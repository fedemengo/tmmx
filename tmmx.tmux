#!/usr/bin/env sh

CURRENT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
outer_prefix=$(tmux show-options -gqv @tmmx_outer_prefix)
manager_key=$(tmux show-options -gqv @tmmx_manager_key)
picker_key=$(tmux show-options -gqv @tmmx_picker_key)
manager_picker_key=$(tmux show-options -gqv @tmmx_manager_picker_key)
popup_width=$(tmux show-options -gqv @tmmx_popup_width)
popup_height=$(tmux show-options -gqv @tmmx_popup_height)
[ -n "$outer_prefix" ] || outer_prefix='C-\'
[ -n "$manager_key" ] || manager_key='C-q'
[ -n "$picker_key" ] || picker_key='f'
[ -n "$manager_picker_key" ] || manager_picker_key='w'
case "$popup_width" in ''|*[!0-9%]*) popup_width='60%' ;; esac
case "$popup_height" in ''|*[!0-9%]*) popup_height='50%' ;; esac
previous_manager_key=$(tmux show-options -gqv @tmmx_bound_manager_key)
previous_manager_picker_key=$(tmux show-options -gqv @tmmx_bound_manager_picker_key)
forwarded_outer_prefix=$(printf '%s' "$outer_prefix" | sed 's/\\/\\\\/g')
forwarded_manager_key=$(printf '%s' "$manager_key" | sed 's/\\/\\\\/g')

tmux set-option -g @tmmx_path "$CURRENT_DIR"
tmux set-option -s set-clipboard on
tmux set-option -as terminal-features ',screen*:clipboard,alacritty:clipboard'
tmux bind-key -n "$outer_prefix" if-shell -F '#{==:#{@tmmx_remote},1}' "send-keys $forwarded_outer_prefix" 'switch-client -T prefix'
tmux bind-key "$picker_key" display-popup -E -w "$popup_width" -h "$popup_height" "TMMX_DIR='$CURRENT_DIR' sh '$CURRENT_DIR/scripts/picker.sh'"
tmux bind-key Space switch-client -l
tmux bind-key C-Tab switch-client -l
if [ -n "$previous_manager_key" ] && [ "$previous_manager_key" != "$manager_key" ]; then tmux unbind-key -n "$previous_manager_key"; fi
if [ -n "$previous_manager_picker_key" ] && [ "$previous_manager_picker_key" != "$manager_picker_key" ]; then tmux unbind-key -T tmmx-prefix "$previous_manager_picker_key"; fi
tmux unbind-key -T tmmx-prefix f
tmux unbind-key -T tmmx-prefix w
tmux bind-key -n "$manager_key" if-shell -F '#{==:#{@tmmx_managed},1}' 'switch-client -T tmmx-prefix' "send-keys $forwarded_manager_key"
tmux set-option -g @tmmx_bound_manager_key "$manager_key"
tmux set-option -g @tmmx_bound_manager_picker_key "$manager_picker_key"
tmux bind-key -T tmmx-prefix "$manager_picker_key" display-popup -E -w "$popup_width" -h "$popup_height" "TMMX_DIR='$CURRENT_DIR' sh '$CURRENT_DIR/scripts/manager-picker.sh' '#{client_tty}'" \; switch-client -T root
tmux bind-key -T tmmx-prefix Tab switch-client -l
tmux bind-key -T tmmx-prefix C-Tab switch-client -l
tmux run-shell "TMMX_DIR='$CURRENT_DIR' sh '$CURRENT_DIR/scripts/tag-sessions.sh'"
if [ "$(tmux show-options -gqv @tmmx_session_hook_installed)" != 1 ]; then
  tmux set-hook -ag session-created "run-shell \"TMMX_DIR='$CURRENT_DIR' sh '$CURRENT_DIR/scripts/tag-sessions.sh'\""
  tmux set-option -g @tmmx_session_hook_installed 1
fi
