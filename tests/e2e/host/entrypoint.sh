#!/bin/sh

set -eu
install -m 600 -o tmmx -g tmmx /keys/id_ed25519.pub /home/tmmx/.ssh/authorized_keys
exec /usr/sbin/sshd -D -e
