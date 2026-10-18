#!/bin/sh
# Writes ios/trampoline.patch: every change made in build/xcode/Classes against Unity's pristine Trampoline
# (generated Register* files excluded). make_xcode.sh re-applies it.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IOS="$ROOT/build/unity-4.6.6/pkg/Unity.pkg/Payload/Unity/Unity.app/Contents/PlaybackEngines/iossupport"
P="$ROOT/build/xcode-pristine"
rm -rf "$P" && mkdir -p "$P" && cp -R "$IOS/Trampoline/Classes" "$P/Classes"
cd "$ROOT/build"
diff -ruN -x 'RegisterClasses.cpp' -x 'RegisterMonoModules.*' -x 'RegisterFeatures.*' -x '.DS_Store' \
    xcode-pristine/Classes xcode/Classes | sed -e 's#^--- xcode-pristine/#--- a/#' -e 's#^+++ xcode/#+++ b/#' \
    > "$ROOT/ios/trampoline.patch" || true
echo "ios/trampoline.patch: $(grep -c '^+++ ' "$ROOT/ios/trampoline.patch") files changed"
