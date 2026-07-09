# stay-alive

Keep your Mac awake from the terminal. A small zsh wrapper around macOS's
built-in [`caffeinate`](https://ss64.com/mac/caffeinate.html) — nothing to
install, no menu bar apps.

## Usage

```bash
stay-alive                 # stay awake until you press Ctrl+C
stay-alive 45m             # stay awake for 45 minutes
stay-alive 2h              # stay awake for 2 hours
stay-alive 90              # plain number = seconds
stay-alive -b 20           # stop when battery drops to 20% while unplugged
stay-alive -b 15 2h        # 2 hours max, but bail early if battery hits 15%
stay-alive -D 2h           # keep the Mac awake but let the display sleep
stay-alive make build      # stay awake exactly as long as a command runs
stay-alive status          # is stay-alive running?
stay-alive stop            # stop a running stay-alive
```

While running, the script keeps the display on and prevents idle, disk, and
system sleep. When it exits (duration elapsed, command finished, Ctrl+C,
`stay-alive stop`, or the low-battery threshold is reached), normal sleep
behavior is restored.

### Run for the length of a command

Any arguments that aren't a duration are treated as a command to run:

```bash
stay-alive rsync -av ~/big-folder /Volumes/backup/
stay-alive -b 10 make -j8
```

The Mac stays awake until the command finishes, and stay-alive exits with the
command's exit status. Use `--` before commands that could be mistaken for
options. If the low-battery threshold fires mid-command, the command keeps
running — only the keep-awake assertion is dropped.

### Low-battery shutoff

With `-b <percent>`, the script polls the battery every 30 seconds and stops
keeping the Mac awake once you're **unplugged** and at or below the threshold.
You'll get a macOS notification (and a terminal bell) when it triggers, so you
know why the Mac went back to its normal sleep habits. Being plugged into AC
power never triggers the shutoff. On a Mac with no battery the flag is
ignored.

### Display sleep

By default the display is kept on. Pass `-D` / `--no-display` to let the
screen sleep while the Mac itself stays awake — handy for overnight downloads.

### status / stop

`stay-alive` writes a pidfile to `~/.cache/stay-alive.pid`, so you can check
on or stop a session from another terminal (or one running in the
background). `status` and `stop` target the most recently started instance.

## Install

To run it from anywhere as `stay-alive`:

```bash
./install.sh                 # symlinks into ~/.local/bin
./install.sh /usr/local/bin  # or pick your own bin directory
```

The installer symlinks rather than copies, so a `git pull` updates the
installed command too. It will warn you if the target directory isn't on your
`PATH`.

## Notes

- Closing the laptop lid still puts the Mac to sleep. Overriding that requires
  `sudo pmset disablesleep 1`, which is system-wide and not recommended unless
  you really need it.
- Requires macOS (uses `caffeinate`, `pmset`, and `osascript`).
