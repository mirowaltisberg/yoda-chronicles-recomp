"""Retag Unity 4 serialized files (format 9) from the Android build to Unity 4.6.6f2's iOS player, in place.

The iOS player refuses files whose header names another build target ("created for another build
target ... File's Build target is: 13") and files written by another engine version ("Invalid
serialized file version. Expected version: 4.6.6f2. Actual version: 4.6.6p1"). The game data is
otherwise the same for both players (GLES2 shaders, same serialization; p1 is a bug-fix patch on f2),
so two header fields change:
  - the 4-byte build target after the version string: 13 (Android) -> 9 (iPhone)
  - the version string itself: 4.6.6p1 -> 4.6.6f2 (same length)

Usage: python -I tools/retarget_data.py <Data dir>
"""
import pathlib
import struct
import sys

ANDROID, IPHONE = 13, 9
SOURCE_VERSION, PLAYER_VERSION = "4.6.6p1", "4.6.6f2"
assert len(SOURCE_VERSION) == len(PLAYER_VERSION)


def retag(path):
    with open(path, "r+b") as f:
        head = f.read(128)
        if len(head) < 40:
            return None
        _meta, file_size, version, _data_off = struct.unpack_from(">IIII", head, 0)
        if version != 9 or file_size != path.stat().st_size:
            return None
        end = head.index(b"\0", 20)
        unity = head[20:end].decode("ascii", "replace")
        little = head[16] == 0
        fmt = "<i" if little else ">i"
        target = struct.unpack_from(fmt, head, end + 1)[0]
        if target != ANDROID:
            return False
        f.seek(end + 1)
        f.write(struct.pack(fmt, IPHONE))
        if unity == SOURCE_VERSION:
            f.seek(20)
            f.write(PLAYER_VERSION.encode("ascii"))
        return unity


def main():
    root = pathlib.Path(sys.argv[1])
    changed = skipped = 0
    for p in sorted(root.rglob("*")):
        if not p.is_file():
            continue
        r = retag(p)
        if r:
            changed += 1
        elif r is False:
            skipped += 1
    print(f"retagged {changed} serialized files to iPhone, {skipped} already non-Android")


if __name__ == "__main__":
    main()
