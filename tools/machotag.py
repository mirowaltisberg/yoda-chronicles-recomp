"""Retag Mach-O arm64 object files for another Apple platform (in place).

GCC's libstdc++.a (Homebrew, aarch64-apple-darwin) is built for macOS. Its objects carry an
LC_BUILD_VERSION with platform 1; the iOS Simulator linker wants 7, the device 2. The command has the
same size for every platform, so only the platform/minos fields change. Objects without any platform
command (Unity 4.6's 2015 objects) are left alone; the linker assumes the target platform for them.

Usage: python -I tools/machotag.py <platform: ios|iossim> <minos e.g. 26.0> file.o [file.o ...]
"""
import struct
import sys

LC_BUILD_VERSION = 0x32
LC_VERSION_MIN = {0x24, 0x25, 0x2F, 0x30}  # macosx, iphoneos, tvos, watchos
PLATFORMS = {"ios": 2, "iossim": 7}
MH_MAGIC_64 = 0xFEEDFACF


def encode_version(text):
    parts = [int(p) for p in text.split(".")] + [0, 0]
    return (parts[0] << 16) | (parts[1] << 8) | parts[2]


def retag(path, platform, minos):
    data = bytearray(open(path, "rb").read())
    magic, _cpu, _sub, _ftype, ncmds, _size, _flags, _res = struct.unpack_from("<IiiIIIII", data, 0)
    if magic != MH_MAGIC_64:
        raise ValueError(f"{path}: not a 64-bit little-endian Mach-O")
    off = 32
    changed = False
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, off)
        if cmd == LC_BUILD_VERSION:
            struct.pack_into("<III", data, off + 8, platform, minos, minos)  # platform, minos, sdk
            changed = True
        elif cmd in LC_VERSION_MIN:
            raise ValueError(f"{path}: has an LC_VERSION_MIN command; this tool only retags LC_BUILD_VERSION")
        off += cmdsize
    if changed:
        open(path, "wb").write(data)
    return changed


def main():
    platform = PLATFORMS[sys.argv[1]]
    minos = encode_version(sys.argv[2])
    n = sum(retag(p, platform, minos) for p in sys.argv[3:])
    print(f"retagged {n} of {len(sys.argv) - 3} objects")


if __name__ == "__main__":
    main()
