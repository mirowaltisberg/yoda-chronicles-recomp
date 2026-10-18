#!/bin/sh
# Managed side of the port, mirroring what Unity 4.6.6's editor does for an iOS IL2CPP build
# (UnityEditorInternal.IL2CPPBuilder.Run), but starting from the Android build's assemblies:
#
#   1. stage the Android build's Managed/ folder
#   2. ILPatch: swap in the iOS (IL2CPP variant) UnityEngine.dll, point Android-only types at AndroidShim.dll
#   3. AssemblyPatcher on mscorlib (the editor's PatchAssemblies step)
#   4. il2cpp.exe: IL -> C++ into build/il2cppOutput
#   5. InternalCallRegistrationWriter: UnityICallRegistration.cpp from the iOS UnityEngine.dll
#
# Usage: tools/build_managed.sh            (inputs in input/x, Unity installer expanded in build/unity-4.6.6)
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
U="$ROOT/build/unity-4.6.6/pkg/Unity.pkg/Payload/Unity/Unity.app/Contents"
IOS="$U/PlaybackEngines/iossupport"
IL2CPP="$U/Frameworks/il2cpp"
SRC="$ROOT/input/x/apk/assets/bin/Data/Managed"
B="$ROOT/build/managed"
OUT="$ROOT/build/il2cppOutput"

"$ROOT/tools/ilpatch/build.sh" >/dev/null

rm -rf "$B" && mkdir -p "$B/stage"
cp "$SRC"/*.dll "$B/stage/"
cp "$ROOT/build/tools/AndroidShim.dll" "$B/stage/"

echo "== ILPatch"
mono "$ROOT/build/tools/ILPatch.exe" patch "$B/stage" "$B/Managed" "$IOS/Variations/il2cpp/Managed/UnityEngine.dll"
mono "$ROOT/build/tools/ILPatch.exe" check "$B/Managed" "$B/Managed/UnityEngine.dll" | grep -v 'UnityEngine.Color\[,\]' || true

echo "== AssemblyPatcher (mscorlib)"
M="$B/Managed"
mv "$M/mscorlib.dll" "$M/mscorlib.unpatched.dll"
cp "$IL2CPP/replacements.dll" "$M/replacements.dll"
mono "$IL2CPP/AssemblyPatcher/AssemblyPatcher.exe" -a "$M/mscorlib.unpatched.dll" -o "$M/mscorlib.dll" \
    -c "$IL2CPP/assemblypatcher_config.txt" --log-config "$IL2CPP/AssemblyPatcher.Log.Config.xml" -s "$M"
rm -f "$M/mscorlib.unpatched.dll"

echo "== il2cpp"
rm -rf "$OUT" && mkdir -p "$OUT"
USER_ASMS=""
for a in Assembly-CSharp-firstpass Assembly-CSharp P31RestKit P31MetroLocalytics UnityEngine.UI AndroidShim; do
    [ -f "$M/$a.dll" ] && USER_ASMS="${USER_ASMS:+$USER_ASMS,}$M/$a.dll"
done
mono "$IL2CPP/build/il2cpp.exe" --copy-level=None --emit-null-checks --enable-array-bounds-check \
    --extra-types.file="$IL2CPP/il2cpp_default_extra_types.txt" --assembly="$USER_ASMS" \
    --generatedcppdir="$OUT" --builder=none 2>&1 | tee "$ROOT/build/il2cpp.log" | tail -20

echo "== icall registration"
mono "$IOS/BuildTools/InternalCallRegistrationWriter/InternalCallRegistrationWriter.exe" \
    -assembly="$M/UnityEngine.dll" -output="$OUT/UnityICallRegistration.cpp" 2>&1 | tail -5
ls "$OUT" | head -20
echo "$(ls "$OUT" | wc -l) files in $OUT"
