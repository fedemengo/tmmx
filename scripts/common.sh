#!/bin/sh

tmmx_list_sessions() {
  current_session=$1
  separator='|'
  tmux list-sessions -F '#{session_last_attached}|#{session_name}|#{@tmmx_remote}|#{@tmmx_host}|#{@tmmx_manager}' | sort -t "$separator" -k1,1nr | while IFS="$separator" read -r last_attached session remote host manager; do
    [ "$session" = "$current_session" ] && continue
    [ "$manager" = 1 ] && continue
    timestamp=$(tmmx_format_timestamp "$last_attached")
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

tmmx_host_label() {
  host=$1
  color=$(tmux show-options -gqv @tmmx_host_colors | tr ',' '\n' | while IFS='=' read -r key value; do [ "$key" = "$host" ] && { printf '%s\n' "$value"; break; }; done)
  hex=$(printf '%s' "$color" | sed -n 's/^#\([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\)$/\1/p')
  if [ -n "$hex" ]; then
    red=$(printf '%d' "0x$(printf '%s' "$hex" | cut -c1-2)")
    green=$(printf '%d' "0x$(printf '%s' "$hex" | cut -c3-4)")
    blue=$(printf '%d' "0x$(printf '%s' "$hex" | cut -c5-6)")
    printf '\033[38;2;%s;%s;%sm@%s\033[0m' "$red" "$green" "$blue" "$host"
  else
    printf '@%s' "$host"
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

tmmx_fzf() {
  picker_kind=$1
  kill_command=$2
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
  fzf --ansi --height=100% --reverse --border=rounded --padding=0 --no-scrollbar --prompt='> ' --delimiter='\t' --with-nth=1,2 --tabstop=1 --print-query --bind "j:down,k:up,$mode_bindings,enter:accept$kill_binding" "$@"
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
