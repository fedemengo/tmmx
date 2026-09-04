#!/usr/bin/env sh

CURRENT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
outer_prefix=$(tmux show-options -gqv @tmmx_outer_prefix)
manager_key=$(tmux show-options -gqv @tmmx_manager_key)
picker_key=$(tmux show-options -gqv @tmmx_picker_key)
manager_picker_key=$(tmux show-options -gqv @tmmx_manager_picker_key)
previous_key=$(tmux show-options -gqv @tmmx_previous_key)
[ -n "$outer_prefix" ] || outer_prefix='C-\'
[ -n "$manager_key" ] || manager_key='C-q'
[ -n "$picker_key" ] || picker_key='f'
[ -n "$manager_picker_key" ] || manager_picker_key='w'
[ -n "$previous_key" ] || previous_key='C-Tab'
previous_manager_key=$(tmux show-options -gqv @tmmx_bound_manager_key)
previous_manager_picker_key=$(tmux show-options -gqv @tmmx_bound_manager_picker_key)
previous_previous_key=$(tmux show-options -gqv @tmmx_bound_previous_key)
forwarded_outer_prefix=$(printf '%s' "$outer_prefix" | sed 's/\\/\\\\/g')
forwarded_manager_key=$(printf '%s' "$manager_key" | sed 's/\\/\\\\/g')
forwarded_previous_key=$(printf '%s' "$previous_key" | sed 's/\\/\\\\/g')
manager_popup="TMMX_DIR='$CURRENT_DIR' sh '$CURRENT_DIR/scripts/popup.sh' '#{client_tty}' manager"

tmux set-option -g @tmmx_path "$CURRENT_DIR"
tmux set-option -s set-clipboard on
tmux set-option -as terminal-features ',screen*:clipboard,alacritty:clipboard,alacritty:extkeys'
# Ctrl-Tab and similar chords only reach tmux as distinct keys when it asks the
# terminal for extended key reporting.
tmux set-option -s extended-keys on
# Locally the outer prefix opens the prefix table. Inside a managed remote
# wrapper it opens the tmmx-outer table instead: the manager picker key is
# handled here, and every other key is re-sent to the remote tmux after the
# outer prefix, so the remote sees the same chord it would have seen directly.
tmux bind-key -n "$outer_prefix" if-shell -F '#{==:#{@tmmx_remote},1}' 'switch-client -T tmmx-outer' 'switch-client -T prefix'
tmux bind-key "$picker_key" run-shell -b "TMMX_DIR='$CURRENT_DIR' sh '$CURRENT_DIR/scripts/popup.sh' '#{client_tty}' picker"
tmux bind-key "$manager_picker_key" run-shell -b "$manager_popup"
tmux bind-key Tab switch-client -l
tmux bind-key Space switch-client -l
tmux bind-key C-Tab switch-client -l
tmux unbind-key -a -T tmmx-outer 2>/dev/null || true
tmux bind-key -T tmmx-outer "$manager_picker_key" run-shell -b "$manager_popup"
forward() { [ "$1" = "$manager_picker_key" ] || tmux bind-key -T tmmx-outer "$1" send-keys "$outer_prefix" "$1"; }
code=33
while [ "$code" -le 126 ]; do
  key=$(printf "\\$(printf '%03o' "$code")")
  case "$key" in
    # A semicolon inside a bound command is a command separator, so ; is sent
    # as its hex code in a second command.
    ';') [ "$manager_picker_key" = ';' ] || tmux bind-key -T tmmx-outer '\;' send-keys "$outer_prefix" '\;' send-keys -H 3b ;;
    *) forward "$key" ;;
  esac
  code=$((code + 1))
done
for key in Space Tab BTab Enter Escape BSpace Up Down Left Right Home End PPage NPage IC DC \
  C-a C-b C-c C-d C-e C-f C-g C-h C-j C-k C-l C-m C-n C-o C-p C-q C-r C-s C-t C-u C-v C-w C-x C-y C-z C-Tab C-Space "$outer_prefix"; do forward "$key"; done
if [ -n "$previous_manager_key" ] && [ "$previous_manager_key" != "$manager_key" ]; then tmux unbind-key -n "$previous_manager_key"; fi
if [ -n "$previous_manager_picker_key" ] && [ "$previous_manager_picker_key" != "$manager_picker_key" ]; then
  tmux unbind-key -T tmmx-prefix "$previous_manager_picker_key"
  # The old manager key may be the host picker key, which is bound above.
  [ "$previous_manager_picker_key" = "$picker_key" ] || tmux unbind-key "$previous_manager_picker_key"
fi
if [ -n "$previous_previous_key" ] && [ "$previous_previous_key" != "$previous_key" ]; then tmux unbind-key -n "$previous_previous_key"; fi
tmux unbind-key -T tmmx-prefix f
tmux unbind-key -T tmmx-prefix w
tmux bind-key -n "$manager_key" if-shell -F '#{==:#{@tmmx_managed},1}' 'switch-client -T tmmx-prefix' "send-keys $forwarded_manager_key"
tmux set-option -g @tmmx_bound_manager_key "$manager_key"
tmux set-option -g @tmmx_bound_manager_picker_key "$manager_picker_key"
# Previous manager-level session: works from every managed session, including
# remote wrappers, because it is handled locally before the pane sees it.
tmux bind-key -n "$previous_key" if-shell -F '#{==:#{@tmmx_managed},1}' 'switch-client -l' "send-keys $forwarded_previous_key"
tmux set-option -g @tmmx_bound_previous_key "$previous_key"
tmux bind-key -T tmmx-prefix "$manager_picker_key" run-shell -b "$manager_popup" \; switch-client -T root
tmux bind-key -T tmmx-prefix Tab switch-client -l
tmux bind-key -T tmmx-prefix C-Tab switch-client -l
tmux run-shell "TMMX_DIR='$CURRENT_DIR' sh '$CURRENT_DIR/scripts/tag-sessions.sh'"
if [ "$(tmux show-options -gqv @tmmx_session_hook_installed)" != 1 ]; then
  tmux set-hook -ag session-created "run-shell \"TMMX_DIR='$CURRENT_DIR' sh '$CURRENT_DIR/scripts/tag-sessions.sh'\""
  tmux set-option -g @tmmx_session_hook_installed 1
fi
