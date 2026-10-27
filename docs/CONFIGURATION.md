# Configuration

Set these options before TPM loads tmmx. Popup size is re-read each time a picker opens; the rest are read when the plugin loads.

```tmux
set -g @tmmx_outer_prefix 'C-\'
set -g @tmmx_manager_key 'C-q'
set -g @tmmx_picker_key 'f'
set -g @tmmx_manager_picker_key 'w'
set -g @tmmx_previous_key 'C-Tab'
set -g @tmmx_nav_key 'C-`'
set -g @tmmx_manager_local_sessions 'all'   # or 'host' for one @local-host row
set -g @tmmx_popup_width '60%'
set -g @tmmx_popup_height '50%'
set -g @tmmx_auto_reconnect 'off'
set -g @tmmx_reconnect_on_input 'on'        # hold a dropped frame on screen until you type
set -g @tmmx_reconnect_delay 2
set -g @tmmx_reconnect_max 60
set -g @tmmx_server_alive_interval 5
set -g @tmmx_server_alive_count 3
set -g @tmmx_auto_restore 'off'
set -g @tmmx_restore_grace 5
set -g @tmmx_manager_host 'local-host'
set -g @tmmx_host_colors 'personal-host=#a3be8c,work-host=#ff9e64'
```

## Keys

tmmx enables tmux's `extended-keys` so chords like `Ctrl-Tab` arrive as distinct keys; this needs a terminal that supports extended key reporting (Alacritty, kitty, WezTerm, iTerm2).

The outer prefix (`@tmmx_outer_prefix`) is an extra tmux root binding. In local sessions it opens the local prefix table. In a managed SSH wrapper it opens a table where the manager picker key is handled locally and every other key is forwarded to the remote tmux after the outer prefix.

## Reconnect

`@tmmx_auto_reconnect` retries a managed SSH connection after a network drop. It uses capped exponential backoff — starting at `@tmmx_reconnect_delay` and doubling up to `@tmmx_reconnect_max` seconds — so a host that stays unreachable is retried slowly rather than hammered; any successful step resets the delay.

A live attach uses an SSH keepalive (`@tmmx_server_alive_interval` seconds × `@tmmx_server_alive_count` probes; ~15s of silence by default) to notice a truly dead link so it can reconnect, without dropping a healthy session on a brief stall.

With `@tmmx_reconnect_on_input` on (the default), a dropped session's last frame stays on screen and reconnects only when you press a key, so you can keep reading a disconnected session. A host that was never up still retries in the background without a keypress.

Automatic reconnect and restore are reliable only when SSH authentication is non-interactive: an agent-loaded key, an unprotected key, or a key whose passphrase is already cached. This applies to both `@host` and `ssh user@host` targets. A password or passphrase prompt during a reconnect blocks the wrapper until it is answered.

## Restore

With `@tmmx_auto_restore` enabled, a recovered host with no tmux server is bootstrapped and its configured `@resurrect-restore-script-path` is invoked before tmmx reattaches. Restore is attempted once per outage and waits up to `@tmmx_restore_grace` seconds for the requested session.

After a tmux-resurrect restore, a managed remote wrapper comes back as a plain shell because resurrect does not re-run its ssh. tmmx reopens it: switching to such a wrapper reconnects it on the spot, on the session it was last on. With `@tmmx_auto_reconnect` on, restored wrappers are also reopened in the background after the restore, one at a time, without waiting for you to visit them.

State (each wrapper's last session) and per-host logs live under `~/.local/share/tmmx`; override the directory with `TMMX_STATE_DIR`.

## Colors

`@tmmx_host_colors` keys can be a host alias or a complete `user@host` destination. A `user@host` entry matches only that destination; a host alias also colors every `user@host` destination for that host.

## Other

- tmux normalizes `.` and `:` in session names to `_`; tmmx follows that rule. New session names containing tabs or `|` are rejected because they cannot be represented safely in picker entries.
- Set `TMMX_REMOTE_TMUX` in tmux's server environment when a remote host needs an explicit tmux binary path.
