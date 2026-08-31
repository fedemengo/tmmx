#!/bin/sh

tmux list-sessions -F '#{session_name}' | while IFS= read -r session; do
  tmux set-option -t "=$session:" @tmmx_managed 1
  case "$session" in
    __tmmx_remote__*|__remote__*)
      tmux set-option -t "=$session:" @tmmx_remote 1
      case "$session" in
        __tmmx_remote__*) host=${session#__tmmx_remote__} ;;
        __remote__*) host=${session#__remote__} ;;
      esac
      existing_host=$(tmux show-option -t "=$session:" -qv @tmmx_host)
      [ -n "$existing_host" ] || tmux set-option -t "=$session:" @tmmx_host "$host"
      existing_mouse=$(tmux show-option -t "=$session:" -qv mouse)
      [ -n "$existing_mouse" ] || tmux set-option -t "=$session:" mouse off
      ;;
    '~tmmx'|'~manager') tmux set-option -t "=$session:" @tmmx_manager 1 ;;
  esac
done
