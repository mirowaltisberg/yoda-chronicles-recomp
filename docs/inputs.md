# Inputs (personal copies, never committed)

| File in `input/` | Source file | SHA-256 |
|---|---|---|
| `apk/yoda-android-10.0.31.apk` | `LEGO-Star-Wars-The-Yoda-Chronicles-v10-0-31 (1).apk` | `1c777beb5db7fa97c6bad298c92d53b968a5c7f69474d870e7b30e1bfbb1ae74` |
| `cache/yoda-cache-10.0.31.zip` | `07165-LEGO-STAR-WARS-v10-0-31-cache1 (1).zip` (holds `main.10.com.lego.starwars.theyodachronicles.obb`) | `abd563b3e379851f6bfc1c548fd5d89c3a162bfae6a727dadbb988c612d7649f` |
| `ipa/yoda-ios.ipa` | `LEGO__STAR_WARS__THE_YODA_CHRONICLES_1_ios_5.0.ipa` | `cdba0bcdfc562a1576b402160fbe39a69a8bfb062374ea707c9b15dc56a1d50d` |

## First findings (19.10.2026)

| | Android 10.0.31 (APK + OBB) | iOS IPA |
|---|---|---|
| Engine | Unity **4.6.6p1** | Unity **4.1.2f1** |
| Game code | C# IL: `Assembly-CSharp.dll` (813 KB), `-firstpass` (167 KB), Prime31 plugins | same kind, older (760 KB / 120 KB) |
| Native code | `libunity.so`, `libmono.so` (Mono **JIT**), `libmain.so`; armeabi-v7a and x86 | one armv7 Mach-O (`cryptid 0`), engine + Mono full-AOT |
| Scenes | `level0` … `level27` (28) in the OBB (725 entries, 302 MB) | `level0` … `level24` (25) |
| Bundle id | `com.lego.starwars.theyodachronicles` | same, version 1.0, `MinimumOSVersion` 5.0 |
