#!/bin/sh

. "$TMMX_DIR/scripts/common.sh"
current_session=$(tmux display-message -p '#{session_name}')
result=$(tmmx_list_host_sessions "$current_session" | tmmx_fzf local "TMMX_DIR='$TMMX_DIR' sh '$TMMX_DIR/scripts/kill-session.sh' {3}" || true)
query=$(tmmx_query "$result")
selected=$(tmmx_selection "$result")

if [ -n "$selected" ]; then
  tmux switch-client -t "=$selected"
elif [ -n "$query" ]; then
  case "$query" in @*) tmux display-message 'Use Ctrl-q then w to create an SSH-backed @host session'; exit 1 ;; esac
  if ! tmmx_valid_session_name "$query"; then tmux display-message 'Session names cannot contain tabs or |'; exit 1; fi
  session=$(tmmx_session_name "$query")
  if ! tmmx_has_session "$session"; then tmux new-session -d -s "$session"; tmmx_tag_managed "$session"; fi
  tmux switch-client -t "=$session"
fi
