# 🚀 Nexus-PC (Stratum Engine)
> **The Zero-Configuration, Plug-and-Play PC Game Runner for Android**

[![Flutter](https://img.shields.io/badge/Frontend-Flutter-blue?logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Platform-Android_12%2B-green?logo=android)](https://developer.android.com)
[![Status](https://img.shields.io/badge/Status-Active_Development-orange)]()

**Nexus-PC** is an Android application, in active development, that aims to run DRM-free Windows PC games without manual Wine prefixes, driver installation or container configuration. Import a game folder or ZIP; the app keeps a validated private copy and, in the experimental runtime build, launches it through pinned Wine/Box64.

---

## ✨ Key Features

Available now:

* **📚 Local game library:** Folder and ZIP imports through the Android system picker into app-private copies, backed by Android SQLite (not Isar; see [ADR 0002](docs/architecture/0002-local-library.md)). Paged title search, executable selection, title edits, SHA-256 details, duplicate rejection and confirmed removal. Original sources are never modified.
* **🛡️ Bounded, safe imports:** Path traversal, alias, link, ZIP64/encryption and compression-bomb checks; size/entry limits; progress and cancellation; interruption recovery.
* **📱 Flutter shell:** Adaptive Home, Library, Device and Settings screens with accessible layouts and System/Light/Dark appearance.
* **🔍 Device profile:** Typed native bridge reporting Android API, SoC, ABIs, RAM and the stock Vulkan renderer/version.

Experimental (opt-in build, emulator-tested only):

* **🧪 Windows runtime:** Pinned Wine 10.10 and a source-built Box64 interpreter (no JIT) launch saved x86-64 executables from the library at target API 36 on 4 KB and 16 KB-page ARM64 hosts. Only Windows GDI titles have been tested; Direct3D, DXVK/Turnip, sound and controllers are unverified. Games run with the app's UID — run trusted games only. The ordinary APK excludes this runtime.

Planned (not yet implemented):

* **🧠 Cloud profile matching** of device chipsets to community-verified execution flags.
* **🌐 Server-side SoC alias normalization** for new Snapdragon tiers.
* **🎮 Touch and controller input overlays.**
* **🖥️ Mesa Turnip / DXVK graphics** for Direct3D games.

## Implementation status

Phase 0 device feasibility is verified on Xiaomi 17 Pro: stock Vulkan presentation
and an original Windows GDI game via pinned Wine/Box64, including input and clean
shutdown. The standalone diagnostic app lives in
[`app/feasibility`](app/feasibility). See the [feasibility gate and phase sequence](docs/phase-0-feasibility.md)
for build instructions and pending device checks. The runtime and product features above
are planned; this proof does not establish general game compatibility. The runtime
spike uses legacy Android targeting; production-runtime integration remains future work.

Phase 1 adds the separate modern-target app in [`app/production`](app/production):
typed Dart/Kotlin APIs, C++ Vulkan device profiling, bounded diagnostics, generated
bridge checks and Android build CI. Its target-API-36 packaged native helper passed
on the Xiaomi; Windows runtime integration remains unavailable in this app.
See [Phase 1 acceptance and limitations](docs/phase-1-foundation.md).

Phase 2 adds Home, Library, Device and Settings navigation, shared live device
status, accessible adaptive layouts and session-only appearance controls.
Windows runtime integration is still unavailable. See
[Phase 2 behavior and validation](docs/phase-2-shell.md) for acceptance status.

Phase 3 now connects the native SQLite library to the app: folder/ZIP imports,
progress/cancellation, paged title search, executable selection, title edits,
file hashes and confirmed removal of imported copies. Automated checks and
system-picker flows have been exercised on an ARM64 Android emulator. Physical
Xiaomi/HyperOS acceptance remains pending; Phase 3 is not declared complete.
See [Phase 3 status and validation](docs/phase-3-library.md).

An opt-in experimental Windows runtime now connects the library to pinned
Wine/Box64 at target API 36. The original x86-64 GDI game passed import, launch,
rendering, input and clean exit on 4 KB and 16 KB ARM64 emulators. See
[16 KB validation](docs/runtime-16k.md). The ordinary APK excludes
this runtime; general game compatibility remains unverified in
the experiment. See [runtime emulator validation](docs/runtime-emulator.md).
