#!/bin/sh

set -eu

mkdir -p /root/.ssh
cat > /root/.ssh/config <<'EOF'
Host host
  HostName host
  User tmmx
  IdentityFile /keys/id_ed25519
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
Host host-alias
  HostName host
  User nobody-else
  IdentityFile /keys/id_ed25519
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR
  RequestTTY force
  RemoteCommand exec /bin/sh -i
EOF
chmod 600 /root/.ssh/config

ssh host 'tmux -V' | grep -q '^tmux '

# The host shell always writes a banner. The discovery sentinel must be the only
# input tmmx accepts as the remote tmux binary.
remote_tmux_bin=$(ssh host 'PATH=$HOME/.local/bin:$HOME/bin:$PATH; export PATH; tmmx_tmux=$(command -v tmux); [ -n "$tmmx_tmux" ] && printf "__TMMX_BIN__%s\\n" "$tmmx_tmux"' | sed -n 's/^__TMMX_BIN__//p' | sed -n '1p')
[ "$remote_tmux_bin" = /usr/bin/tmux ]

# There is intentionally no remote tmux server yet. Run the real connection
# script in a pseudo-terminal; timeout ends its interactive attach after main is
# created. A timeout status is expected.
set +e
timeout -k 2 5 script -q -c 'TMMX_DIR=/src sh /src/scripts/remote-connect.sh host' /dev/null >/tmp/tmmx-e2e-connect.log 2>&1
status=$?
set -e
case "$status" in 124|137) ;; *) cat /tmp/tmmx-e2e-connect.log >&2; exit 1 ;; esac
ssh host 'tmux has-session -t =main'

# Listing through the real remote shell still contains a banner, while its
# sentinel records remain unambiguous and sortable by callers.
ssh host 'tmux new-session -d -s later'
sessions=$(ssh host 'tmux list-sessions -F "__TMMX_SESSION__#{session_name}"' | sed -n 's/^__TMMX_SESSION__//p' | sort)
[ "$sessions" = 'later
main' ]

# fzf's noninteractive filter mode selects an existing remote session through
# the real binary. The timed attach must not create a duplicate session.
set +e
FZF_DEFAULT_OPTS='--filter=later' timeout -k 2 5 script -q -c 'TMMX_DIR=/src sh /src/scripts/remote-connect.sh host' /dev/null >/tmp/tmmx-e2e-existing.log 2>&1
status=$?
set -e
case "$status" in 124|137) ;; *) cat /tmp/tmmx-e2e-existing.log >&2; exit 1 ;; esac
ssh host 'tmux has-session -t =later'

# An explicit user@host destination reuses the Host entry's key and reaches the
# same tmux server, so the existing session is selected instead of duplicated.
set +e
FZF_DEFAULT_OPTS='--filter=later' timeout -k 2 5 script -q -c 'TMMX_DIR=/src sh /src/scripts/remote-connect.sh tmmx@host' /dev/null >/tmp/tmmx-e2e-user.log 2>&1
status=$?
set -e
case "$status" in 124|137) ;; *) cat /tmp/tmmx-e2e-user.log >&2; exit 1 ;; esac
sessions=$(ssh host 'tmux list-sessions -F "__TMMX_SESSION__#{session_name}"' | sed -n 's/^__TMMX_SESSION__//p' | sort)
[ "$sessions" = 'later
main' ]

# A Host entry whose User, RemoteCommand, and RequestTTY would each defeat tmmx:
# the explicit user replaces User, and tmmx overrides the other two itself.
set +e
FZF_DEFAULT_OPTS='--filter=later' timeout -k 2 5 script -q -c 'TMMX_DIR=/src sh /src/scripts/remote-connect.sh tmmx@host-alias' /dev/null >/tmp/tmmx-e2e-alias.log 2>&1
status=$?
set -e
case "$status" in 124|137) ;; *) cat /tmp/tmmx-e2e-alias.log >&2; exit 1 ;; esac
sessions=$(ssh host 'tmux list-sessions -F "__TMMX_SESSION__#{session_name}"' | sed -n 's/^__TMMX_SESSION__//p' | sort)
[ "$sessions" = 'later
main' ]

# A normally ending remote session must return to the host picker. This small
# fzf driver accepts one-shot on its first call and cancels the next picker.
# Wait until it has a real SSH client, then end it to avoid a timing race.
ssh host 'tmux new-session -d -s one-shot "sleep 60"'
mkdir -p /tmp/tmmx-e2e-bin
ln -sf /usr/local/bin/tmmx-e2e-fzf-flow /tmp/tmmx-e2e-bin/fzf
PATH=/tmp/tmmx-e2e-bin:$PATH TMMX_DIR=/src timeout -k 2 20 script -q -c 'sh /src/scripts/remote-connect.sh host' /dev/null >/tmp/tmmx-e2e-exit.log 2>&1 &
picker_pid=$!
attached=0
attempt=0
while [ "$attempt" -lt 100 ]; do
  if ssh host 'tmux list-clients -F "#{client_session}" | grep -qx one-shot'; then attached=1; break; fi
  attempt=$((attempt + 1))
  sleep 0.1
done
[ "$attached" = 1 ] || { kill "$picker_pid" 2>/dev/null || true; wait "$picker_pid" 2>/dev/null || true; cat /tmp/tmmx-e2e-exit.log >&2; exit 1; }
ssh host 'tmux kill-session -t =one-shot'
set +e
wait "$picker_pid"
status=$?
set -e
[ "$status" -eq 0 ] || { cat /tmp/tmmx-e2e-exit.log >&2; exit 1; }
ssh host '! tmux has-session -t =one-shot'

# A host restart drops the SSH transport. The managed wrapper must stay alive,
# restore the requested session once, and reattach after the controller restarts
# the host container.
tmux new-session -d -s tmmx-e2e-local
tmux set-option -g @tmmx_auto_reconnect on
tmux set-option -g @tmmx_reconnect_delay 1
tmux set-option -g @tmmx_auto_restore on
tmux set-option -g @tmmx_restore_grace 10
ssh host 'tmux new-session -d -s restored "sleep 60"'
rm -f /tmp/tmmx-e2e-fzf-calls
TMMX_E2E_FZF_SESSION=restored PATH=/tmp/tmmx-e2e-bin:$PATH TMMX_DIR=/src script -q -c 'sh /src/scripts/remote-connect.sh host' /dev/null >/tmp/tmmx-e2e-recovery.log 2>&1 &
recovery_pid=$!
attached=0
attempt=0
while [ "$attempt" -lt 100 ]; do
  if ssh host 'tmux list-clients -F "#{client_session}" | grep -qx restored'; then attached=1; break; fi
  attempt=$((attempt + 1))
  sleep 0.1
done
[ "$attached" = 1 ] || { kill "$recovery_pid" 2>/dev/null || true; wait "$recovery_pid" 2>/dev/null || true; cat /tmp/tmmx-e2e-recovery.log >&2; exit 1; }
touch /signals/recovery-attached
printf '%s\n' 'recovery test: host attached; waiting for crash' >&2
attempt=0
while [ ! -f /signals/host-restarted ] && [ "$attempt" -lt 200 ]; do attempt=$((attempt + 1)); sleep 0.1; done
[ -f /signals/host-restarted ] || { kill "$recovery_pid" 2>/dev/null || true; wait "$recovery_pid" 2>/dev/null || true; cat /tmp/tmmx-e2e-recovery.log >&2; exit 1; }
printf '%s\n' 'recovery test: host recreated; waiting for restore' >&2
attached=0
attempt=0
while [ "$attempt" -lt 60 ]; do
  if ssh host 'test -f /tmp/tmmx-e2e-restored && tmux list-clients -F "#{client_session}" | grep -qx restored'; then attached=1; break; fi
  attempt=$((attempt + 1))
  sleep 1
done
[ "$attached" = 1 ] || { kill "$recovery_pid" 2>/dev/null || true; wait "$recovery_pid" 2>/dev/null || true; cat /tmp/tmmx-e2e-recovery.log >&2; exit 1; }
touch /signals/recovery-complete
kill "$recovery_pid" 2>/dev/null || true
wait "$recovery_pid" 2>/dev/null || true

printf '%s\n' 'tmmx E2E: fresh host and noisy shell passed'
