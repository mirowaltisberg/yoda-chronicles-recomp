# LEGO Star Wars: The Yoda Chronicles on iOS 27: design

**Date:** 19.10.2026 · **Owner:** Miró (personal use) · **Status:** approved direction ("do the same as Ninjago"), building

## Intent

Same goal as `ninjago-recomp`: play a 32-bit-era LEGO mobile game again, natively, on the iPhone 17
(iOS 27) as a normal app installed with Miró's developer account, tested first in the iOS Simulator.
Here: LEGO Star Wars: The Yoda Chronicles (TT Games / LEGO, 2013), last Android build 10.0.31 (2016).

**Success:** boot to the menu, pick a side (Jedi/Sith), play the levels with original graphics, music,
cutscenes and touch controls; progress persists.

## Anti-goals (unchanged from Ninjago)

- No redistribution: no game code, game data, Unity code or anything generated from them goes to git.
  The repository holds only our tooling, our shims and a patch against Unity's Trampoline.
- No reimplementation "by eye": the original C# and data run, translated.
- No JIT on the phone.

## What is different from Ninjago, and why the route changes

| | Ninjago (`ninjago-recomp`) | Yoda Chronicles (this repo) |
|---|---|---|
| Engine | native C++ engine in `libLEGO_M1.so` (ARM32) | **Unity 4.6.6p1** (`libunity.so`) |
| Game logic | inside the native library | **C# IL** (`Assembly-CSharp.dll`, 813 KB) |
| On Android | runs as ARM32 code | Mono **JIT** compiles the IL at run time |
| Translator | our own ARM32 → C recompiler | **Unity's own IL2CPP** (IL → C++ → arm64) |
| Platform layer | our HLE (JNI, bionic, EGL, OpenSL) | **Unity's own 2015 iOS player** (arm64) + small shims |

Statically recompiling `libunity.so`/`libmono.so` like Ninjago does not work: Mono's JIT writes the game's
machine code at run time, so there is nothing fixed to translate, and iOS forbids writing code at run
time. The faithful analog of "run the original code, translated" is the path Unity itself offered in
2015 when Apple required arm64: the IL2CPP scripting backend of Unity 4.6.

## Decisions (with evidence)

1. **Source: the Android build, not the IPA.** The IPA is v1.0 / Unity 4.1.2 (armv7 only, Mono full-AOT
   baked into one Mach-O, 25 scenes). Android 10.0.31 is the last content update (28 scenes, 28
   cutscene movies) on Unity 4.6.6p1, the first Unity generation with arm64 iOS support.
2. **Engine: Unity 4.6.6's iOS player, from Unity's official installer** (`unity-4.6.6.dmg`,
   download.unity3d.com, sha256 `0a38e483…`). Only unpacked (`pkgutil --expand-full`), never installed
   or run (the 4.x editor is 32-bit). It contains `libiPhone-lib-il2cpp.a` with an **arm64** slice, the
   Trampoline (the Xcode app shell, as source) and the IL2CPP converter.
3. **Translator: IL2CPP 4.6.6, run headless with Homebrew Mono 6.14 (arm64).** The editor's exact
   pipeline was recovered from `UnityEditor.dll` (`IL2CPPBuilder.Run`): AssemblyPatcher on mscorlib →
   `il2cpp.exe --copy-level=None --emit-null-checks --enable-array-bounds-check --extra-types.file=…
   --assembly=… --generatedcppdir=… --builder=none` → `InternalCallRegistrationWriter`. Result: 168 C++
   files (274 MB) in 16 s, 6,398 engine internal calls registered.
4. **Class libraries:** the Android build's `mscorlib`/`System*` are byte-identical to the installer's
   `Mono/lib/mono/unity` profile, so the managed side matches the engine version exactly.
5. **Android-only code: a shim assembly, not edits.** Against the iOS `UnityEngine.dll`, the game's only
   unresolved references are `AndroidJavaObject`, `AndroidJavaClass`, `AndroidJNI` (Google Play OBB
   downloader, Prime31 Android dialogs, an HTTP bridge, Flurry). The game guards these calls with
   `Application.platform == Android`, which is false on the iOS player. `AndroidShim.dll` provides inert
   versions; ILPatch (Mono.Cecil) only retargets the type references. The game's IL is otherwise untouched.
6. **C++ runtime: GNU libstdc++.** The 2015 engine was built against Apple's GCC-4.2 libstdc++ (old
   copy-on-write `std::string` `_ZNSs…`, GNU iostreams, 98 symbols). iOS ships only libc++ now. GCC 16's
   static `libstdc++.a` keeps that ABI; we take it without its `libsupc++` members (exceptions, RTTI and
   new/delete stay with iOS's libc++abi, one C++ runtime) and retag the objects macOS → iOS (Simulator).
7. **Data: the Android data, unchanged**, in the iOS layout (`Data/`, splits joined, movies in `Data/Raw`).
   Same engine version, same GLES2 shader platform. Texture census: 170 ETC1, 124 RGBA4444, rest raw.
8. **App life cycle:** the iOS 27 SDK requires UIScene; a scene delegate adopts Unity's window and
   forwards the scene events to the Trampoline's old app-delegate callbacks.
9. **Simulator:** Unity's arm64 objects carry no platform load command, so they link for the arm64
   Simulator directly (no Rosetta on this Mac, so the x86_64 slice is useless).

## Architecture

```
 input/ (APK, OBB)                     Unity 4.6.6 installer (unpacked)            this repo
 ─────────────────                     ───────────────────────────────            ─────────
 Managed/*.dll ── ILPatch + shim ──▶  AssemblyPatcher ─▶ il2cpp.exe ─▶ build/il2cppOutput (C++)
 Data + OBB    ── make_data.sh ────▶  build/Data (iOS layout)
                                      Trampoline/Classes ── ios/trampoline.patch ─▶ build/xcode/Classes
                                      libiPhone-lib-il2cpp.a (arm64)            ios/Shim (scene, GNU bridge)
 GCC libstdc++.a ── make_gnustdcxx.sh (filter + retag) ─▶ libgnustdcxx.a
                                      └──────────── ios/project.yml (xcodegen) ──▶ YodaChronicles.app
```

## Milestones

| # | Result | Where |
|---|---|---|
| M0 | Inputs hashed, census (IL, data, engine symbols), Unity 4.6.6 iOS support unpacked | Mac |
| M1 | Managed pipeline: shim + IL2CPP output | Mac |
| M2 | Simulator app links (engine + IL2CPP code + GNU libstdc++ + Trampoline) | Mac |
| M3 | Simulator: first frames (splash, LEGO logo, intro movie) | Simulator |
| M4 | Simulator: menus, side selection, a level playable with sound and touch | Simulator |
| M5 | Device build with the dev account (libstdc++ retagged for iOS) | iPhone 17 |
| M6 | Polish: safe areas, save persistence, cutscenes on modern AVKit, app icon, credit | iPhone 17 |

## Open questions left to the builder

- Does the iOS player accept data whose header says Android (platform 13)? Patch the tag if not.
- ETC1 textures in a GLES2 context: does the player decompress unsupported formats, or do we decode
  them in a GL shim (like Ninjago's ATC decoder)?
- `MPMoviePlayerController` (cutscenes) on iOS 27: still present? Otherwise play `Data/Raw/*.mp4` with AVKit.
- Prime31 / Flurry / LEGO account services are dead; confirm they fail quietly.
