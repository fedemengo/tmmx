#!/bin/sh
# Authorize the demo key, seed this host's tmux sessions as the tmmx user, then
# run sshd in the foreground.
set -eu

install -m 600 -o tmmx -g tmmx /keys/id_ed25519.pub /home/tmmx/.ssh/authorized_keys

# Seed under the tmmx user's own tmux server so the sessions are there when you
# ssh in. DEMO_ROLE picks which sessions this host gets.
su - tmmx -c "DEMO_ROLE='${DEMO_ROLE:-web}' /usr/local/bin/tmmx-demo-seed" || true

exec /usr/sbin/sshd -D -e
