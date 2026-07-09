#!/bin/zsh
#
# stay-alive.sh — keep your Mac awake
#
# Usage:
#   stay-alive                # stay awake until you press Ctrl+C
#   stay-alive 45m            # stay awake for 45 minutes (also 2h, or 90 = seconds)
#   stay-alive -b 20          # stop if battery drops to 20% while unplugged
#   stay-alive -b 15 2h       # 2 hours max, but bail early if battery hits 15%
#   stay-alive -D 2h          # keep the Mac awake but let the display sleep
#   stay-alive make build     # stay awake while a command runs (use -- if needed)
#   stay-alive status         # show whether stay-alive is running
#   stay-alive stop           # stop a running stay-alive

set -euo pipefail

command -v caffeinate >/dev/null || { echo "error: caffeinate not found (macOS only)" >&2; exit 1; }

CHECK_INTERVAL=30  # seconds between battery checks

# The pidfile trusts anything running as this user: stop kills whatever
# own-UID PID it finds here. Only one instance may run at a time.
PIDFILE="${XDG_CACHE_HOME:-$HOME/.cache}/stay-alive.pid"
SCRIPT_PATH=${0:a}  # $0 becomes the function name inside zsh functions

usage() {
  sed -n '3,13p' "$SCRIPT_PATH" | sed 's/^# \{0,1\}//'
  exit 0
}

# Convert "45m" / "2h" / "90" into seconds.
# The <-> globs guarantee the numeric part is a pure non-negative integer
# before it reaches arithmetic expansion, which would otherwise resolve
# identifiers, hex/octal, and operators inside $(( )).
to_seconds() {
  local input=$1 num unit
  case $input in
    <->h) num=${input%h}; unit=3600 ;;
    <->m) num=${input%m}; unit=60 ;;
    <->s) num=${input%s}; unit=1 ;;
    <->)  echo "$input"; return ;;
    *) echo "error: can't parse duration '$input' (try 90, 45m, or 2h)" >&2; exit 1 ;;
  esac
  echo $(( num * unit ))
}

battery_pct() {
  pmset -g batt | grep -Eo '[0-9]+%' | head -1 | tr -d '%'
}

on_ac_power() {
  pmset -g batt | head -1 | grep -q "AC Power"
}

# Pass the message as argv data, never interpolated into AppleScript source,
# so no value reaching $1 can be parsed as code.
notify() {
  printf '\a'
  osascript - "$1" >/dev/null 2>&1 <<'APPLESCRIPT' || true
on run argv
  display notification (item 1 of argv) with title "stay-alive"
end run
APPLESCRIPT
}

read_pidfile() {
  [[ -f $PIDFILE ]] && cat "$PIDFILE" 2>/dev/null || true
}

# Subcommands
case ${1:-} in
  status)
    pid=$(read_pidfile)
    if [[ $pid == <-> ]] && kill -0 "$pid" 2>/dev/null; then
      echo "stay-alive is running (PID $pid)."
    else
      echo "stay-alive is not running."
    fi
    exit 0
    ;;
  stop)
    pid=$(read_pidfile)
    if [[ $pid == <-> ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      echo "Stopped stay-alive (PID $pid)."
    else
      echo "stay-alive is not running."
    fi
    exit 0
    ;;
esac

# Parse arguments
THRESHOLD=""
DURATION=""
NO_DISPLAY=""
CMD=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) usage ;;
    -b|--battery)
      [[ $# -ge 2 && $2 == <-> ]] || { echo "error: -b needs a percentage (e.g. -b 20)" >&2; exit 1; }
      THRESHOLD=$2
      shift 2
      ;;
    -D|--no-display)
      NO_DISPLAY=1
      shift
      ;;
    --)
      shift
      CMD=("$@")
      break
      ;;
    <->|<->h|<->m|<->s)
      DURATION=$1
      shift
      [[ $# -eq 0 ]] || { echo "error: unexpected arguments after duration: $*" >&2; exit 1; }
      ;;
    *)
      CMD=("$@")
      break
      ;;
  esac
done

if [[ -n $DURATION && ${#CMD} -gt 0 ]]; then
  echo "error: give a duration or a command, not both" >&2
  exit 1
fi

if (( ${#CMD} )) && ! command -v "${CMD[1]}" >/dev/null; then
  echo "error: '${CMD[1]}' is neither a duration (try 90, 45m, or 2h) nor a command" >&2
  exit 1
fi

if [[ -n $THRESHOLD ]] && ! pmset -g batt | grep -q "InternalBattery"; then
  echo "note: no battery detected, ignoring -b $THRESHOLD" >&2
  THRESHOLD=""
fi

# Refuse to start if a live instance already owns the pidfile
existing=$(read_pidfile)
if [[ $existing == <-> ]] && kill -0 "$existing" 2>/dev/null; then
  echo "error: stay-alive is already running (PID $existing) — run 'stay-alive stop' first" >&2
  exit 1
fi

# -d  keep the display awake (dropped with -D/--no-display)
# -i  prevent idle sleep
# -m  prevent disk sleep
# -s  prevent system sleep (on AC power)
FLAGS="-dims"
[[ -n $NO_DISPLAY ]] && FLAGS="-ims"

# Install the traps before anything is launched, so a signal can never
# land in a window where caffeinate or the wrapped command gets orphaned
CMD_PID=""
CAFF_PID=""
SLEEP_PID=""
cleanup() {
  [[ -n $CAFF_PID ]] && kill "$CAFF_PID" 2>/dev/null || true
  # Reap the wrapped command too, so TERM doesn't orphan it
  [[ -n $CMD_PID ]] && kill "$CMD_PID" 2>/dev/null || true
  [[ -n $SLEEP_PID ]] && kill "$SLEEP_PID" 2>/dev/null || true
  # Only remove the pidfile if it still belongs to this instance
  [[ $(read_pidfile) == $$ ]] && rm -f "$PIDFILE"
  return 0
}

# Exit right away on Ctrl+C / stay-alive stop. Without this, zsh resumes
# the interrupted wait on the battery-poll sleep after the trap returns,
# delaying exit by up to CHECK_INTERVAL seconds.
on_signal() {
  trap - INT TERM EXIT
  cleanup
  echo ""
  echo "Done — normal sleep behavior restored."
  exit 130
}
trap on_signal INT TERM
trap cleanup EXIT

mkdir -p "${PIDFILE:h}"
echo $$ > "$PIDFILE"

if (( ${#CMD} )); then
  echo "☕ Keeping Mac awake while running: ${CMD[*]}"
  "${CMD[@]}" &
  CMD_PID=$!
  caffeinate $FLAGS -w "$CMD_PID" &
  CAFF_PID=$!
else
  CAFF_ARGS=($FLAGS)
  if [[ -n $DURATION ]]; then
    secs=$(to_seconds "$DURATION")
    CAFF_ARGS+=(-t "$secs")
    echo "☕ Keeping Mac awake for $DURATION ($secs seconds)..."
  else
    echo "☕ Keeping Mac awake until you press Ctrl+C (or run: stay-alive stop)..."
  fi
  caffeinate $CAFF_ARGS &
  CAFF_PID=$!
fi

[[ -n $THRESHOLD ]] && echo "🔋 Will stop if battery drops to ${THRESHOLD}% while unplugged."

if [[ -n $THRESHOLD ]]; then
  while kill -0 "$CAFF_PID" 2>/dev/null; do
    if ! on_ac_power; then
      # || guard: a transient pmset/grep failure must not kill the
      # script via set -e; the <-> check below skips the bad reading
      pct=$(battery_pct) || pct=""
      if [[ $pct == <-> ]] && (( pct <= THRESHOLD )); then
        if [[ -n $CMD_PID ]]; then
          msg="Battery at ${pct}% — no longer keeping the Mac awake (your command is still running)."
        else
          msg="Battery at ${pct}% — no longer keeping the Mac awake."
        fi
        echo "🔋 $msg"
        notify "$msg"
        kill "$CAFF_PID" 2>/dev/null || true
        break
      fi
    fi
    sleep "$CHECK_INTERVAL" &
    SLEEP_PID=$!
    wait "$SLEEP_PID" 2>/dev/null || true
    SLEEP_PID=""
  done
fi

if [[ -n $CMD_PID ]]; then
  CMD_STATUS=0
  wait "$CMD_PID" || CMD_STATUS=$?
  wait "$CAFF_PID" 2>/dev/null || true
  echo "Done — normal sleep behavior restored."
  exit $CMD_STATUS
fi

wait "$CAFF_PID" 2>/dev/null || true
echo "Done — normal sleep behavior restored."
