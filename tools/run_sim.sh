#!/bin/sh
# Build, install and run the game in this project's own Simulator ("Yoda iPhone 17", build/sim-udid),
# capture the console for N seconds and take a screenshot.
#   tools/run_sim.sh [seconds=40] [--no-build]
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SECS=${1:-40}
UDID=$(cat "$ROOT/build/sim-udid")
APP="$ROOT/build/dd/Build/Products/Debug-iphonesimulator/YodaChronicles.app"
LOG="$ROOT/build/run.log"
SHOT="$ROOT/build/shot.png"
if [ "$2" != "--no-build" ]; then
    xcodebuild -project "$ROOT/ios/Yoda.xcodeproj" -scheme YodaSim -configuration Debug -sdk iphonesimulator \
        -destination "id=$UDID" -derivedDataPath "$ROOT/build/dd" ARCHS=arm64 build > "$ROOT/build/xcodebuild-sim.log" 2>&1 \
        || { grep -E "error:|Undefined" "$ROOT/build/xcodebuild-sim.log" | head -20; exit 1; }
fi
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID"
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch --console-pty --terminate-running-process "$UDID" ch.mirowaltisberg.yodachronicles > "$LOG" 2>&1 &
PID=$!
sleep "$SECS"
xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null 2>&1 || true
kill $PID 2>/dev/null || true
echo "log: $LOG ($(wc -l < "$LOG" | tr -d ' ') lines), screenshot: $SHOT"
