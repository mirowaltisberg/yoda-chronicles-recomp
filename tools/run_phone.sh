#!/bin/sh
# Build (signed, Release), install and launch the game on a connected iPhone; console -> build/run-phone.log.
#   tools/run_phone.sh [device id]   (default: the first paired physical iPhone)
#   tools/run_phone.sh [device id] --no-build
# The phone must be unlocked to launch; while it is locked (or briefly unreachable) the launch is retried.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEV=${1:-$(xcrun devicectl list devices 2>/dev/null | awk '/physical/ && /iPhone/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) {print $i; exit}}')}
[ -n "$DEV" ] || { echo "no paired iPhone found"; exit 1; }
APP="$ROOT/build/dd-phone/Build/Products/Release-iphoneos/YodaChronicles.app"
LOG="$ROOT/build/run-phone.log"

if [ "$2" != "--no-build" ]; then
    xcodebuild -project "$ROOT/ios/Yoda.xcodeproj" -scheme YodaPhone -configuration Release -destination "id=$DEV" \
        -derivedDataPath "$ROOT/build/dd-phone" -allowProvisioningUpdates build > "$ROOT/build/xcodebuild-phone.log" 2>&1 \
        || { grep -E "error:|Undefined" "$ROOT/build/xcodebuild-phone.log" | head -20; exit 1; }
fi

for i in 1 2 3; do
    xcrun devicectl device install app --device "$DEV" "$APP" > "$ROOT/build/install.log" 2>&1 && break
    echo "install attempt $i failed, retrying"; sleep 3
done
grep -q "App installed" "$ROOT/build/install.log" || { tail -5 "$ROOT/build/install.log"; exit 1; }
echo "installed on $DEV; launching (unlock the phone if it is locked)"

for i in $(seq 1 120); do
    xcrun devicectl device process launch --device "$DEV" --console --terminate-existing \
        ch.mirowaltisberg.yodachronicles > "$LOG" 2>&1 || true
    grep -q -E "^ERROR|failed to launch|Locked" "$LOG" || break
    sleep 4
done
echo "game exited; console in $LOG"
