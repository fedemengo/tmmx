#!/bin/sh

session=$1
printf 'Kill session %s? [y/N] ' "$session" >/dev/tty
IFS= read -r answer </dev/tty || exit 1
case "$answer" in y|Y) tmux kill-session -t "=$session" ;; esac
