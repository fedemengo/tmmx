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

- `Ctrl-q w`: open the manager picker. Type `name` for a local session or `@host` for an SSH-backed tmux session.
- `Ctrl-q Tab`: switch between the two most recently used manager sessions.
- `Ctrl-\ f`: open a create-or-switch picker for the current tmux server.
- `Ctrl-\ Space` or `Ctrl-\ Ctrl-Tab`: switch to the previous session on the current tmux server.
- `Ctrl-\ Tab`: previous window on the current tmux server.
- `Ctrl-x`: close the highlighted local session or managed remote connection; in a remote-host picker, kill the highlighted remote session. Confirmation is required.

Pickers start in scroll mode: use `j` and `k` to navigate, `i` to type, and `Ctrl-j` to return to scroll mode.

## Remote workflow

Typing `@target-host` in the manager creates a local wrapper session, connects with `ssh target-host`, and lets you select or create a tmux session on that host. Ending the inner remote session returns to that host’s picker; `Esc` returns to the local manager.

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
set -g @tmmx_manager_host 'local-host'
set -g @tmmx_host_colors 'personal-host=#a3be8c,work-host=#ff9e64'
```

The outer prefix is an additional tmux root binding. It opens the local prefix table in local sessions and is forwarded unchanged through managed SSH wrappers.

`@tmmx_picker_spacing` controls the minimum number of spaces between the label and timestamp columns.

## Notes

- tmux normalizes `.` and `:` in session names to `_`; tmmx follows that rule.
- New session names containing tabs or `|` are rejected because they cannot be represented safely in picker entries.
- Set `TMMX_REMOTE_TMUX` in tmux’s server environment when a remote host needs an explicit tmux binary path.

## Development

Run the fast shell checks with `make test`. `make test-e2e` builds disposable Docker containers containing a real SSH server and tmux server, then verifies fresh-host creation and noisy remote shell output handling. Docker Compose is required for the E2E suite.
