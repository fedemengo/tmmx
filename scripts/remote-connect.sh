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
  command="$remote_preamble exec $(quote "$remote_tmux_bin")"
  for argument in "$@"; do command="$command $(quote "$argument")"; done
  ssh "$host" "$command"
}

remote_sessions() {
  remote_tmux list-sessions -F '__TMMX_SESSION__#{session_last_attached}|#{session_name}'
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
  command="$remote_preamble exec $(quote "$remote_tmux_bin") new-session -A -s"
  ssh -t "$host" "$command $(quote "$session")"
done
