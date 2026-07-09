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
background). Only one instance runs at a time — starting a second one errors
and points you at `stay-alive stop`.

### If `stop` can't find it

If the pidfile is stale or missing (say, the Mac hard-rebooted or you're on
an older version), you can hunt it down manually:

```bash
pmset -g assertions          # see everything currently preventing sleep
pkill -f stay-alive.sh       # kill any running stay-alive scripts
pgrep -lf caffeinate         # list caffeinate processes and who started them
```

`stay-alive`'s own caffeinate dies with the script, so `pkill -f
stay-alive.sh` is normally all you need. Avoid a blanket `pkill caffeinate` —
other apps and scripts use caffeinate too.

## Install

With Homebrew:

```bash
brew install ChaseBurr/tap/stay-alive
```

Or from a clone, to run it from anywhere as `stay-alive`:

```bash
./install.sh                 # symlinks into ~/.local/bin
./install.sh /usr/local/bin  # or pick your own bin directory
```

The installer symlinks rather than copies, so a `git pull` updates the
installed command too. It will warn you if the target directory isn't on your
`PATH`.

### "zsh: command not found: stay-alive"

The install succeeded, but your shell doesn't look in `~/.local/bin` for
commands. Tell it to (this is the fix for the default macOS zsh):

```zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

For **bash**, use `~/.bash_profile` instead of `~/.zshrc`; for **fish**, run
`fish_add_path ~/.local/bin`. Other terminals that are already open won't see
the change until you open a new one (or `source` the file there too).

Other gotchas of the same flavor:

- **Installed with Homebrew but not found** — open a new terminal first; if
  it persists, brew's own directory is missing from `PATH`, fixed with
  `echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile`
  (`/usr/local/bin/brew` on Intel Macs).
- **Works in one terminal but not another** — the `PATH` change was applied
  to the current session only; make sure it's in your shell startup file.
- **`sudo stay-alive` not found** — `sudo` uses a minimal `PATH` that skips
  user bin directories. You shouldn't need sudo for this tool at all.

## ⚠️ Warnings

- **Battery and heat.** Keeping a Mac awake for hours drains the battery and
  generates heat — that's the point of the tool, but set a duration or a
  `-b` threshold rather than leaving it running indefinitely on battery.
- **Your screen may not lock.** Keeping the display awake also prevents the
  idle timeout that triggers your screen saver and lock screen. If you walk
  away while stay-alive is running (without `-D`), your Mac may sit unlocked.
  Lock it manually (Ctrl+Cmd+Q) when you leave.
- **Command mode runs exactly what you give it.** `stay-alive <command>`
  executes the command with your normal privileges, just as if you'd typed
  it yourself — it adds no safety net.
- **Don't disable lid sleep casually.** Closing the lid still puts the Mac to
  sleep; overriding that requires `sudo pmset disablesleep 1`, which is
  system-wide and can cook a lid-closed laptop in a bag. Not recommended.

## Notes

- Requires macOS (uses `caffeinate`, `pmset`, and `osascript`).
- License: [MIT](LICENSE).
