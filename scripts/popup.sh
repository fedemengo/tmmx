#!/bin/sh

# Opens a picker popup, reading the popup size when the key is pressed so that
# changing @tmmx_popup_width or @tmmx_popup_height takes effect immediately.
client_tty=$1
kind=$2
width=$(tmux show-options -gqv @tmmx_popup_width)
height=$(tmux show-options -gqv @tmmx_popup_height)
case "$width" in ''|*[!0-9%]*) width='60%' ;; esac
case "$height" in ''|*[!0-9%]*) height='50%' ;; esac
case "$kind" in
  manager) command="TMMX_DIR='$TMMX_DIR' sh '$TMMX_DIR/scripts/manager-picker.sh' '$client_tty'" ;;
  *) command="TMMX_DIR='$TMMX_DIR' sh '$TMMX_DIR/scripts/picker.sh'" ;;
esac
exec tmux display-popup -E -c "$client_tty" -w "$width" -h "$height" "$command"
