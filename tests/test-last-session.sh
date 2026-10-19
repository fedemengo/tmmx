#!/bin/sh
# Regression guard: reconnecting / reopening a remote wrapper must land on the
# host's most-recently-used session, not snap back to a frozen session name.
#
# The bug: the attach was `tmux new-session -A -s "$session"` with $session fixed
# for the wrapper's life, so every reconnect force-attached to that one name --
# usually the stale "main" remembered from the first connect -- throwing the user
# off whatever session they were actually on. The fix attaches with a bare
# `attach-session` (most recent), creating the remembered name only when the host
# has no sessions. An explicit picker choice still gets its own exact attach, but
# that path needs fzf and is not exercised here.
#
# Runs the real remote-connect.sh in direct mode (which is how a reopen attaches)
# with stubbed ssh/tmux and inspects the attach command.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if ! command -v timeout >/dev/null 2>&1; then printf 'test-last-session: skip (timeout not available)\n'; exit 0; fi
WORK=$(mktemp -d "${TMPDIR:-/tmp}/tmmx-last.XXXXXX")
BIN="$WORK/bin"; mkdir -p "$BIN"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT INT TERM

# Stub tmux: auto-reconnect on, everything else default.
cat > "$BIN/tmux" <<'EOF'
#!/bin/sh
case "$*" in
  *"@tmmx_auto_reconnect"*) printf 'on\n' ;;
  *) : ;;
esac
EOF

# Stub ssh: discovery returns a tmux path; the interactive attach (the only call
# carrying keepalive options) records its args and returns cleanly.
cat > "$BIN/ssh" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$WORK/ssh.log"
case "\$*" in
  *__TMMX_BIN__*|*'command -v tmux'*) printf '__TMMX_BIN__/usr/bin/tmux\n'; exit 0 ;;
  *ServerAliveInterval*) exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$BIN/tmux" "$BIN/ssh"

# Direct mode (inner=main) is the reopen path: it skips the picker and attaches.
PATH="$BIN:$PATH" TMMX_DIR="$ROOT" TMMX_STATE_DIR="$WORK/state" \
  timeout 3 sh "$ROOT/scripts/remote-connect.sh" testhost main >/dev/null 2>&1 || true

attach=$(grep -m1 'ServerAliveInterval' "$WORK/ssh.log" 2>/dev/null || true)
[ -n "$attach" ] || { printf 'FAIL: no attach ssh call recorded\n' >&2; exit 1; }

# Must attach to the most-recently-used session, not a frozen name.
case "$attach" in
  *attach-session*) ;;
  *) printf 'FAIL: reopen attach does not use attach-session (most recent): [%s]\n' "$attach" >&2; exit 1 ;;
esac
# The old bug: force-attach to a fixed name on every connect.
case "$attach" in
  *'new-session -A'*) printf 'FAIL: reopen still force-attaches a fixed session (new-session -A): [%s]\n' "$attach" >&2; exit 1 ;;
  *) ;;
esac
# A fallback to create the remembered name only when the host is empty is fine.
case "$attach" in
  *'new-session -s'*) ;;
  *) printf 'FAIL: attach has no empty-host fallback (new-session -s): [%s]\n' "$attach" >&2; exit 1 ;;
esac

printf 'test-last-session: ok (reopen/reconnect attaches to most-recent session)\n'
