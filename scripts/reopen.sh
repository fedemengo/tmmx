#!/bin/sh
# Background reopen: after a restore, reconnect managed remote wrappers that came
# back as bare shells, one at a time (round-robin, staggered). Gated by
# @tmmx_auto_reconnect. Each reopened wrapper's own remote-connect.sh then keeps
# its connection alive, so the worker quiesces once all wrappers are connected.

. "$TMMX_DIR/scripts/common.sh"
option_enabled() { case "$(tmux show-options -gqv "$1")" in 1|on|true|yes) return 0 ;; *) return 1 ;; esac; }
option_enabled @tmmx_auto_reconnect || exit 0
delay=$(tmux show-options -gqv @tmmx_reconnect_delay)
case "$delay" in ''|*[!0-9]*) delay=2 ;; esac

state_dir=$(tmmx_state_dir)
mkdir -p "$state_dir" 2>/dev/null || exit 0
lock="$state_dir/reopen.lock"
# Single worker at a time, but a lock left by a worker that died uncleanly must
# not block every future reopen: take it over when its owner is gone.
if ! mkdir "$lock" 2>/dev/null; then
  owner=$(cat "$lock/pid" 2>/dev/null)
  if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then exit 0; fi
  rm -f "$lock/pid" 2>/dev/null; rmdir "$lock" 2>/dev/null
  mkdir "$lock" 2>/dev/null || exit 0
fi
printf '%s\n' "$$" > "$lock/pid" 2>/dev/null
list_file=$(mktemp "${TMPDIR:-/tmp}/tmmx-reopen.XXXXXX") || { rm -f "$lock/pid" 2>/dev/null; rmdir "$lock" 2>/dev/null; exit 0; }
trap 'rm -f "$lock/pid" 2>/dev/null; rmdir "$lock" 2>/dev/null; rm -f "$list_file"' EXIT INT TERM

while :; do
  kicked=0
  tmux list-sessions -F '#{session_name}	#{@tmmx_remote}	#{@tmmx_host}' 2>/dev/null > "$list_file"
  # `done < file` keeps this loop in the current shell so kicked persists.
  while IFS='	' read -r s remote host; do
    [ "$remote" = 1 ] || continue
    [ -n "$host" ] || continue
    pane=$(tmux list-panes -t "=$s:" -F '#{pane_id} #{pane_pid}' 2>/dev/null | head -1)
    pane_id=${pane%% *}
    pane_pid=${pane##* }
    [ -n "$pane_id" ] || continue
    tmmx_pane_connected "$pane_pid" && continue
    inner=$(tmmx_recall_inner "$host")
    if [ -n "$inner" ]; then
      tmux respawn-pane -k -t "$pane_id" "TMMX_DIR='$TMMX_DIR' sh '$TMMX_DIR/scripts/remote-connect.sh' '$host' '$inner'"
    else
      tmux respawn-pane -k -t "$pane_id" "TMMX_DIR='$TMMX_DIR' sh '$TMMX_DIR/scripts/remote-connect.sh' '$host'"
    fi
    tmux set-option -t "=$s:" status off
    tmux set-option -t "=$s:" mouse off
    kicked=1
    sleep "$delay"
  done < "$list_file"
  [ "$kicked" = 1 ] || break
  sleep "$delay"
done
