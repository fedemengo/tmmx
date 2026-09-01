#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
keys_dir=$(mktemp -d "${TMPDIR:-/tmp}/tmmx-e2e.XXXXXX")
compose_file="$root/tests/e2e/compose.yaml"
log_file=${TMMX_E2E_LOG:-"${TMPDIR:-/tmp}/tmmx-e2e.log"}
docker info >/dev/null 2>&1 || {
  printf '%s\n' 'tmmx E2E requires a running Docker daemon.' >&2
  exit 1
}
cleanup() {
  TMMX_E2E_KEYS_DIR="$keys_dir" docker compose -f "$compose_file" down --volumes --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$keys_dir"
}
trap cleanup EXIT INT TERM

ssh-keygen -q -t ed25519 -N '' -f "$keys_dir/id_ed25519"
export TMMX_E2E_KEYS_DIR="$keys_dir"
set +e
docker compose -f "$compose_file" up --build --abort-on-container-exit --exit-code-from tester
status=$?
set -e
if [ "$status" -ne 0 ]; then
  mkdir -p "$(dirname "$log_file")"
  docker compose -f "$compose_file" logs --no-color >"$log_file" 2>&1 || true
  cat "$log_file" >&2
fi
exit "$status"
