#!/bin/sh

host=$1
# Optional inner session: when given, attach straight to it and skip the picker.
# Used to reopen a restored wrapper on the session it was on before.
inner=${2:-}
. "$TMMX_DIR/scripts/common.sh"

quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
# tmmx always supplies its own remote command, so a RemoteCommand or forced
# RequestTTY from a matching Host entry must not apply. Other options do.
ssh_batch() { ssh -o RemoteCommand=none -o RequestTTY=no "$@"; }
ssh_tty() { ssh -t -o RemoteCommand=none "$@"; }
# A wrapper session closes as soon as this script exits, so a fatal error must
# stay on screen until the user has read it.
pause_before_exit() {
  [ -r /dev/tty ] || return 0
  printf 'Press Enter to close.\n' >&2
  IFS= read -r _ </dev/tty 2>/dev/null || true
}
remote_tmux_bin=${TMMX_REMOTE_TMUX:-}
remote_preamble='PATH=$HOME/.local/bin:$HOME/bin:$PATH; export PATH; for tmmx_locale in C.utf8 C.UTF-8 en_US.utf8 en_US.UTF-8; do if locale -a 2>/dev/null | grep -qx "$tmmx_locale"; then export LC_ALL="$tmmx_locale"; break; fi; done; '

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
# Reconnect uses capped exponential backoff so a host that stays unreachable (or
# whose tmux never answers) is retried ever more slowly instead of hammered every
# few seconds. Any forward progress (discovery, listing, or a live attach) resets
# it, so a transient drop still recovers quickly.
reconnect_max=$(tmux show-options -gqv @tmmx_reconnect_max)
case "$reconnect_max" in ''|*[!0-9]*) reconnect_max=60 ;; esac
[ "$reconnect_max" -ge "$reconnect_delay" ] || reconnect_max=$reconnect_delay
backoff=$reconnect_delay

reconnecting() {
  printf '\033[2J\033[HConnection to %s lost. Reconnecting in %ss…\nPress Ctrl-c to stop.\n' "$host" "$backoff"
  sleep "$backoff"
  backoff=$((backoff * 2))
  [ "$backoff" -le "$reconnect_max" ] || backoff=$reconnect_max
}
reset_backoff() { backoff=$reconnect_delay; }

discover_tmux() {
  [ -n "$remote_tmux_bin" ] && return 0
  remote_tmux_bin=$(ssh_batch "$host" 'PATH=$HOME/.local/bin:$HOME/bin:$PATH; export PATH; tmmx_tmux=$(command -v tmux || { command -v zsh >/dev/null 2>&1 && zsh -ic "command -v tmux" 2>/dev/null | sed -n "/^\\//{p;q;}"; }); [ -n "$tmmx_tmux" ] && printf "__TMMX_BIN__%s\\n" "$tmmx_tmux"' | sed -n 's/^__TMMX_BIN__//p' | sed -n '1p')
  [ -n "$remote_tmux_bin" ]
}

remote_tmux() {
  remote_command="$remote_preamble exec $(quote "$remote_tmux_bin")"
  for argument in "$@"; do remote_command="$remote_command $(quote "$argument")"; done
  ssh_batch "$host" "$remote_command"
}

remote_sessions() {
  remote_tmux list-sessions -F '__TMMX_SESSION__#{session_last_attached}|#{session_name}'
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

# Locate the remote tmux. With auto-reconnect on, a currently unreachable host is
# retried instead of ending the wrapper, so a reopened session waits for the host
# to come back exactly like a dropped connection does.
while ! discover_tmux; do
  printf 'Could not find tmux on %s. Set TMMX_REMOTE_TMUX to its path if necessary.\n' "$host" >&2
  if [ "$auto_reconnect" = 1 ]; then reconnecting; continue; fi
  pause_before_exit
  exit 1
done
reset_backoff

first_direct=$inner
while :; do
  if [ -n "$first_direct" ]; then
    # Reopen path: go straight to the remembered session.
    session=$first_direct
    first_direct=
  else
    error_file=$(mktemp "${TMPDIR:-/tmp}/tmmx.XXXXXX") || exit 1
    session_output=$(remote_sessions 2>"$error_file")
    status=$?
    sessions=$(printf '%s\n' "$session_output" | sed -n 's/^__TMMX_SESSION__//p')
    if [ "$status" -ne 0 ] && ! tmmx_no_server_error <"$error_file"; then
      printf 'Could not list tmux sessions on %s.\n' "$host" >&2; sed -n '1,3p' "$error_file" >&2; rm -f "$error_file"
      if [ "$auto_reconnect" = 1 ]; then reconnecting; continue; fi
      pause_before_exit; exit 1
    fi
    rm -f "$error_file"
    reset_backoff
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
  fi
  # Remember the session so a later reopen can attach here without the picker.
  tmmx_remember_inner "$host" "$session"
  attach_command="$remote_preamble exec $(quote "$remote_tmux_bin") new-session -A -s"
  recovering=0
  while :; do
    [ "$recovering" = 1 ] && restore_if_needed "$session"
    error_file=$(mktemp "${TMPDIR:-/tmp}/tmmx.XXXXXX") || exit 1
    if [ "$auto_reconnect" = 1 ]; then
      # A dropped Wi-Fi or sleeping laptop can leave TCP half-open indefinitely.
      # Probes make SSH return its normal transport-failure status so this loop
      # can reconnect, without changing the default non-reconnecting behavior.
      ssh_tty -o ServerAliveInterval=5 -o ServerAliveCountMax=1 "$host" "$attach_command $(quote "$session")" 2>"$error_file"
    else
      ssh_tty "$host" "$attach_command $(quote "$session")" 2>"$error_file"
    fi
    status=$?
    if [ "$status" -eq 255 ] && [ "$auto_reconnect" = 1 ]; then rm -f "$error_file"; reconnecting; recovering=1; continue; fi
    rm -f "$error_file"
    reset_backoff
    break
  done
done
