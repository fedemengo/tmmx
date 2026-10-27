# tmmx

`tmmx` is a host-aware tmux session manager: one local tmux server that switches between local workspaces and SSH-backed remote tmux sessions.

## Requirements

tmux 3.2+, fzf 0.36+ (locally and on each remote host where you use the picker), and SSH access to your remote hosts.

## Install

```tmux
set -g @plugin 'fedemengo/tmmx'
```

Install TPM plugins, then the launcher:

```sh
make -C ~/.tmux/plugins/tmmx install
```

Run `tmmx` to create or attach to the `~tmmx` manager session. Install the plugin (no launcher needed) on remote hosts too, for `Ctrl-\ f`, clipboard forwarding, and per-host switching inside their tmux servers.

## Controls

- `Ctrl-\ w` — manager picker. Type `name` (local session), `@host` (SSH tmux session), or `ssh user@host` (connect as a specific user).
- `Ctrl-\ f` — create-or-switch picker for the current tmux server.
- `Ctrl-\ Tab` / `Ctrl-\ Space` — previous session on the current server.
- `Ctrl-Tab` — previous manager-level session, from any managed session including remote wrappers.
- `` Ctrl-` `` then `1`/`2`/`3` — scoped previous switch: window / session-on-host / across-hosts. In a remote wrapper `1` and `2` act on that host. Prefix set by `@tmmx_nav_key`.
- `Ctrl-q w` / `Ctrl-q Tab` — the manager picker and previous manager-level session, on the manager key table.
- `Ctrl-x` — close the highlighted session or remote connection (kills the remote session in a host picker). Confirmation required.

Inside a remote wrapper, `Ctrl-\ w` opens the local manager; every other `Ctrl-\` chord is forwarded to the remote tmux, so `Ctrl-\ f` and `Ctrl-\ Tab` act there.

Pickers start in **scroll mode** (printable keys ignored except navigation): `j`/`k` row, `Ctrl-d`/`Ctrl-u` half-page, `Ctrl-f`/`Ctrl-b` page, `g`/`G` first/last, `1`–`9` jump to and select that row. `i` (or `@`) enters **insert mode** to type; `Ctrl-j` returns to scroll. `Tab` completes the highlighted row; `Enter`/`Esc` work in both modes.

## Remote workflow

Typing `@host` creates a local wrapper session, runs `ssh host`, and lets you pick or create a tmux session there. Ending the inner session returns to that host's picker; `Esc` returns to the local manager. Reconnect and reopen reattach to the session you were last on.

Once the query contains `@`, the manager also lists `~/.ssh/config` hosts (marked `ssh config`) below matching sessions — `@` lists them as `@host`, `user@` as `user@host`. `Include` is followed; wildcards are skipped. Selecting one connects as typing it would.

`@host` connects as the user from your SSH config; `ssh user@host` overrides only the user (the host's `Host` entry — keys, `ProxyJump`, etc. — still applies). The full destination is kept for the wrapper's lifetime, so reconnect, restore, and remote kill all reuse it. Use `ProxyJump` for hosts behind a bastion.

Automatic reconnect and restore work only with non-interactive SSH auth (an agent-loaded or passphrase-cached key); a prompt blocks the wrapper until answered.

## Configuration

Set before TPM loads tmmx (popup size is re-read each time a picker opens; the rest at load):

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

- **Keys** — tmmx enables tmux `extended-keys` so chords like `Ctrl-Tab` arrive distinctly; needs a terminal that supports it (Alacritty, kitty, WezTerm, iTerm2). The outer prefix opens the local prefix table locally, or the forwarding table inside a remote wrapper.
- **Reconnect** — `@tmmx_auto_reconnect` retries a dropped SSH connection with capped exponential backoff (`@tmmx_reconnect_delay`→`@tmmx_reconnect_max`), using an SSH keepalive (`@tmmx_server_alive_interval` × `@tmmx_server_alive_count`, ~15s) to detect a dead link without dropping a healthy one. With `@tmmx_reconnect_on_input` on, a dropped session's last frame stays on screen until you press a key.
- **Restore** — with `@tmmx_auto_restore`, a recovered host with no tmux server is bootstrapped and its `@resurrect-restore-script-path` run (once per outage, waiting up to `@tmmx_restore_grace`s). After a resurrect restore, remote wrappers reopen on the session they were on; with auto-reconnect on, in the background too. State and per-host logs live under `~/.local/share/tmmx` (`TMMX_STATE_DIR` to override).
- **Colors** — `@tmmx_host_colors` keys are a host alias or a full `user@host`; an alias colors every `user@host` destination for that host.

## Notes

- tmux normalizes `.`/`:` to `_` in session names; tmmx follows suit. Names with tabs or `|` are rejected.
- Set `TMMX_REMOTE_TMUX` in tmux's server environment when a remote host needs an explicit tmux path.

## Development

`make test` runs the shell checks. `make test-e2e` spins up disposable Docker containers (real SSH + tmux) to verify fresh-host creation and noisy remote output; Docker Compose required.
