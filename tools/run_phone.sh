#!/bin/sh
# Build (signed, Release), install and launch the game on a connected iPhone; console -> build/run-phone.log.
#   tools/run_phone.sh [device id] [--no-build] [--no-launch]
#   device id: default is the first paired physical iPhone (from devicectl's JSON output)
#   --no-build: install the existing build; --no-launch: build and install only
# The phone must be unlocked to launch; while it is locked (or briefly unreachable) the launch is retried.
# Exits non-zero if the build, the install or every launch attempt fails.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP="$ROOT/build/dd-phone/Build/Products/Release-iphoneos/YodaChronicles.app"
LOG="$ROOT/build/run-phone.log"

DEV=""; BUILD=1; LAUNCH=1
for arg in "$@"; do
    case "$arg" in
        --no-build) BUILD=0 ;;
        --no-launch) LAUNCH=0 ;;
        -*) echo "unknown option $arg"; exit 2 ;;
        *) DEV="$arg" ;;
    esac
done

if [ -z "$DEV" ]; then
    JSON=$(mktemp -t yoda-devices)
    xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1 || true
    DEV=$(/usr/bin/python3 -I -c '
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
for d in devices:
    hw, conn = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if hw.get("reality") == "physical" and hw.get("deviceType") == "iPhone" and conn.get("pairingState") == "paired":
        print(hw.get("udid", "")); break
' "$JSON")
    rm -f "$JSON"
fi
[ -n "$DEV" ] || { echo "no paired iPhone found"; exit 1; }

if [ "$BUILD" = 1 ]; then
    xcodebuild -project "$ROOT/ios/Yoda.xcodeproj" -scheme YodaPhone -configuration Release -destination "id=$DEV" \
        -derivedDataPath "$ROOT/build/dd-phone" -allowProvisioningUpdates build > "$ROOT/build/xcodebuild-phone.log" 2>&1 \
        || { grep -E "error:|Undefined" "$ROOT/build/xcodebuild-phone.log" | head -20; exit 1; }
fi

for i in 1 2 3; do
    xcrun devicectl device install app --device "$DEV" "$APP" > "$ROOT/build/install.log" 2>&1 && break
    echo "install attempt $i failed, retrying"; sleep 3
done
grep -q "App installed" "$ROOT/build/install.log" || { tail -5 "$ROOT/build/install.log"; exit 1; }
if [ "$LAUNCH" = 0 ]; then echo "installed on $DEV"; exit 0; fi
echo "installed on $DEV; launching (unlock the phone if it is locked)"

for i in $(seq 1 120); do
    xcrun devicectl device process launch --device "$DEV" --console --terminate-existing \
        ch.mirowaltisberg.yodachronicles > "$LOG" 2>&1 || true
    if ! grep -q -E "^ERROR|failed to launch|Locked" "$LOG"; then
        echo "game exited; console in $LOG"
        exit 0
    fi
    sleep 4
done
echo "could not launch after 120 attempts (phone locked or unreachable); last error in $LOG"
exit 1
