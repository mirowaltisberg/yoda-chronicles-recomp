# yoda-chronicles-recomp

Personal preservation project: run LEGO Star Wars: The Yoda Chronicles (Android build 10.0.31, Unity 4.6.6p1)
natively on iOS 27 / iPhone 17, by pairing the game's original C# code and data with Unity's own arm64 iOS
player of the same engine generation, with the C# translated ahead of time to native code.

Sister project of `ninjago-recomp` (same goal, different engine: Ninjago is a native C++ engine, Yoda Chronicles
is a Unity/Mono game).

**No game code or data lives in this repository.** Put your own copies in `input/` (git-ignored).
Anything generated from them (translated code, converted data, builds) goes to `gen/` or `build/`
(git-ignored) and is never committed.

Inputs and their hashes: `docs/inputs.md`
Design: `docs/superpowers/specs/`
Status, findings and how to build/run: `docs/m3-m5-sim-report.md`

## Status (19.10.2026)

Runs in the iOS 27 Simulator: intro movie, side selection, menus, Coruscant mission 1 playable with touch.
iPhone build compiles; installing it on the phone is the next step.
