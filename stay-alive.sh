#!/bin/zsh
#
# stay-alive.sh — keep your Mac awake
#
# Usage:
#   ./stay-alive.sh                # stay awake until you press Ctrl+C
#   ./stay-alive.sh 45m            # stay awake for 45 minutes
#   ./stay-alive.sh 2h             # stay awake for 2 hours
#   ./stay-alive.sh 90             # plain number = seconds
#   ./stay-alive.sh -b 20          # stop when battery drops to 20% (on battery power)
#   ./stay-alive.sh -b 15 2h       # 2 hours max, but bail early if battery hits 15%

set -euo pipefail

command -v caffeinate >/dev/null || { echo "error: caffeinate not found (macOS only)" >&2; exit 1; }

CHECK_INTERVAL=30  # seconds between battery checks

usage() {
  sed -n '3,11p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
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

# Parse arguments
THRESHOLD=""
DURATION=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) usage ;;
    -b|--battery)
      [[ $# -ge 2 && $2 == <-> ]] || { echo "error: -b needs a percentage (e.g. -b 20)" >&2; exit 1; }
      THRESHOLD=$2
      shift 2
      ;;
    *)
      DURATION=$1
      shift
      ;;
  esac
done

if [[ -n $THRESHOLD ]] && ! pmset -g batt | grep -q "InternalBattery"; then
  echo "note: no battery detected, ignoring -b $THRESHOLD" >&2
  THRESHOLD=""
fi

# -d  keep the display awake
# -i  prevent idle sleep
# -m  prevent disk sleep
# -s  prevent system sleep (on AC power)
FLAGS="-dims"

CAFF_ARGS=($FLAGS)
if [[ -n $DURATION ]]; then
  secs=$(to_seconds "$DURATION")
  CAFF_ARGS+=(-t "$secs")
  echo "☕ Keeping Mac awake for $DURATION ($secs seconds)..."
else
  echo "☕ Keeping Mac awake until you press Ctrl+C..."
fi
[[ -n $THRESHOLD ]] && echo "🔋 Will stop if battery drops to ${THRESHOLD}% while unplugged."

caffeinate $CAFF_ARGS &
CAFF_PID=$!

cleanup() {
  kill "$CAFF_PID" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

if [[ -n $THRESHOLD ]]; then
  while kill -0 "$CAFF_PID" 2>/dev/null; do
    if ! on_ac_power; then
      pct=$(battery_pct)
      if [[ $pct == <-> ]] && (( pct <= THRESHOLD )); then
        echo "🔋 Battery at ${pct}% (≤ ${THRESHOLD}%) — stopping."
        kill "$CAFF_PID" 2>/dev/null || true
        break
      fi
    fi
    sleep "$CHECK_INTERVAL" &
    wait $! 2>/dev/null || true
  done
fi

wait "$CAFF_PID" 2>/dev/null || true
echo "Done — normal sleep behavior restored."
