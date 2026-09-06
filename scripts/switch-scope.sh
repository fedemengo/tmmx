#!/bin/sh
# Switch to the most-recently-attached session whose host matches (scope=host)
# or differs from (scope=across) the current session's host. Host is "local" for
# a local session or the wrapper's @tmmx_host for a remote wrapper. The current
# session and client tty are passed in, since a run-shell has no client of its own.
scope=$1
cur=$2
tty=$3
. "$TMMX_DIR/scripts/common.sh"
[ -n "$cur" ] || exit 0
cur_host=$(tmmx_session_host "$cur")
target=$(tmux list-sessions -F '#{session_last_attached}|#{session_name}|#{@tmmx_remote}|#{@tmmx_host}|#{@tmmx_manager}' 2>/dev/null \
  | sort -t '|' -k1,1nr \
  | awk -F '|' -v cur="$cur" -v curhost="$cur_host" -v scope="$scope" '
      $2 == cur { next }
      $5 == 1 { next }
      { h = ($3 == 1 ? $4 : "local") }
      scope == "host"   && h == curhost { print $2; exit }
      scope == "across" && h != curhost { print $2; exit }
    ')
[ -n "$target" ] || exit 0
if [ -n "$tty" ]; then tmux switch-client -c "$tty" -t "=$target"; else tmux switch-client -t "=$target"; fi
