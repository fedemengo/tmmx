#!/bin/sh

client_tty=$1
. "$TMMX_DIR/scripts/common.sh"
current_session=$(tmux display-message -p '#{session_name}')
manager_host=$(tmmx_manager_host)
local_sessions=$(tmux show-options -gqv @tmmx_manager_local_sessions)
[ "$local_sessions" = host ] || local_sessions=all
if [ "$local_sessions" = host ] && [ "$(tmux display-message -p '#{@tmmx_remote}')" != 1 ] && [ "$(tmux display-message -p '#{@tmmx_manager}')" != 1 ]; then local_sessions=none; fi
candidates_command="TMMX_DIR=$(tmmx_quote "$TMMX_DIR") sh $(tmmx_quote "$TMMX_DIR/scripts/manager-candidates.sh") $(tmmx_quote "$current_session") $(tmmx_quote "$manager_host") $(tmmx_quote "$local_sessions")"
result=$(tmmx_list_manager_candidates "$current_session" "$manager_host" "$local_sessions" '' | tmmx_fzf manager "TMMX_DIR='$TMMX_DIR' sh '$TMMX_DIR/scripts/kill-session.sh' {3}" "$candidates_command" || true)
query=$(tmmx_query "$result")
selected=$(tmmx_selection "$result")

switch_to() {
  if [ -n "$client_tty" ] && tmux list-clients -F '#{client_tty}' | grep -Fx "$client_tty" >/dev/null && tmux switch-client -c "$client_tty" -t "=$1"; then return 0; fi
  tmux switch-client -t "=$1"
}

# destination is a complete SSH destination ([user@]host). It is stored verbatim
# in @tmmx_host so reconnect, restore, and kill all reuse the same target.
connect_remote() {
  destination=$1
  session=$(tmmx_find_remote "$destination")
  if [ -z "$session" ]; then
    session=$(tmmx_remote_session_name "$destination")
    if ! tmmx_has_session "$session"; then tmux new-session -d -s "$session" "TMMX_DIR='$TMMX_DIR' sh '$TMMX_DIR/scripts/remote-connect.sh' '$destination'"; fi
    tmux set-option -t "=$session:" status off
    tmux set-option -t "=$session:" mouse off
    tmux set-option -t "=$session:" @tmmx_remote 1
    tmux set-option -t "=$session:" @tmmx_host "$destination"
    tmmx_tag_managed "$session"
  fi
  switch_to "$session"
}

case "$selected" in ssh:*) connect_remote "${selected#ssh:}"; exit 0 ;; esac
if [ -n "$selected" ]; then switch_to "$selected"; exit 0; fi
[ -n "$query" ] || exit 0

if destination=$(tmmx_ssh_command_destination "$query"); then
  if ! tmmx_valid_ssh_destination "$destination"; then tmux display-message 'Use ssh user@host'; exit 1; fi
  connect_remote "$destination"
  exit 0
fi

case "$query" in
  @*)
    host=${query#@}
    case "$host" in ''|*[!A-Za-z0-9._-]*) tmux display-message 'Use @ followed by an SSH host alias, or ssh user@host'; exit 1 ;; esac
    connect_remote "$host"
    ;;
  *)
    if ! tmmx_valid_session_name "$query"; then tmux display-message 'Session names cannot contain tabs or |'; exit 1; fi
    session=$(tmmx_session_name "$query")
    if ! tmmx_has_session "$session"; then tmux new-session -d -s "$session"; tmmx_tag_managed "$session"; fi
    switch_to "$session"
    ;;
esac
