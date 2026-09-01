#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
keys_dir=$(mktemp -d "${TMPDIR:-/tmp}/tmmx-e2e.XXXXXX")
signals_dir=$(mktemp -d "${TMPDIR:-/tmp}/tmmx-e2e-signals.XXXXXX")
compose_file="$root/tests/e2e/compose.yaml"
log_file=${TMMX_E2E_LOG:-"${TMPDIR:-/tmp}/tmmx-e2e.log"}
docker info >/dev/null 2>&1 || {
  printf '%s\n' 'tmmx E2E requires a running Docker daemon.' >&2
  exit 1
}
cleanup() {
  TMMX_E2E_KEYS_DIR="$keys_dir" TMMX_E2E_SIGNALS_DIR="$signals_dir" docker compose -f "$compose_file" down --volumes --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$keys_dir"
  rm -rf "$signals_dir"
}
trap cleanup EXIT INT TERM

ssh-keygen -q -t ed25519 -N '' -f "$keys_dir/id_ed25519"
export TMMX_E2E_KEYS_DIR="$keys_dir"
export TMMX_E2E_SIGNALS_DIR="$signals_dir"
docker compose -f "$compose_file" up --build --wait host
(
  attempt=0
  while [ ! -f "$signals_dir/recovery-attached" ] && [ "$attempt" -lt 300 ]; do attempt=$((attempt + 1)); sleep 0.1; done
  [ -f "$signals_dir/recovery-attached" ] || exit 1
  # A graceful `restart` lets tmux close its client normally, which is
  # indistinguishable from intentionally ending a remote session. Recreate the
  # host with SIGKILL so the client observes the SSH transport failure that a
  # laptop sleep or host crash produces.
  docker compose -f "$compose_file" kill host
  docker compose -f "$compose_file" rm --force host
  docker compose -f "$compose_file" up --wait host
  touch "$signals_dir/host-restarted"
  attempt=0
  while [ ! -f "$signals_dir/recovery-complete" ] && [ "$attempt" -lt 300 ]; do attempt=$((attempt + 1)); sleep 0.1; done
  [ -f "$signals_dir/recovery-complete" ]
) &
controller_pid=$!
set +e
# Keep the tester container after a failure: `compose logs` then includes the
# wrapper's pseudo-terminal transcript, which is where recovery diagnostics
# are emitted.
docker compose -f "$compose_file" up --build --abort-on-container-exit --exit-code-from tester tester
status=$?
wait "$controller_pid"
controller_status=$?
set -e
[ "$controller_status" -eq 0 ] || status=1
if [ "$status" -ne 0 ]; then
  mkdir -p "$(dirname "$log_file")"
  docker compose -f "$compose_file" logs --no-color >"$log_file" 2>&1 || true
  cat "$log_file" >&2
fi
exit "$status"
