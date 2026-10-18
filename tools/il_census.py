"""IL census of the game's managed assemblies.

Lists, per assembly: referenced assemblies, native imports (P/Invoke), and every member
reference into UnityEngine grouped by type. Android-only APIs (AndroidJava*, AndroidInput, ...)
are flagged, since the Android build was compiled with UNITY_ANDROID and those calls are baked
into the IL.

Usage: python -I tools/il_census.py <Managed dir> [--members]
"""
import collections
import pathlib
import sys

import dnfile

GAME_ASSEMBLIES = None  # None = every non-framework dll in the folder
FRAMEWORK = {"mscorlib.dll", "System.dll", "System.Core.dll", "System.Xml.dll", "Mono.Security.dll",
             "UnityEngine.dll", "UnityEngine.UI.dll"}
ANDROID_HINTS = ("Android", "Handheld", "GooglePlay", "Obb")


def _name(row_ref):
    try:
        return row_ref.row.TypeNamespace + "." + row_ref.row.TypeName
    except AttributeError:
        return "?"


def census(path, show_members):
    pe = dnfile.dnPE(str(path))
    md = pe.net.mdtables
    print(f"== {path.name}")
    if md.AssemblyRef:
        refs = [f"{str(r.Name)} {r.MajorVersion}.{r.MinorVersion}" for r in md.AssemblyRef]
        print("  assembly refs:", ", ".join(refs))
    if md.ImplMap:
        pinv = collections.Counter()
        for r in md.ImplMap:
            pinv[str(r.ImportScope.row.Name)] += 1
        print("  P/Invoke modules:", dict(pinv))
        if show_members:
            for r in md.ImplMap:
                print(f"    [{str(r.ImportScope.row.Name)}] {str(r.ImportName)}")
    # type refs grouped by resolution scope (assembly)
    by_type = collections.defaultdict(set)
    if md.MemberRef:
        for m in md.MemberRef:
            parent = m.Class
            if parent is None or parent.table is None:
                continue
            if parent.table.name == "TypeRef":
                t = parent.row
                scope = t.ResolutionScope.row
                scope_name = str(getattr(scope, "Name", "?"))
                by_type[(scope_name, f"{str(t.TypeNamespace)}.{str(t.TypeName)}")].add(str(m.Name))
    types_by_asm = collections.defaultdict(list)
    for (asm, t), members in sorted(by_type.items()):
        types_by_asm[asm].append((t, members))
    for asm, types in types_by_asm.items():
        print(f"  -> {asm}: {len(types)} types, {sum(len(m) for _, m in types)} members")
        for t, members in types:
            flag = "  [ANDROID]" if any(h in t for h in ANDROID_HINTS) else ""
            if show_members or flag:
                print(f"     {t}{flag}: {', '.join(sorted(members))}")
    # Android-only type refs without member refs (e.g. only used as field types)
    if md.TypeRef:
        for t in md.TypeRef:
            full = f"{str(t.TypeNamespace)}.{str(t.TypeName)}"
            if any(h in full for h in ANDROID_HINTS) and not any(full == k[1] for k in by_type):
                print(f"     typeref only: {full}  [ANDROID]")


def main():
    managed = pathlib.Path(sys.argv[1])
    show_members = "--members" in sys.argv
    for dll in sorted(managed.glob("*.dll")):
        if GAME_ASSEMBLIES is None and dll.name in FRAMEWORK and dll.name != "UnityEngine.UI.dll":
            continue
        census(dll, show_members)


if __name__ == "__main__":
    main()
