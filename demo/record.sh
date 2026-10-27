#!/bin/sh
# Launch tmmx in a fully isolated sandbox for recording: a separate tmux socket
# (so none of your real local sessions show), a separate $HOME with an ssh config
# listing only the demo hosts (so @ lists only those), and a separate state dir.
# Your real tmux and ~/.ssh are never touched. Run demo/up.sh first.
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$dir/.." && pwd)
keys="$dir/.keys"
[ -f "$keys/id_ed25519" ] || { printf 'run demo/up.sh first (no demo key yet)\n' >&2; exit 1; }

sandbox="$dir/.sandbox"
rm -rf "$sandbox"
mkdir -p "$sandbox/.ssh" "$sandbox/.local/share/tmmx" "$sandbox/bin"

# ssh config: only the demo hosts, each on its published localhost port.
cat > "$sandbox/.ssh/config" <<EOF
Host web api db worker
  HostName 127.0.0.1
  User tmmx
  IdentityFile $keys/id_ed25519
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
Host web
  Port 2201
Host api
  Port 2202
Host db
  Port 2203
Host worker
  Port 2204
EOF
chmod 700 "$sandbox/.ssh"; chmod 600 "$sandbox/.ssh/config"

# A clean-looking throwaway tmux.conf for the recording.
cat > "$sandbox/.tmux.conf" <<'EOF'
set -g mouse on
set -g status-style 'bg=default fg=white'
set -g status-left ' tmmx '
set -g status-right ' %H:%M '
set -g status-left-length 20
EOF

# PATH shim: every bare `tmux` call (tmmx.tmux, popups, scripts) targets an
# isolated server on socket tmmx-demo. The server inherits this PATH, so popups
# stay isolated too. Same mechanism the test harness uses.
real_tmux=$(command -v tmux)
cat > "$sandbox/bin/tmux" <<EOF
#!/bin/sh
exec "$real_tmux" -L tmmx-demo "\$@"
EOF
chmod +x "$sandbox/bin/tmux"

# Start fresh in case a previous recording left the isolated server running.
"$real_tmux" -L tmmx-demo kill-server 2>/dev/null || true

HOME="$sandbox" TMMX_STATE_DIR="$sandbox/.local/share/tmmx" PATH="$sandbox/bin:$PATH" \
  exec sh "$repo/bin/tmmx"
