#!/bin/sh
# Tear down the demo hosts and the isolated recording sandbox. Touches nothing of
# your real tmux or ~/.ssh.
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

TMMX_DEMO_KEYS_DIR="$dir/.keys" docker compose -f "$dir/compose.yaml" down -v --remove-orphans || true

# Kill the isolated recording server and remove the sandbox.
real_tmux=$(command -v tmux 2>/dev/null || true)
[ -n "$real_tmux" ] && "$real_tmux" -L tmmx-demo kill-server 2>/dev/null || true
rm -rf "$dir/.sandbox"

# Clean up the ssh snippet an older up.sh may have written.
rm -f "$HOME/.ssh/tmmx-demo.config"

printf '✓ demo hosts down, sandbox removed. Your tmux and ~/.ssh are untouched.\n'
