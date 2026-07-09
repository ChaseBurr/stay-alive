# stay-alive

Keep your Mac awake from the terminal. A small zsh wrapper around macOS's
built-in [`caffeinate`](https://ss64.com/mac/caffeinate.html) — nothing to
install, no menu bar apps.

## Usage

```bash
./stay-alive.sh              # stay awake until you press Ctrl+C
./stay-alive.sh 45m          # stay awake for 45 minutes
./stay-alive.sh 2h           # stay awake for 2 hours
./stay-alive.sh 90           # plain number = seconds
./stay-alive.sh -b 20        # stop when battery drops to 20% while unplugged
./stay-alive.sh -b 15 2h     # 2 hours max, but bail early if battery hits 15%
```

While running, the script keeps the display on and prevents idle, disk, and
system sleep. When it exits (duration elapsed, Ctrl+C, or the low-battery
threshold is reached), normal sleep behavior is restored.

### Low-battery shutoff

With `-b <percent>`, the script polls the battery every 30 seconds and stops
keeping the Mac awake once you're **unplugged** and at or below the threshold.
Being plugged into AC power never triggers the shutoff. On a Mac with no
battery the flag is ignored.

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
- To keep the Mac awake but let the display turn off, change `FLAGS="-dims"`
  to `FLAGS="-ims"` in `stay-alive.sh`.
- Requires macOS (uses `caffeinate` and `pmset`).
