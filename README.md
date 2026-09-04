# tmmx

`tmmx` is a host-aware tmux session manager. It lets one local tmux server switch between local workspaces and SSH-backed remote tmux sessions.

## Requirements

- tmux 3.2 or newer;
- fzf 0.35 or newer on the local machine and each remote host where you use the picker;
- SSH access to remote hosts.

## Install

Add tmmx to TPM:

```tmux
set -g @plugin 'fedemengo/tmmx'
```

Install TPM plugins, then install the launcher:

```sh
make -C ~/.tmux/plugins/tmmx install
```

Run `tmmx` from a terminal to create or attach to the `~tmmx` manager session.

Install the plugin on remote hosts as well when you want `Ctrl-\ f`, clipboard forwarding, and per-host session switching inside their tmux servers. Remote hosts do not need the launcher.

## Controls

- `Ctrl-q w`: open the manager picker. Type `name` for a local session, `@host` for an SSH-backed tmux session, or `ssh user@host` to connect as a specific SSH user.
- `Ctrl-q Tab`: switch between the two most recently used manager sessions.
- `Ctrl-\ f`: open a create-or-switch picker for the current tmux server.
- `Ctrl-\ Space` or `Ctrl-\ Ctrl-Tab`: switch to the previous session on the current tmux server.
- `Ctrl-\ Tab`: previous window on the current tmux server.
- `Ctrl-x`: close the highlighted local session or managed remote connection; in a remote-host picker, kill the highlighted remote session. Confirmation is required.

Pickers start in scroll mode, where every printable key is ignored except the movement keys: `j` and `k` move by one row, `Ctrl-d` and `Ctrl-u` by half a page, `Ctrl-f` and `Ctrl-b` by a page, and `g` and `G` jump to the first and last row. Press `i` to enter insert mode and type, or `@` to enter insert mode with `@` already typed. `Ctrl-j` returns to scroll mode; `Enter` and `Esc` work in both modes.

## Remote workflow

Typing `@target-host` in the manager creates a local wrapper session, connects with `ssh target-host`, and lets you select or create a tmux session on that host. Ending the inner remote session returns to that host’s picker; `Esc` returns to the local manager.

Once the query contains `@`, the manager also lists hosts from `~/.ssh/config` below the matching sessions, marked `ssh config`. Typing `@` lists them as `@host` and typing `user@` lists them as `user@host`. Hosts that already have a wrapper are not repeated. Selecting a host row connects exactly as typing that destination would. `Include` directives are followed; wildcard patterns are skipped.

`@host` connects as the user configured for that host in your SSH configuration. To connect as a different user without adding an SSH alias, type `ssh user@host` instead. tmmx creates the same kind of wrapper session, connects with `ssh user@host`, and shows the same host session picker. The complete destination is kept for the wrapper's lifetime, so reconnect, restore, and remote kill all use it. `@host` and `ssh user@host` are separate entries in the manager: the first appears as `@host` and the second as `user@host`. `ssh host` without a user is equivalent to `@host`.

The `Host` entry in your SSH configuration still applies when connecting as `user@host`; the command-line user only overrides `User`. Keys, `ProxyJump`, and other options from that entry are used as usual, so no per-user alias is needed. tmmx always runs its own command over SSH, so `RemoteCommand` and `RequestTTY` from a matching entry are overridden.

If the connection fails before the host picker appears, for example because the name does not resolve or tmux is missing on the host, the wrapper shows the error and waits for Enter before closing.

Use SSH `ProxyJump` for hosts behind a jump host. tmmx then keeps the interactive workflow at two tmux layers.

```sshconfig
Host target-host
  HostName target.internal
  User remote-user
  ProxyJump jump-host
```

## Configuration

Set these options before TPM loads tmmx to change the defaults:

```tmux
set -g @tmmx_outer_prefix 'C-\'
set -g @tmmx_manager_key 'C-q'
set -g @tmmx_picker_key 'f'
set -g @tmmx_manager_picker_key 'w'
set -g @tmmx_manager_local_sessions 'all' # or 'host' for one @local-host row
set -g @tmmx_popup_width '60%'
set -g @tmmx_popup_height '50%'
set -g @tmmx_auto_reconnect 'off'
set -g @tmmx_reconnect_delay 2
set -g @tmmx_auto_restore 'off'
set -g @tmmx_restore_grace 5
set -g @tmmx_manager_host 'local-host'
set -g @tmmx_host_colors 'personal-host=#a3be8c,work-host=#ff9e64'
```

The outer prefix is an additional tmux root binding. It opens the local prefix table in local sessions and is forwarded unchanged through managed SSH wrappers.

`@tmmx_auto_reconnect` retries a managed SSH connection after a network drop and uses a five-second SSH keepalive so a half-open connection is detected. With `@tmmx_auto_restore` enabled, a recovered host with no tmux server is bootstrapped and its configured `@resurrect-restore-script-path` is invoked before tmmx reattaches. Restore is attempted once per outage and waits up to `@tmmx_restore_grace` seconds for the requested session.

Automatic reconnect and restore are reliable only when SSH authentication is non-interactive: an agent-loaded key, an unprotected key, or a key whose passphrase is already cached. This applies equally to `@host` and `ssh user@host` targets, and the key can come from the host's `Host` entry. A password or passphrase prompt during a reconnect attempt blocks the wrapper until it is answered.

`@tmmx_host_colors` keys can be a host alias or a complete `user@host` destination. A `user@host` entry matches only that destination, and a host alias also colors every `user@host` destination for that host.

`@tmmx_picker_spacing` controls the minimum number of spaces between the label and timestamp columns.

## Notes

- tmux normalizes `.` and `:` in session names to `_`; tmmx follows that rule.
- New session names containing tabs or `|` are rejected because they cannot be represented safely in picker entries.
- Set `TMMX_REMOTE_TMUX` in tmux’s server environment when a remote host needs an explicit tmux binary path.

## Development

Run the fast shell checks with `make test`. `make test-e2e` builds disposable Docker containers containing a real SSH server and tmux server, then verifies fresh-host creation and noisy remote shell output handling. Docker Compose is required for the E2E suite.
