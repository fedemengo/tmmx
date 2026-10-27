#!/bin/sh
# Seed this host's tmux sessions (3 per host, 2 windows each). Window 1 of the
# "live" sessions runs a lightweight loop so panes scroll during a recording;
# the other windows are idle shells. Loop commands are single-quoted so $RANDOM
# and $(date) are evaluated by each pane's bash, not here at seed time.
set -eu

role=${DEMO_ROLE:-web}

# mk <session> <window1> <window2> <loop-command-or-empty>
mk() {
  tmux new-session -d -s "$1" -n "$2"
  [ -n "$4" ] && tmux send-keys -t "$1:$2" "$4" C-m
  tmux new-window -t "$1" -n "$3"
  tmux select-window -t "$1:$2"
}

case "$role" in
  web)
    mk nginx access error 'while true; do printf "%s \"GET /api/v1/users\" 200 %dms\n" "$(date +%T)" $((RANDOM%40+5)); sleep 1.3; done'
    mk deploy build release 'while true; do for s in fetch build test package; do printf "[deploy] %s…\n" "$s"; sleep 1; done; printf "[deploy] ✓ released %s\n" "$(date +%T)"; sleep 3; done'
    mk shell main scratch ''
    ;;
  api)
    mk server run logs 'while true; do printf "%s POST /orders 201 %dms\n" "$(date +%T)" $((RANDOM%60+10)); sleep 1.1; done'
    mk logs tail scratch 'while true; do printf "%s INFO cache hit %d%%\n" "$(date +%T)" $((RANDOM%20+78)); sleep 1.4; done'
    mk repl python scratch ''
    ;;
  db)
    mk psql query schema ''
    mk backup dump scratch 'while true; do for p in 10 30 55 80 100; do printf "[backup] %d%%\n" "$p"; sleep 0.7; done; printf "[backup] ✓ snapshot %s\n" "$(date +%T)"; sleep 3; done'
    mk monitor stats conns 'while true; do printf "%s conns=%d qps=%d cache=%d%%\n" "$(date +%T)" $((RANDOM%50+10)) $((RANDOM%400+100)) $((RANDOM%20+78)); sleep 1.2; done'
    ;;
  worker)
    mk queue jobs failed 'while true; do printf "%s job #%d done (%dms)\n" "$(date +%T)" $((RANDOM%9000+1000)) $((RANDOM%200+20)); sleep 0.9; done'
    mk cron schedule scratch ''
    mk shell main scratch ''
    ;;
  *)
    mk shell main scratch ''
    ;;
esac
