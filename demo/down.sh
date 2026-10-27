#!/bin/sh
# Tear down the demo hosts and remove the generated ssh config snippet.
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMMX_DEMO_KEYS_DIR="$dir/.keys" docker compose -f "$dir/compose.yaml" down -v --remove-orphans || true
rm -f "$HOME/.ssh/tmmx-demo.config"
printf '✓ demo hosts down, ssh snippet removed.\n'
printf 'You can delete the Include line from ~/.ssh/config (it now points at nothing).\n'
