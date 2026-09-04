#!/bin/sh

tmmx_list_sessions() {
  current_session=$1
  separator='|'
  tmux list-sessions -F '#{session_last_attached}|#{session_name}|#{@tmmx_remote}|#{@tmmx_host}|#{@tmmx_manager}' | sort -t "$separator" -k1,1nr | while IFS="$separator" read -r last_attached session remote host manager; do
    [ "$session" = "$current_session" ] && continue
    [ "$manager" = 1 ] && continue
    timestamp=$(tmmx_format_timestamp "$last_attached")
    last_attached=${last_attached:-0}
    if [ "$remote" = 1 ]; then printf '@%s\t%s\t%s\t%s\n' "$host" "$last_attached" "$timestamp" "$session"; else printf '%s\t%s\t%s\t%s\n' "$session" "$last_attached" "$timestamp" "$session"; fi
  done
}

tmmx_list_host_sessions() {
  current_session=$1
  tmmx_list_sessions "$current_session" | while IFS="$(printf '\t')" read -r label epoch timestamp target; do
    case "$label" in @*) ;; *) printf '%s\t%s\t%s\t%s\n' "$label" "$epoch" "$timestamp" "$target" ;; esac
  done
}

tmmx_format_timestamp() {
  timestamp=$1
  [ "${timestamp:-0}" -gt 0 ] 2>/dev/null || { printf 'never\n'; return; }
  date -r "$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || date -d "@$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || printf '%s\n' "$timestamp"
}

tmmx_manager_host() {
  manager_host=$(tmux show-options -gqv @tmmx_manager_host)
  [ -n "$manager_host" ] || manager_host=$(hostname -s)
  printf '%s\n' "$manager_host"
}

tmmx_ssh_host() { printf '%s\n' "${1##*@}"; }
tmmx_ssh_user() { case "$1" in *@*) printf '%s\n' "${1%@*}" ;; *) printf '\n' ;; esac; }
tmmx_ssh_command_destination() {
  case "$1" in ssh|'ssh '*) printf '%s\n' "${1#ssh}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' ;; *) return 1 ;; esac
}
tmmx_valid_ssh_destination() { case "$1" in ''|*[!A-Za-z0-9._@-]*|@*|*@|*@*@*) return 1 ;; *) return 0 ;; esac; }

tmmx_host_color() {
  destination=$1
  colors=$(tmux show-options -gqv @tmmx_host_colors)
  for key in "$destination" "$(tmmx_ssh_host "$destination")"; do
    color=$(printf '%s\n' "$colors" | tr ',' '\n' | awk -v key="$key" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }')
    if [ -n "$color" ]; then printf '%s\n' "$color"; return 0; fi
  done
  return 1
}

tmmx_host_label() {
  destination=$1
  user=$(tmmx_ssh_user "$destination")
  if [ -n "$user" ]; then text=$destination; else text="@$destination"; fi
  hex=$(tmmx_host_color "$destination" | sed -n 's/^#\([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\)$/\1/p')
  if [ -n "$hex" ]; then
    red=$(printf '%d' "0x$(printf '%s' "$hex" | cut -c1-2)")
    green=$(printf '%d' "0x$(printf '%s' "$hex" | cut -c3-4)")
    blue=$(printf '%d' "0x$(printf '%s' "$hex" | cut -c5-6)")
    printf '\033[38;2;%s;%s;%sm%s\033[0m' "$red" "$green" "$blue" "$text"
  else
    printf '%s' "$text"
  fi
}

tmmx_list_manager_sessions() {
  current_session=$1
  manager_host=$2
  local_sessions=${3:-all}
  local_seen=
  tmmx_list_sessions "$current_session" | while IFS="$(printf '\t')" read -r label epoch timestamp target; do
    case "$label" in
      @*) host=${label#@}; printf '%s\t%s\t%s\t%s\n' "$(tmmx_host_label "$host")" "$epoch" "$timestamp" "$target" ;;
      *)
        if [ "$local_sessions" = host ]; then
          [ -n "$local_seen" ] && continue
          local_seen=1
          printf '%s [local]\t%s\t%s\t%s\n' "$(tmmx_host_label "$manager_host")" "$epoch" "$timestamp" "$target"
        elif [ "$local_sessions" = none ]; then
          continue
        else
          printf '%s - %s\t%s\t%s\t%s\n' "$(tmmx_host_label "$manager_host")" "$label" "$epoch" "$timestamp" "$target"
        fi
        ;;
    esac
  done
}

# Hosts declared in an OpenSSH client configuration, in file order, following
# Include directives. Patterns with wildcards or negation are not connectable.
tmmx_ssh_config_hosts() { tmmx_ssh_config_scan "${1:-$HOME/.ssh/config}" 0 | awk '!seen[$0]++'; }
tmmx_ssh_config_scan() {
  config_file=$1
  depth=$2
  [ -r "$config_file" ] && [ "$depth" -lt 8 ] || return 0
  awk '{ sub(/#.*/, ""); key = tolower($1); if (key == "host") { for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/) print "host\t" $i } else if (key == "include") { for (i = 2; i <= NF; i++) print "include\t" $i } }' "$config_file" | while IFS="$(printf '\t')" read -r kind value; do
    case "$kind" in
      host) printf '%s\n' "$value" ;;
      include)
        case "$value" in '~/'*) value="$HOME/${value#\~/}" ;; /*) ;; *) value="$HOME/.ssh/$value" ;; esac
        for included in $value; do tmmx_ssh_config_scan "$included" $((depth + 1)); done
        ;;
    esac
  done
}

# Manager rows for a query: matching sessions, then, once the query names an SSH
# destination (@host or user@host), configured hosts that have no wrapper yet. Host rows carry an ssh: target so the picker connects instead of switching.
tmmx_list_manager_candidates() {
  current_session=$1
  manager_host=$2
  local_sessions=$3
  query=$4
  tmmx_list_manager_sessions "$current_session" "$manager_host" "$local_sessions"
  case "$query" in *@*) user=${query%%@*} ;; *) return 0 ;; esac
  case "$user" in *[!A-Za-z0-9._-]*) return 0 ;; esac
  [ -n "$user" ] && user="$user@"
  existing=$(tmmx_list_sessions '' | cut -f1 | sed -n 's/^@//p')
  tmmx_ssh_config_hosts | while IFS= read -r host; do
    destination="$user$host"
    printf '%s\n' "$existing" | grep -Fqx "$destination" && continue
    printf '%s\t0\tssh config\tssh:%s\n' "$(tmmx_host_label "$destination")" "$destination"
  done
}

tmmx_quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

tmmx_fzf() {
  picker_kind=$1
  kill_command=$2
  reload_command=$3
  case "$picker_kind" in
    manager) title='Hosts'; footer='Ctrl-x close · Ctrl-j scroll · i insert · Esc cancel' ;;
    remote) title='Sessions'; footer='Ctrl-x kill · Ctrl-j scroll · i insert · Esc cancel' ;;
    *) title='Sessions'; footer='Ctrl-x kill · Ctrl-j scroll · i insert · Esc cancel' ;;
  esac
  fzf_version=$(fzf --version 2>/dev/null | sed -n '1{s/[^0-9.].*$//;p;}')
  if ! awk -v version="$fzf_version" 'BEGIN { split(version, part, "."); exit !(part[1] > 0 || (part[1] == 0 && part[2] >= 35)) }'; then
    message="tmmx requires fzf 0.35 or newer (found ${fzf_version:-none})"
    printf '%s\n' "$message" >&2
    tmux display-message "$message" 2>/dev/null || true
    return 2
  fi
  kill_binding=
  [ -n "$kill_command" ] && kill_binding=",ctrl-x:execute($kill_command)+abort"
  picker_columns=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
  case "$picker_columns" in ''|*[!0-9]*) picker_columns=${COLUMNS:-} ;; esac
  case "$picker_columns" in ''|*[!0-9]*) picker_columns=$(tput cols 2>/dev/null || printf 0) ;; esac
  case "$picker_columns" in ''|*[!0-9]*) picker_columns=0 ;; esac
  reload_binding=
  [ -n "$reload_command" ] && reload_binding=",change:reload($reload_command {q} | TMMX_PICKER_COLUMNS=$picker_columns sh $(tmmx_quote "$TMMX_DIR/scripts/format-picker.sh"))"
  if awk -v version="$fzf_version" 'BEGIN { split(version, part, "."); exit !(part[1] > 0 || (part[1] == 0 && part[2] >= 63)) }'; then
    TMMX_PICKER_COLUMNS="$picker_columns" "$TMMX_DIR/scripts/format-picker.sh" | tmmx_run_fzf "$title" 1 --border-label=" $title [scroll] " --footer="$footer"
  else
    header=$(printf '%s [scroll]\n%s\n ' "$title" "$footer")
    TMMX_PICKER_COLUMNS="$picker_columns" "$TMMX_DIR/scripts/format-picker.sh" | tmmx_run_fzf "$title" 0 --header="$header"
  fi
}

tmmx_run_fzf() {
  title=$1
  dynamic_title=$2
  shift 2
  if [ "$dynamic_title" = 1 ]; then mode_bindings="i:unbind(j,k,i)+change-border-label( $title [insert] ),start:change-border-label( $title [scroll] ),ctrl-j:rebind(j,k,i)+change-border-label( $title [scroll] )"; else mode_bindings='i:unbind(j,k,i),ctrl-j:rebind(j,k,i)'; fi
  fzf --ansi --height=100% --reverse --border=rounded --padding=0 --no-scrollbar --prompt='> ' --delimiter='\t' --with-nth=1,2 --tabstop=1 --print-query --bind "j:down,k:up,$mode_bindings,enter:accept$kill_binding$reload_binding" "$@"
}

tmmx_query() { printf '%s\n' "$1" | sed -n '1p'; }
tmmx_selection() { printf '%s\n' "$1" | sed -n '2p' | cut -f3-; }
tmmx_has_session() { tmux has-session -t "=$1" 2>/dev/null; }
tmmx_tag_managed() { tmux set-option -t "=$1:" @tmmx_managed 1; }
tmmx_session_name() { printf '%s\n' "$(printf '%s' "$1" | tr '.:' '__')"; }
tmmx_remote_session_name() { printf '__tmmx_remote__%s\n' "$(tmmx_session_name "$1")"; }
tmmx_valid_session_name() { forbidden=$(printf '\t|'); [ -n "$1" ] && [ "$(printf '%s' "$1" | tr -d "$forbidden")" = "$1" ]; }
tmmx_no_server_error() { grep -Eq 'no server running|error connecting to .*No such file or directory'; }

tmmx_find_remote() {
  requested_host=$1
  separator='|'
  tmux list-sessions -F '#{session_name}|#{@tmmx_remote}|#{@tmmx_host}' | while IFS="$separator" read -r session remote host; do
    [ "$remote" = 1 ] && [ "$host" = "$requested_host" ] && { printf '%s\n' "$session"; exit 0; }
  done
}
