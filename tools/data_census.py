"""Census of the Unity serialized data of the Android build.

For every serialized file (mainData, sharedassets*, level*, the GUID-named resource files in the OBB):
header (format version, Unity version, target platform), object counts per class, and texture formats.
Split files (`name.split0..N`) are joined in memory.

Usage: python -I tools/data_census.py <Data dir> [<Data dir> ...]
"""
import collections
import pathlib
import re
import struct
import sys

import UnityPy
from UnityPy.enums import ClassIDType

SPLIT = re.compile(r"^(?P<base>.+)\.split(?P<n>\d+)$")


def logical_files(dirs):
    """Yield (name, bytes) for every serialized file, joining splits."""
    splits = collections.defaultdict(dict)
    for d in dirs:
        for p in sorted(pathlib.Path(d).iterdir()):
            if p.is_dir():
                continue
            m = SPLIT.match(p.name)
            if m:
                splits[m["base"]][int(m["n"])] = p
            else:
                yield p.name, p.read_bytes()
    for base, parts in splits.items():
        yield base, b"".join(parts[i].read_bytes() for i in sorted(parts))


def header(data):
    """Unity serialized file header, format 9 (big-endian header)."""
    meta_size, file_size, version, data_offset = struct.unpack_from(">IIII", data, 0)
    if version > 30 or file_size != len(data):
        return None
    endian = data[16]
    end = data.index(b"\0", 20)
    unity = data[20:end].decode("ascii", "replace")
    platform = struct.unpack_from("<i" if endian == 0 else ">i", data, end + 1)[0]
    return {"format": version, "unity": unity, "platform": platform, "size": file_size}


def main():
    dirs = sys.argv[1:]
    platforms = collections.Counter()
    classes = collections.Counter()
    tex_formats = collections.Counter()
    audio_formats = collections.Counter()
    shaders = []
    not_serialized = []
    for name, data in logical_files(dirs):
        h = header(data)
        if not h:
            not_serialized.append((name, len(data)))
            continue
        platforms[(h["unity"], h["format"], h["platform"])] += 1
        try:
            env = UnityPy.load(data)
        except Exception as e:  # noqa: BLE001 - report and continue
            print(f"!! {name}: {e}")
            continue
        for obj in env.objects:
            classes[obj.type.name] += 1
            if obj.type == ClassIDType.Texture2D:
                try:
                    t = obj.read()
                    tex_formats[str(t.m_TextureFormat)] += 1
                except Exception as e:  # noqa: BLE001
                    tex_formats[f"unreadable: {type(e).__name__}"] += 1
            elif obj.type == ClassIDType.AudioClip:
                try:
                    a = obj.read()
                    audio_formats[str(getattr(a, "m_Type", "?")) + "/" + str(getattr(a, "m_Format", "?"))] += 1
                except Exception as e:  # noqa: BLE001
                    audio_formats[f"unreadable: {type(e).__name__}"] += 1
            elif obj.type == ClassIDType.Shader:
                try:
                    shaders.append(obj.read().m_Name)
                except Exception:  # noqa: BLE001
                    shaders.append("?")
    print("serialized files by (unity, format, platform):", dict(platforms))
    print("not serialized (raw):", not_serialized[:20], "..." if len(not_serialized) > 20 else "")
    print("texture formats:", dict(tex_formats))
    print("audio clip formats:", dict(audio_formats))
    print(f"shaders ({len(shaders)}):", sorted(set(shaders)))
    print("objects per class:")
    for k, v in classes.most_common():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
