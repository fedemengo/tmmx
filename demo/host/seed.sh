#!/bin/sh
# Seed this host's tmux sessions (3 per host, 2 windows each). Both windows of the
# sessions you tour run a lightweight loop so panes scroll during a recording.
# Loop commands are single-quoted so $RANDOM and $(date) are evaluated by each
# pane's bash, not here at seed time.
set -eu

role=${DEMO_ROLE:-web}

# mk <session> <w1> <w1cmd> <w2> <w2cmd>  (empty cmd = idle shell)
mk() {
  tmux new-session -d -s "$1" -n "$2"
  [ -n "$3" ] && tmux send-keys -t "$1:$2" "clear; $3" C-m
  tmux new-window -t "$1" -n "$4"
  [ -n "$5" ] && tmux send-keys -t "$1:$4" "clear; $5" C-m
  tmux select-window -t "$1:$2"
}

ACC='while true; do printf "%s \"GET /api/v1/users\" 200 %dms\n" "$(date +%T)" $((RANDOM%40+5)); sleep 1.2; done'
ERR='while true; do printf "%s WARN upstream retry (%d)\n" "$(date +%T)" $((RANDOM%3+1)); sleep 2.0; done'
BUILD='while true; do for s in fetch build test package; do printf "[deploy] %s…\n" "$s"; sleep 1; done; printf "[deploy] ✓ released %s\n" "$(date +%T)"; sleep 3; done'
PUSH='while true; do printf "pushing layer %06x … done\n" $((RANDOM%16777215)); sleep 1.3; done'
REQ='while true; do printf "%s POST /orders 201 %dms\n" "$(date +%T)" $((RANDOM%60+10)); sleep 1.1; done'
CACHE='while true; do printf "%s INFO cache hit %d%%\n" "$(date +%T)" $((RANDOM%20+78)); sleep 1.4; done'
REPL='while true; do printf ">>> df.head()   # %d rows\n" $((RANDOM%1000)); sleep 2.5; done'
STATS='while true; do printf "%s conns=%d qps=%d cache=%d%%\n" "$(date +%T)" $((RANDOM%50+10)) $((RANDOM%400+100)) $((RANDOM%20+78)); sleep 1.2; done'
CONNS='while true; do printf "%s client 10.0.%d.%d connected\n" "$(date +%T)" $((RANDOM%255)) $((RANDOM%255)); sleep 1.5; done'
DUMP='while true; do for p in 10 30 55 80 100; do printf "[backup] %d%%\n" "$p"; sleep 0.7; done; printf "[backup] ✓ snapshot %s\n" "$(date +%T)"; sleep 3; done'
ARCHIVE='while true; do printf "archived table tbl_%02d\n" $((RANDOM%50)); sleep 1.6; done'
PSQL='while true; do printf "%s SELECT ok (%d rows, %dms)\n" "$(date +%T)" $((RANDOM%500)) $((RANDOM%40+2)); sleep 1.8; done'
JOBS='while true; do printf "%s job #%d done (%dms)\n" "$(date +%T)" $((RANDOM%9000+1000)) $((RANDOM%200+20)); sleep 0.9; done'
FAILED='while true; do printf "%s retry job #%d (attempt %d)\n" "$(date +%T)" $((RANDOM%9000+1000)) $((RANDOM%3+1)); sleep 2.0; done'
CRON='while true; do printf "%s cron: ran backup.sh (ok)\n" "$(date +%T)"; sleep 3.0; done'

case "$role" in
  web)
    mk deploy build "$BUILD" push "$PUSH"
    mk nginx access "$ACC" error "$ERR"
    mk shell main "$ACC" scratch "$REQ"
    ;;
  api)
    mk logs tail "$CACHE" warn "$ERR"
    mk repl ipython "$REPL" scratch "$CACHE"
    mk server run "$REQ" access "$ACC"
    ;;
  db)
    mk backup dump "$DUMP" archive "$ARCHIVE"
    mk monitor stats "$STATS" conns "$CONNS"
    mk psql query "$PSQL" schema "$ARCHIVE"
    ;;
  worker)
    mk cron schedule "$CRON" dispatch "$JOBS"
    mk queue jobs "$JOBS" failed "$FAILED"
    mk shell main "$JOBS" scratch "$ACC"
    ;;
  *)
    mk shell main '' scratch ''
    ;;
esac
