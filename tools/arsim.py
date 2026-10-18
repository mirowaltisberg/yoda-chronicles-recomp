"""Make Unity 4.6's arm64 iOS engine archive linkable for the arm64 iOS Simulator.

Most of the 2015 objects carry no platform load command, and the modern linker assumes the target
platform for them. A few (FMOD, some ObjC files) carry LC_VERSION_MIN_IPHONEOS, which makes the linker
refuse them for the Simulator. This tool removes that command, so those objects look like the rest:
the following load commands move up by 16 bytes, the freed bytes become zero padding, and no section,
symbol or relocation offset changes. Members are edited in place (member sizes stay the same), so the
archive layout and its symbol table stay valid; the archive has duplicate member names, which is why
it is not unpacked and repacked.

Usage: python -I tools/arsim.py <in.a> <out.a>
"""
import struct
import sys

LC_VERSION_MIN_IPHONEOS = 0x25
LC_BUILD_VERSION = 0x32
PLATFORM_IOS, PLATFORM_IOSSIM = 2, 7
MH_MAGIC_64 = 0xFEEDFACF


def fix_object(buf, start, size):
    """Edits the Mach-O object at buf[start:start+size]; returns what was done or None."""
    if size < 32 or struct.unpack_from("<I", buf, start)[0] != MH_MAGIC_64:
        return None
    ncmds, sizeofcmds = struct.unpack_from("<II", buf, start + 16)
    off = start + 32
    end = off + sizeofcmds
    done = None
    i = 0
    while i < ncmds:
        cmd, cmdsize = struct.unpack_from("<II", buf, off)
        if cmd == LC_VERSION_MIN_IPHONEOS:
            buf[off:end - cmdsize] = buf[off + cmdsize:end]
            buf[end - cmdsize:end] = b"\0" * cmdsize
            ncmds -= 1
            sizeofcmds -= cmdsize
            end -= cmdsize
            struct.pack_into("<II", buf, start + 16, ncmds, sizeofcmds)
            done = "version-min removed"
            continue
        if cmd == LC_BUILD_VERSION and struct.unpack_from("<I", buf, off + 8)[0] == PLATFORM_IOS:
            struct.pack_into("<I", buf, off + 8, PLATFORM_IOSSIM)
            done = "build-version retagged"
        off += cmdsize
        i += 1
    return done


def main():
    data = bytearray(open(sys.argv[1], "rb").read())
    if data[:8] != b"!<arch>\n":
        raise SystemExit("not an ar archive")
    pos = 8
    counts = {}
    while pos + 60 <= len(data):
        hdr = data[pos:pos + 60]
        name = hdr[0:16].decode("ascii").rstrip()
        size = int(hdr[48:58].decode("ascii").strip())
        body = pos + 60
        name_len = 0
        if name.startswith("#1/"):  # BSD long name stored at the start of the member data
            name_len = int(name[3:])
        result = fix_object(data, body + name_len, size - name_len)
        if result:
            counts[result] = counts.get(result, 0) + 1
        pos = body + size + (size & 1)
    open(sys.argv[2], "wb").write(data)
    print(sys.argv[2], counts)


if __name__ == "__main__":
    main()
