#!/bin/sh
# Launch the installed game in this project's Simulator and take a screenshot every INTERVAL seconds.
#   tools/watch_sim.sh [total=180] [interval=20]
ROOT=$(cd "$(dirname "$0")/.." && pwd)
UDID=$(cat "$ROOT/build/sim-udid")
TOTAL=${1:-180}; STEP=${2:-20}
mkdir -p "$ROOT/build/shots"; rm -f "$ROOT/build/shots/"*.png
xcrun simctl launch --console-pty --terminate-running-process "$UDID" ch.mirowaltisberg.yodachronicles > "$ROOT/build/run.log" 2>&1 &
PID=$!
t=0
while [ $t -lt "$TOTAL" ]; do
    sleep "$STEP"; t=$((t + STEP))
    xcrun simctl io "$UDID" screenshot "$ROOT/build/shots/t$(printf %03d $t).png" >/dev/null 2>&1
done
kill $PID 2>/dev/null
ls "$ROOT/build/shots"
