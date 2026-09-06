#!/bin/sh
# Lazy reconnect: when a client switches to a managed remote wrapper whose pane
# is a bare shell (e.g. after a resurrect restore), reopen its ssh connection,
# straight to the session it was on when known.

. "$TMMX_DIR/scripts/common.sh"
session=${1:-$(tmux display-message -p '#{session_name}' 2>/dev/null)}
[ -n "$session" ] || exit 0
[ "$(tmux show-options -t "=$session:" -qv @tmmx_remote 2>/dev/null)" = 1 ] || exit 0
host=$(tmux show-options -t "=$session:" -qv @tmmx_host 2>/dev/null)
[ -n "$host" ] || exit 0

pane=$(tmux list-panes -t "=$session:" -F '#{pane_id} #{pane_pid}' 2>/dev/null | head -1)
pane_id=${pane%% *}
pane_pid=${pane##* }
[ -n "$pane_id" ] || exit 0
tmmx_pane_connected "$pane_pid" && exit 0

inner=$(tmmx_recall_inner "$host")
if [ -n "$inner" ]; then
  tmux respawn-pane -k -t "$pane_id" "TMMX_DIR='$TMMX_DIR' sh '$TMMX_DIR/scripts/remote-connect.sh' '$host' '$inner'"
else
  tmux respawn-pane -k -t "$pane_id" "TMMX_DIR='$TMMX_DIR' sh '$TMMX_DIR/scripts/remote-connect.sh' '$host'"
fi
tmux set-option -t "=$session:" status off
tmux set-option -t "=$session:" mouse off
