#!/bin/sh
# Guards the Ctrl-\ navigation layout. Ctrl-\ routes into tmux's shared prefix
# key-table, so tmmx must be careful about what it binds there:
#   - Ctrl-\ Tab   -> the user's window nav (e.g. last-window). tmmx must NOT
#                     touch it. Regression: tmmx once overwrote it with
#                     switch-client, destroying `bind Tab last-window`.
#   - Ctrl-\ Space -> last session on the current host. This one is tmmx's.
#   - Ctrl-Tab     -> previous session across hosts, on the root previous key.
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
# Seed both keys with sentinels so we can tell what tmmx changes.
tmux bind-key Tab last-window
tmux bind-key Space next-window

TMMX_DIR="$ROOT" sh "$ROOT/tmmx.tmux" >/dev/null 2>&1 || true

prefix_cmd() { tmux list-keys -T prefix | awk -v k="$1" '$1=="bind-key" && $4==k { for (i=5;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":"\n") }'; }
assert_prefix() {
  got=$(prefix_cmd "$1")
  if [ "$got" != "$2" ]; then
    printf 'FAIL: prefix %s is [%s], expected [%s]\n' "$1" "$got" "$2" >&2
    exit 1
  fi
}

# Window nav (Ctrl-\ Tab) is the user's and must survive loading tmmx.
assert_prefix Tab last-window
# Session-on-host nav (Ctrl-\ Space) is tmmx's (host-scoped previous switch).
case "$(prefix_cmd Space)" in
  *switch-scope.sh*host*) ;;
  *) printf 'FAIL: prefix Space is [%s], expected tmmx within-host switch\n' "$(prefix_cmd Space)" >&2; exit 1 ;;
esac
# Across-host previous session is the root previous key (Ctrl-Tab default).
tmux list-keys -T root | awk '$1=="bind-key" && $4=="C-Tab"' | grep -q . || {
  printf 'FAIL: root C-Tab (across-host previous session) not bound\n' >&2
  exit 1
}

# One-handed scoped nav: the nav key (default Ctrl-`) is a prefix into tmmx-nav,
# with digits 1/2/3 bound.
tmux list-keys -T root | awk '$1=="bind-key" && $4=="C-`"' | grep -q . || {
  printf 'FAIL: nav key C-` not bound at root\n' >&2
  exit 1
}
for d in 1 2 3; do
  tmux list-keys -T tmmx-nav | awk -v d="$d" '$1=="bind-key" && $4==d' | grep -q . || {
    printf 'FAIL: tmmx-nav %s not bound\n' "$d" >&2
    exit 1
  }
done

printf 'test-bindings: ok\n'
