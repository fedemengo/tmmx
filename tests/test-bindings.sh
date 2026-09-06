#!/bin/sh
# Guards that loading tmmx does not clobber the user's own bindings in tmux's
# shared prefix key-table. tmmx's outer prefix (Ctrl-\) routes into that table,
# so any nav key tmmx binds there would silently rewrite the same key for the
# user's native prefix. Regression: tmmx once bound prefix Tab to switch-client,
# destroying a user's `bind Tab last-window` (per-session previous window).
#
# Runs against a private tmux socket via a PATH shim, so tmmx.tmux's own bare
# `tmux` calls target the throwaway server and never the caller's real one.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if ! command -v tmux >/dev/null 2>&1; then
  printf 'test-bindings: skip (tmux not installed)\n'
  exit 0
fi
REAL_TMUX=$(command -v tmux)
SOCK="tmmx-bindings-$$"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/tmmx-bindings.XXXXXX")
cat > "$WORK/tmux" <<EOF
#!/bin/sh
exec "$REAL_TMUX" -L "$SOCK" "\$@"
EOF
chmod +x "$WORK/tmux"
PATH="$WORK:$PATH"; export PATH
cleanup() { tmux kill-server 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT INT TERM

tmux new-session -d -s '~tmmx' 'sleep 120'
# User bindings in the shared prefix table; loading tmmx must leave them intact.
tmux bind-key Tab last-window
tmux bind-key Space next-window
tmux bind-key C-Tab previous-window

TMMX_DIR="$ROOT" sh "$ROOT/tmmx.tmux" >/dev/null 2>&1 || true

prefix_cmd() { tmux list-keys -T prefix | awk -v k="$1" '$1=="bind-key" && $4==k { for (i=5;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":"\n") }'; }
assert_prefix() {
  got=$(prefix_cmd "$1")
  if [ "$got" != "$2" ]; then
    printf 'FAIL: tmmx changed prefix %s -> [%s], expected [%s]\n' "$1" "$got" "$2" >&2
    exit 1
  fi
}

# tmmx must not have touched the user's window-nav keys in the prefix table.
assert_prefix Tab last-window
assert_prefix Space next-window
assert_prefix C-Tab previous-window

# Previous session must be available at the root previous key (Ctrl-Tab default).
tmux list-keys -T root | awk '$1=="bind-key" && $4=="C-Tab"' | grep -q . || {
  printf 'FAIL: root C-Tab (previous session) not bound\n' >&2
  exit 1
}

printf 'test-bindings: ok\n'
