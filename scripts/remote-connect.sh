#!/bin/sh

host=$1
. "$TMMX_DIR/scripts/common.sh"

quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
remote_tmux_bin=${TMMX_REMOTE_TMUX:-}
remote_preamble='PATH=$HOME/.local/bin:$HOME/bin:$PATH; export PATH; for tmmx_locale in C.utf8 C.UTF-8 en_US.utf8 en_US.UTF-8; do if locale -a 2>/dev/null | grep -qx "$tmmx_locale"; then export LC_ALL="$tmmx_locale"; break; fi; done; '

if [ -z "$remote_tmux_bin" ]; then
  remote_tmux_bin=$(ssh "$host" 'PATH=$HOME/.local/bin:$HOME/bin:$PATH; export PATH; tmmx_tmux=$(command -v tmux || { command -v zsh >/dev/null 2>&1 && zsh -ic "command -v tmux" 2>/dev/null | sed -n "/^\\//{p;q;}"; }); [ -n "$tmmx_tmux" ] && printf "__TMMX_BIN__%s\\n" "$tmmx_tmux"' | sed -n 's/^__TMMX_BIN__//p' | sed -n '1p')
fi

[ -n "$remote_tmux_bin" ] || {
  printf 'Could not find tmux on %s. Set TMMX_REMOTE_TMUX to its path if necessary.\n' "$host" >&2
  exit 1
}

remote_tmux() {
  remote_command="$remote_preamble exec $(quote "$remote_tmux_bin")"
  for argument in "$@"; do remote_command="$remote_command $(quote "$argument")"; done
  ssh "$host" "$remote_command"
}

remote_sessions() {
  remote_tmux list-sessions -F '__TMMX_SESSION__#{session_last_attached}|#{session_name}'
}

option_enabled() {
  case "$(tmux show-options -gqv "$1")" in 1|on|true|yes) return 0 ;; *) return 1 ;; esac
}

auto_reconnect=0
option_enabled @tmmx_auto_reconnect && auto_reconnect=1
reconnect_delay=$(tmux show-options -gqv @tmmx_reconnect_delay)
case "$reconnect_delay" in ''|*[!0-9]*) reconnect_delay=2 ;; esac
auto_restore=0
option_enabled @tmmx_auto_restore && auto_restore=1
restore_grace=$(tmux show-options -gqv @tmmx_restore_grace)
case "$restore_grace" in ''|*[!0-9]*) restore_grace=5 ;; esac
restore_attempted=0

reconnecting() {
  printf '\033[2J\033[HConnection to %s lost. Reconnecting…\nPress Ctrl-c to stop.\n' "$host"
  sleep "$reconnect_delay"
}

restore_if_needed() {
  target=$1
  [ "$auto_restore" = 1 ] || return 0
  error_file=$(mktemp "${TMPDIR:-/tmp}/tmmx.XXXXXX") || return 0
  remote_sessions >/dev/null 2>"$error_file"
  status=$?
  if [ "$status" -eq 0 ]; then restore_attempted=0; rm -f "$error_file"; return 0; fi
  if ! tmmx_no_server_error <"$error_file" || [ "$restore_attempted" = 1 ]; then rm -f "$error_file"; return 0; fi
  rm -f "$error_file"
  restore_attempted=1
  bootstrap='__tmmx_restore__'
  remote_tmux new-session -d -s "$bootstrap" 2>/dev/null || return 0
  restore_script=$(remote_tmux display-message -p '__TMMX_RESTORE__#{@resurrect-restore-script-path}' 2>/dev/null | sed -n 's/^__TMMX_RESTORE__//p' | sed -n '1p')
  [ -n "$restore_script" ] || { remote_tmux kill-session -t "=$bootstrap" 2>/dev/null; return 0; }
  remote_tmux run-shell "$restore_script" >/dev/null 2>&1 || { remote_tmux kill-session -t "=$bootstrap" 2>/dev/null; return 0; }
  elapsed=0
  while [ "$elapsed" -lt "$restore_grace" ]; do
    remote_tmux has-session -t "=$target" 2>/dev/null && break
    sleep 1
    elapsed=$((elapsed + 1))
  done
  remote_tmux kill-session -t "=$bootstrap" 2>/dev/null || true
}

while :; do
  error_file=$(mktemp "${TMPDIR:-/tmp}/tmmx.XXXXXX") || exit 1
  session_output=$(remote_sessions 2>"$error_file")
  status=$?
  sessions=$(printf '%s\n' "$session_output" | sed -n 's/^__TMMX_SESSION__//p')
  if [ "$status" -ne 0 ] && ! tmmx_no_server_error <"$error_file"; then printf 'Could not list tmux sessions on %s.\n' "$host" >&2; sed -n '1,3p' "$error_file" >&2; rm -f "$error_file"; exit 1; fi
  rm -f "$error_file"
  if [ -n "$sessions" ]; then
    result=$(printf '%s\n' "$sessions" | sort -t '|' -k1,1nr | while IFS='|' read -r last_attached remote_session; do printf '%s\t%s\t%s\t%s\n' "$remote_session" "$last_attached" "$(tmmx_format_timestamp "$last_attached")" "$remote_session"; done | tmmx_fzf remote "TMMX_DIR='$TMMX_DIR' sh '$TMMX_DIR/scripts/remote-kill-session.sh' '$host' '$remote_tmux_bin' {3}" || true)
  else
    result=$(printf 'main\n')
  fi
  query=$(tmmx_query "$result")
  selected=$(tmmx_selection "$result")
  session=${selected:-$query}
  [ -n "$session" ] || exit 0
  if ! tmmx_valid_session_name "$session"; then printf 'Session names cannot contain tabs or |.\n' >&2; continue; fi
  session=$(tmmx_session_name "$session")
  attach_command="$remote_preamble exec $(quote "$remote_tmux_bin") new-session -A -s"
  recovering=0
  while :; do
    [ "$recovering" = 1 ] && restore_if_needed "$session"
    error_file=$(mktemp "${TMPDIR:-/tmp}/tmmx.XXXXXX") || exit 1
    if [ "$auto_reconnect" = 1 ]; then
      # A dropped Wi-Fi or sleeping laptop can leave TCP half-open indefinitely.
      # Probes make SSH return its normal transport-failure status so this loop
      # can reconnect, without changing the default non-reconnecting behavior.
      ssh -t -o ServerAliveInterval=5 -o ServerAliveCountMax=1 "$host" "$attach_command $(quote "$session")" 2>"$error_file"
    else
      ssh -t "$host" "$attach_command $(quote "$session")" 2>"$error_file"
    fi
    status=$?
    if [ "$status" -eq 255 ] && [ "$auto_reconnect" = 1 ]; then rm -f "$error_file"; reconnecting; recovering=1; continue; fi
    rm -f "$error_file"
    break
  done
done
