#!/bin/sh
# Builds ILPatch.exe against the Mono.Cecil shipped with Unity 4.6.6's IL2CPP, and AndroidShim.dll against
# the game's own .NET 2.0 class library (neither is committed).
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
U="$ROOT/build/unity-4.6.6/pkg/Unity.pkg/Payload/Unity/Unity.app/Contents"
OUT="$ROOT/build/tools"
mkdir -p "$OUT"
cp "$U/Frameworks/il2cpp/build/Mono.Cecil.dll" "$OUT/"
mcs -nologo -debug -out:"$OUT/ILPatch.exe" -r:"$OUT/Mono.Cecil.dll" "$ROOT"/tools/ilpatch/ILPatch.cs
mcs -nologo -target:library -nostdlib -noconfig -r:"$U/Frameworks/Mono/lib/mono/unity/mscorlib.dll" \
    -out:"$OUT/AndroidShim.dll" "$ROOT"/tools/ilpatch/shim/AndroidShim.cs
echo "built $OUT/ILPatch.exe $OUT/AndroidShim.dll"
