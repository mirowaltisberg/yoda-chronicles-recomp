"""Convert the textures Apple GPUs cannot use, and the engine cannot decode either, to RGBA32 (in place).

The Android build holds three textures in desktop/Adreno-only formats: the game font's distance-field
atlas `maquiFont_0_distance` (ATC_RGBA8) and two minifig skins (DXT1). Unity 4.6's iOS player tries to
decompress them in software and fails ("ATC compressed texture format not supported, decompressing! /
Decompressing level 0 failed!"), which leaves every text in the game invisible. They are decoded here
once into uncompressed RGBA32, the format Unity itself falls back to, and their files re-serialized.

Unity 4.6 Texture2D layout used here: ... m_CompleteImageSize (int32), m_TextureFormat (int32), ...,
then image data as int32 length + bytes at the end of the object. Only those three fields change; the
pixel rows stay in Unity's bottom-up order.

Usage: python -I tools/convert_textures.py <Data dir>
"""
import os
import struct
import sys

import texture2ddecoder
import UnityPy
from UnityPy.enums import ClassIDType

RGBA32 = 4
DECODERS = {
    10: texture2ddecoder.decode_bc1,         # DXT1
    12: texture2ddecoder.decode_bc3,         # DXT5
    35: texture2ddecoder.decode_atc_rgb4,    # ATC_RGB4
    36: texture2ddecoder.decode_atc_rgba8,   # ATC_RGBA8
}


def convert_object(obj):
    tex = obj.read()
    fmt = int(tex.m_TextureFormat)
    if fmt not in DECODERS:
        return None
    w, h = tex.m_Width, tex.m_Height
    raw = bytearray(obj.get_raw_data())
    old_size = struct.unpack_from("<i", raw, len(raw) - 4 - len(tex.image_data))[0]
    if old_size != len(tex.image_data):
        raise ValueError(f"{tex.m_Name}: image data is not the last field ({old_size} != {len(tex.image_data)})")
    # level 0 only: the textures in question have no mip chain
    level0 = bytes(tex.image_data)
    bgra = DECODERS[fmt](level0, w, h)
    rgba = bytearray(len(bgra))
    rgba[0::4], rgba[1::4], rgba[2::4], rgba[3::4] = bgra[2::4], bgra[1::4], bgra[0::4], bgra[3::4]
    # m_CompleteImageSize and m_TextureFormat: the two int32 after name, width and height
    name_len = struct.unpack_from("<i", raw, 0)[0]
    off = 4 + name_len
    off += (-off) % 4
    width, height, complete, tformat = struct.unpack_from("<iiii", raw, off)
    if (width, height, tformat) != (w, h, fmt):
        raise ValueError(f"{tex.m_Name}: unexpected header {width}x{height} fmt {tformat}")
    struct.pack_into("<ii", raw, off + 8, len(rgba), RGBA32)
    head = raw[:len(raw) - 4 - old_size]
    obj.set_raw_data(bytes(head) + struct.pack("<i", len(rgba)) + bytes(rgba))
    return f"{tex.m_Name} {w}x{h} fmt {fmt} -> RGBA32"


def main():
    root = sys.argv[1]
    for name in sorted(os.listdir(root)):
        path = os.path.join(root, name)
        if not os.path.isfile(path):
            continue
        try:
            env = UnityPy.load(path)
        except Exception:  # noqa: BLE001 - not a Unity file
            continue
        done = []
        for obj in env.objects:
            if obj.type == ClassIDType.Texture2D:
                r = convert_object(obj)
                if r:
                    done.append(r)
        if done:
            sf = next(iter(env.files.values()))
            with open(path, "wb") as f:
                f.write(sf.save())
            print(f"{name}: " + "; ".join(done))


if __name__ == "__main__":
    main()
