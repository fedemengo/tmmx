# tmmx demo

Spins up four fake remote hosts (real sshd + tmux in Docker) so you can record
tmmx connecting across machines. Each host runs **tmmx + the minova theme** and is
pre-seeded with sessions whose windows print live-looking output, so the pickers,
status bars, and panes all look alive — this is what `demo/tmmx.gif` was made from.

| Host (`@`) | Port | Sessions (3 each, 2 live windows) |
|------------|------|-----------------------------------|
| web    | 2201 | `deploy`, `nginx`, `shell` |
| api    | 2202 | `logs`, `repl`, `server` |
| db     | 2203 | `backup`, `monitor`, `psql` |
| worker | 2204 | `cron`, `queue`, `shell` |

## Run it

```sh
demo/up.sh        # build + start the 4 hosts and generate a key
demo/record.sh    # launch an ISOLATED tmmx that shows only the demo hosts
demo/down.sh      # stop everything, remove the sandbox
```

Requires Docker (daemon running) and Docker Compose. The hosts are throwaway;
`down.sh` removes the containers, volumes, and the recording sandbox.

`record.sh` runs tmmx in a sandbox — a separate tmux socket (so none of your real
local sessions show), a separate `$HOME`/`~/.ssh/config` listing only the demo
hosts (so `@` lists only `web/api/db/worker`), and a separate state dir. **Your
real tmux and `~/.ssh` are never touched.** Detach/exit as usual when done.

Edit `host/seed.sh` to change the sessions/windows, or `compose.yaml` to add hosts.

## Walkthrough (what the GIF shows)

For each host in turn (`web → api → db → worker`):

1. `Ctrl-\ w`, type `@<host>`, Enter — connect; the host's session picker appears, press `1` to quick-select a session.
2. `Ctrl-\ n` — switch to that session's **second window** (forwarded to the host's tmux).
3. `Ctrl-\ e` — open the **host's own tmmx session picker** (forwarded through the wrapper), press `1` for a second session.

Then `Ctrl-\ w` again to hop to the next host, and end on the manager showing the whole fleet.

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

The hosts already run tmmx + fzf, so the forwarded per-host pickers (`Ctrl-\ e`)
and nav render on the host — that's the full remote experience shown in the GIF.
