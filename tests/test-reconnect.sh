#!/bin/sh
# Regression guard: the interactive attach's SSH keepalive must not be so
# aggressive that a healthy connection is dropped on a brief stall. It once used
# ServerAliveInterval=5 with ServerAliveCountMax=1 (a single ~5s stall killed the
# session). This runs the real remote-connect.sh with stubbed ssh/tmux, captures
# the keepalive options passed to the attach, and asserts a sane tolerance.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if ! command -v timeout >/dev/null 2>&1; then printf 'test-reconnect: skip (timeout not available)\n'; exit 0; fi
WORK=$(mktemp -d "${TMPDIR:-/tmp}/tmmx-reconnect.XXXXXX")
BIN="$WORK/bin"; mkdir -p "$BIN"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT INT TERM

# Stub tmux: auto-reconnect on, everything else default (empty).
cat > "$BIN/tmux" <<'EOF'
#!/bin/sh
case "$*" in
  *"@tmmx_auto_reconnect"*) printf 'on\n' ;;
  *) : ;;
esac
EOF

# Stub ssh: discovery returns a tmux path; listing reports no server (so the
# picker is skipped); the attach records its args and returns cleanly.
cat > "$BIN/ssh" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$WORK/ssh.log"
case "\$*" in
  *__TMMX_BIN__*|*'command -v tmux'*) printf '__TMMX_BIN__/usr/bin/tmux\n'; exit 0 ;;
  *'list-sessions'*) printf 'no server running\n' >&2; exit 1 ;;
  *'new-session -A'*) exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$BIN/tmux" "$BIN/ssh"

# Direct mode (inner=main) skips the fzf picker; auto-reconnect never exits on its
# own, so bound it and read the attach it logged.
PATH="$BIN:$PATH" TMMX_DIR="$ROOT" TMMX_STATE_DIR="$WORK/state" \
  timeout 3 sh "$ROOT/scripts/remote-connect.sh" testhost main >/dev/null 2>&1 || true

attach=$(grep -m1 'new-session -A' "$WORK/ssh.log" 2>/dev/null || true)
[ -n "$attach" ] || { printf 'FAIL: no attach ssh call recorded\n' >&2; exit 1; }

interval=$(printf '%s\n' "$attach" | sed -n 's/.*ServerAliveInterval=\([0-9][0-9]*\).*/\1/p')
count=$(printf '%s\n' "$attach" | sed -n 's/.*ServerAliveCountMax=\([0-9][0-9]*\).*/\1/p')
[ -n "$interval" ] && [ -n "$count" ] || { printf 'FAIL: attach has no keepalive: [%s]\n' "$attach" >&2; exit 1; }

# CountMax=1 means a single missed probe drops the session — the regression.
[ "$count" -gt 1 ] || { printf 'FAIL: ServerAliveCountMax=%s is too aggressive (must be >1)\n' "$count" >&2; exit 1; }
# Require at least ~15s of tolerated silence before SSH gives up (5x1=5s was the bug).
[ "$((interval * count))" -ge 15 ] || { printf 'FAIL: keepalive tolerance %ss too short (interval %s x count %s)\n' "$((interval*count))" "$interval" "$count" >&2; exit 1; }

printf 'test-reconnect: ok (keepalive %ss x %s = %ss tolerance)\n' "$interval" "$count" "$((interval*count))"
