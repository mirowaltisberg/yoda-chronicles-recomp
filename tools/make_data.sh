#!/bin/sh
# Assembles the iOS player's Data/ folder (build/Data) from the Android build:
#   APK assets/bin/Data + OBB assets/bin/Data  -> Data/ (".splitN" pieces joined into one file)
#   OBB assets/*.mp4 (Android StreamingAssets)  -> Data/Raw/
#   Unity 4.6.6 iOS "unity default resources" and mono config from the Trampoline (built for the iOS player)
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
X="$ROOT/input/x"
TRAMP="$ROOT/build/unity-4.6.6/pkg/Unity.pkg/Payload/Unity/Unity.app/Contents/PlaybackEngines/iossupport/Trampoline"
OUT="$ROOT/build/Data"

[ -d "$X/obbx/assets/bin/Data" ] || { echo "unpack the OBB into input/x/obbx first (see docs/inputs.md)"; exit 1; }
rm -rf "$OUT" && mkdir -p "$OUT/Raw" "$OUT/Resources"

copy_data_dir() {
    src="$1"
    for f in "$src"/*; do
        [ -f "$f" ] || continue
        name=$(basename "$f")
        case "$name" in
            settings.xml|splash.png) continue ;;
            *.split0)
                base=${name%.split0}
                i=0; : > "$OUT/$base"
                while [ -f "$src/$base.split$i" ]; do cat "$src/$base.split$i" >> "$OUT/$base"; i=$((i + 1)); done ;;
            *.split[0-9]*) ;;
            *) cp "$f" "$OUT/$name" ;;
        esac
    done
}
copy_data_dir "$X/apk/assets/bin/Data"
copy_data_dir "$X/obbx/assets/bin/Data"
rm -f "$OUT/unity default resources"
cp "$X/apk/assets/bin/Data/Resources/unity_builtin_extra" "$OUT/Resources/"
cp "$TRAMP/Data/unity default resources" "$OUT/"
cp -R "$TRAMP/Data/mono" "$OUT/mono"
cp "$X/obbx/assets/"*.mp4 "$OUT/Raw/"
"$ROOT/tools/.venv/bin/python" -I "$ROOT/tools/retarget_data.py" "$OUT"
echo "$(ls "$OUT" | wc -l | tr -d ' ') entries, $(ls "$OUT/Raw" | wc -l | tr -d ' ') movies, $(du -sh "$OUT" | cut -f1)"
