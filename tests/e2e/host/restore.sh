#!/bin/sh

touch /tmp/tmmx-e2e-restored
tmux new-session -d -s restored 'sleep 60' 2>/dev/null || true
