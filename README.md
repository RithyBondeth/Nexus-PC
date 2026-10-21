# 🚀 Nexus-PC (Stratum Engine)
> **The Zero-Configuration, Plug-and-Play PC Game Runner for Android**

[![Flutter](https://img.shields.io/badge/Frontend-Flutter-blue?logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Platform-Android_12%2B-green?logo=android)](https://developer.android.com)
[![Status](https://img.shields.io/badge/Status-Active_Development-orange)]()

**Nexus-PC** is a next-generation Android application that bridges the gap between desktop PC gaming and mobile hardware. Existing Windows translation layers on mobile require tedious container creation, manual driver installation, and complex keymapping. Nexus-PC eliminates this friction entirely via an automated **Cloud Fingerprinting & SoC Alias Normalization** engine.

Simply import your DRM-free game directory or archive, and the app automatically provisions the right translation runtime, injects optimized Mesa Turnip graphics drivers, and launches your game seamlessly.

---

## ✨ Key Features

* **🔌 True Plug-and-Play UX:** No manual Wine prefixes, DXVK toggles, or container configuration required. 
* **⚡ Flutter-Powered Dashboard:** A gorgeous, high-performance UI built with Flutter and Isar DB for lightning-fast local library management.
* **🧠 Automated Cloud Profile Matching:** Automatically detects your device chipset and fetches community-verified execution flags via a lightweight cloud backend.
* **🌐 Universal SoC Abstraction:** Future-proof architecture featuring server-side alias normalization to instantly support evolving Qualcomm Snapdragon tiers (Gen 2, Gen 3, Elite, and beyond) without client app updates.
* **🎮 Smart Touch & Controller Overlays:** Automatically maps contextual on-screen gamepads or translates inputs directly via zero-latency C++ XInput bridges.

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
