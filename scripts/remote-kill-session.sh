#!/bin/sh

host=$1
tmux_bin=$2
session=$3

quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

printf 'Kill session %s on %s? [y/N] ' "$session" "$host" >/dev/tty
IFS= read -r answer </dev/tty || exit 1
case "$answer" in
  y|Y) ssh "$host" "PATH=\$HOME/.local/bin:\$HOME/bin:\$PATH; export PATH; exec $(quote "$tmux_bin") kill-session -t $(quote "=$session")" ;;
esac
