# M0–M6 report: the game runs in the iOS 27 Simulator and on the iPhone 17 (19.10.2026)

## Result

In this project's own Simulator ("Yoda iPhone 17", iOS 27.0, `build/sim-udid`) the original game runs:
Unity splash → intro movie (89 s, plays to the end) → **Select Side** → **Jedi main menu** → **Planet
Select** (1. Coruscant) → **Mission Select** → **Mission Goals** ("Learn with Yoda") → **level**:
Coruscant mission 1 loads and plays. The tutorial runs ("Learn with me" → "Tap to move"), a tap moves
Yoda and his squad, the camera follows, timer and stud counter run.

| Check | Result |
|---|---|
| Engine | Unity 4.6.6f2 iOS player (arm64, IL2CPP), OpenGL ES 3.0 device |
| Game code | `Assembly-CSharp` etc. as IL2CPP C++ (168 files), game `Debug.Log` output in the console |
| Data | the Android 10.0.31 data (632 files retagged), all 28 scenes present |
| Text | renders (font atlas converted from ATC) |
| Touch | developer taps through the engine's own touch entry points; UIKit hit-testing at the tap points reaches `UnityView`, so real touches take the same path |
| Movies | `IntroMovie.mp4` plays through AVPlayer and ends; Unity resumes |
| Audio | FMOD streams and mixes the menu music (MP3 via AudioQueue), RemoteIO output unit running; **not checked by ear** |
| Saves | persist across launches: `menuData` and `levelProgression` are saved (PlayerPrefs, `Library/Preferences/ch.mirowaltisberg.yodachronicles.plist`) and found again after a relaunch |
| iPhone | runs on Miró's iPhone 17 (iOS 27): see "On the iPhone" below |

## On the iPhone (M6, 19.10.2026 morning)

`tools/run_phone.sh` (signed with the team's wildcard development profile, no new App ID needed).

| Check | Result |
|---|---|
| Renderer | Apple A19 GPU, "OpenGL ES 3.0 Metal", native 2622×1206 |
| Start-up | engine up in about 1 s, scene `Main` loaded about 0.5 s later |
| Intro movie | plays to the end (AVPlayer replacement) |
| Touch | real finger taps: Select Side → Jedi → Main Menu → Planet → Mission → Brief |
| Gameplay | Coruscant mission 1 played to the **Win** screen (unit build screen and map used on the way); mission 2 started |
| Errors | none in the console: no exceptions, no memory warnings |
| Screen edges | checked against the iPhone 17 display mask (`simctl io screenshot --mask=black`, now used by `watch_sim.sh`): HUD (minimap, timer, pause, studs) and all menu buttons sit inside the rounded corners; the Dynamic Island only covers scenery. No layout change needed |
| App icon | the original App Store artwork from the user's IPA, upscaled to 1024×1024 at build time (`make_xcode.sh`), not committed |

Notes: launching from the Mac needs the phone unlocked (`run_phone.sh` retries). The first install once
dropped with "Connection invalid" and succeeded on retry.

## Findings, in the order they blocked

| Symptom | Cause | Fix |
|---|---|---|
| `il2cpp.exe` NullReferenceException | assemblies are passed as `--assembly=a,b`, not positionally | `tools/build_managed.sh` |
| `__declspec(noreturn)` errors | 2015 IL2CPP headers, modern clang | `-fdeclspec` for the generated code |
| Trampoline compile errors (iAd, Metal fallback types, enum casts, narrowing) | iOS 27 SDK and modern clang | `ios/trampoline.patch`, `-Wno-c++11-narrowing` |
| GNU `std::string`/iostream symbols undefined (98) | engine built against Apple's GCC 4.2 libstdc++ | GCC 16 `libstdc++.a` without `libsupc++` members, retagged (`tools/make_gnustdcxx.sh`); `ios/Shim/GnuBridge.mm`, `GnuRuntime.cpp` |
| "linking in object file built for 'iOS'" | 175 engine objects carry `LC_VERSION_MIN_IPHONEOS` | removed in place for the Simulator archive (`tools/arsim.py`) |
| "File's Build target is: 13" | data says Android | header target → 9 (`tools/retarget_data.py`) |
| "Expected version: 4.6.6f2. Actual version: 4.6.6p1" | player requires its exact version | version string rewritten (same length) |
| Crash in `-[UIWindow setRootViewController:]` | iOS 26+ presentation transition on root swaps; Unity swaps roots per orientation | one permanent root container, Unity's controllers as children |
| Engine picked Metal | Android data has GLES2/GLES3 shaders only | Metal disabled in `SelectRenderingAPIImpl` → GLES3 |
| Splash for minutes, `sample` shows `GLRendererFloat` | Simulator renders GL in software, at 3× | 1× in the Simulator (`UnityScreenScaleFactor`) |
| Loading bar never finishes | `SendSignalsOnAwakeCheckPlatform.Start` only starts the game when "running on Android and the OBB is present" | `GooglePlayDownloader` reports exactly that (ILPatch stubs) |
| Movie frozen on one frame | `MPMoviePlayerViewController` is dead on iOS 27; engine relies on autoplay and `MPMoviePlayerPlaybackDidFinishNotification` | `UnityVideoViewController` rewritten on AVPlayer with the same interface |
| All text invisible, "Decompressing level 0 failed!" | font atlas `maquiFont_0_distance` is ATC_RGBA8 (Adreno only); 2 minifig skins DXT1 | decoded to RGBA32 at data build time (`tools/convert_textures.py`) |

## How to build and run

```
tools/build_managed.sh        # IL patch + IL2CPP -> build/il2cppOutput (incremental by content)
tools/make_data.sh            # Android APK+OBB -> build/Data (iOS layout, retagged, textures converted)
tools/make_xcode.sh           # Trampoline + patch + generated Register* files -> build/xcode
(cd ios && xcodegen generate) # ios/Yoda.xcodeproj: targets YodaSim, YodaPhone
tools/run_sim.sh 60           # build YodaSim, install in "Yoda iPhone 17", console -> build/run.log
```

Watching the Simulator window yourself: `open -a Simulator --args -CurrentDeviceUDID $(cat build/sim-udid)`
(the Ninjago session uses its own "iPhone 17" device in the same Simulator app; leave that one alone).

Unattended testing (developer only, inactive unless set):
- `YODA_SKIP_MOVIES=1` ends every movie immediately.
- `YODA_TAPS="T:x,y;T:x,y>x2,y2@D"` taps / drags at T seconds after launch, x/y as screen fractions.
- `tools/watch_sim.sh 200 10 "30:0.27,0.5;45:0.5,0.58;60:0.62,0.87;75:0.23,0.32;90:0.62,0.87"` goes from
  launch to Coruscant mission 1 and screenshots every 10 s into `build/shots/`.

## Open

- Audio by ear; a full level to the end; other movies.
- "No receiver of signal OnSignal" warnings from the game's own GUI (also present on Android, harmless so far).
