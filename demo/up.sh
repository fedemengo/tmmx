#!/bin/sh
# Build and start the four demo hosts, and generate the demo ssh key. Does not
# touch your ~/.ssh or your tmux — recording happens in an isolated sandbox via
# demo/record.sh.
set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
keys="$dir/.keys"

mkdir -p "$keys"
[ -f "$keys/id_ed25519" ] || ssh-keygen -q -t ed25519 -N '' -f "$keys/id_ed25519" -C tmmx-demo
chmod 600 "$keys/id_ed25519"

TMMX_DEMO_KEYS_DIR="$keys" docker compose -f "$dir/compose.yaml" up -d --build

printf '\n✓ demo hosts up: web(2201) api(2202) db(2203) worker(2204)\n'
printf 'Record in an isolated tmmx (shows only the demo hosts):\n\n    demo/record.sh\n\n'
printf 'Tear everything down with:  demo/down.sh\n'
