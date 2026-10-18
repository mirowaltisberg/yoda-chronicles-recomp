#!/bin/sh
# GNU libstdc++ for Unity 4.6's iOS engine library, which was built against Apple's (GCC 4.2) libstdc++:
# old copy-on-write std::string (_ZNSs...), GNU iostreams and locale, _Rb_tree helpers.
#
# Takes Homebrew GCC's static libstdc++.a (same libstdc++.so.6 ABI, which GCC keeps stable), drops the
# members that are also in libsupc++ (exceptions, RTTI, operator new/delete: those stay with iOS's own
# libc++abi so there is one C++ runtime), keeps the two GNU-only helpers from that set, retags the
# objects from macOS to the iOS (Simulator) platform and writes build/engine/libgnustdcxx-<platform>.a.
#
# Usage: tools/make_gnustdcxx.sh iossim|ios
set -e
PLATFORM=${1:-iossim}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
G=/opt/homebrew/opt/gcc/lib/gcc/current
W="$ROOT/build/engine/gnustdcxx-$PLATFORM"
OUT="$ROOT/build/engine/libgnustdcxx-$PLATFORM.a"
KEEP_FROM_SUPC="hash_bytes.o atomicity.o"

rm -rf "$W" && mkdir -p "$W"
cd "$W"
ar -x "$G/libstdc++.a"
for m in $(ar -t "$G/libsupc++.a"); do
    case " $KEEP_FROM_SUPC " in *" $m "*) continue ;; esac
    rm -f "$m"
done
rm -f __.SYMDEF "__.SYMDEF SORTED"
"$ROOT/tools/.venv/bin/python" -I "$ROOT/tools/machotag.py" "$PLATFORM" 26.0 ./*.o
rm -f "$OUT"
libtool -static -no_warning_for_no_symbols -o "$OUT" ./*.o
echo "$OUT ($(ls ./*.o | wc -l | tr -d ' ') objects)"
