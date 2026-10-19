#!/bin/sh
# Records every change made in build/xcode/Classes against Unity's pristine Trampoline as ios/trampoline/:
#   MANIFEST         "<sha256 of Unity's original file>  <path>" per changed file
#   <path>.ed        an ed script (diff -e): line addresses plus the new lines only
# No line of Unity's code is stored: unlike a unified diff there are no removed or context lines, so
# the repository can be public. The hashes make sure the line addresses only ever apply to Unity 4.6.6's
# own files. make_xcode.sh re-applies the scripts. (Generated Register* files are not recorded.)
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IOS="$ROOT/build/unity-4.6.6/pkg/Unity.pkg/Payload/Unity/Unity.app/Contents/PlaybackEngines/iossupport"
PRISTINE="$IOS/Trampoline/Classes"
WORK="$ROOT/build/xcode/Classes"
OUT="$ROOT/ios/trampoline"

rm -rf "$OUT" && mkdir -p "$OUT"
: > "$OUT/MANIFEST"
(cd "$WORK" && find . -type f ! -name 'RegisterClasses.cpp' ! -name 'RegisterMonoModules.*' ! -name 'RegisterFeatures.*' \
    ! -name '.DS_Store' | sed 's#^\./##' | sort) | while read -r f; do
    if [ ! -f "$PRISTINE/$f" ]; then
        echo "new file $f: not supported, keep additions in ios/Shim instead" >&2; exit 1
    fi
    cmp -s "$PRISTINE/$f" "$WORK/$f" && continue
    # ed ends inserted text at a line holding a single "."; such a line in our code would corrupt the script
    if grep -q '^\.$' "$WORK/$f"; then echo "$f has a line with a single '.'; cannot be stored as an ed script" >&2; exit 1; fi
    mkdir -p "$OUT/$(dirname "$f")"
    { diff -e "$PRISTINE/$f" "$WORK/$f" || true; printf 'w\nq\n'; } > "$OUT/$f.ed"
    printf '%s  %s\n' "$(shasum -a 256 "$PRISTINE/$f" | cut -d' ' -f1)" "$f" >> "$OUT/MANIFEST"
done
echo "ios/trampoline: $(wc -l < "$OUT/MANIFEST" | tr -d ' ') files changed"
