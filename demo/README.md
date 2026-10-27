# tmmx demo

Spins up four fake remote hosts (real sshd + tmux in Docker) so you can record
tmmx connecting across machines. Each host is pre-seeded with sessions and
windows that print live-looking output, so pickers and panes look alive.

| Host (`@`) | Port | Sessions (3 each, 2 windows) |
|------------|------|------------------------------|
| web    | 2201 | `nginx`, `deploy`, `shell` |
| api    | 2202 | `server`, `logs`, `repl` |
| db     | 2203 | `psql`, `backup`, `monitor` |
| worker | 2204 | `queue`, `cron`, `shell` |

## Run it

```sh
demo/up.sh        # build + start the 4 hosts, generate a key, write ssh snippet
# add `Include ~/.ssh/tmmx-demo.config` to the top of ~/.ssh/config (once)
tmmx              # then: manager key -> type @ -> the four hosts appear
demo/down.sh      # stop everything, remove the ssh snippet
```

Requires Docker (daemon running) and Docker Compose. The hosts are throwaway;
`down.sh` removes the containers, volumes, and the ssh snippet.

Edit `host/seed.sh` to change the sessions/windows, or `compose.yaml` to add hosts.

## Suggested walkthrough (~25s)

1. `tmmx`, then the manager key (`Ctrl-\ w`) and type `@` — the four hosts list.
2. Connect to **api** — its session picker appears; press `1` to quick-select `server` and watch the request log scroll.
3. `Ctrl-` 3` — switch across to another host's session.
4. `Ctrl-\ w` again — hop to **db** and quick-select `monitor`.
5. End on the manager showing the connected hosts.

## Recording

Run tmmx in your **own terminal** (Alacritty etc.) for nice fonts/colors — the
containers are only the remote hosts. Pick one:

- **Show the keys pressed (recommended for tmmx).** tmmx is chord-heavy, so an
  on-screen key overlay matters. On macOS use [KeyCastr](https://github.com/keycastr/keycastr)
  to overlay each chord, screen-record with QuickTime, then convert:
  ```sh
  ffmpeg -i screen.mov -vf "fps=15,scale=1200:-1:flags=lanczos" -loop 0 tmmx.gif
  ```
- **Quick terminal-only capture (no key overlay).** Records only the terminal
  cells, so chords are invisible but it's one command:
  ```sh
  asciinema rec demo.cast        # drive the walkthrough, exit when done
  agg demo.cast tmmx.gif
  ```
- **Scripted (vhs).** `vhs` gives a reproducible GIF but has no key overlay and
  is awkward with `Ctrl-\`/`Ctrl-`` chords, so it's not included here.

Installing tmmx (and fzf) on the demo hosts additionally enables the forwarded
per-host pickers (`Ctrl-\ f`, `Ctrl-` 2`) to render on the host; the local
manager flow above works without it.
