<div align="center">

# Nexus-PC

**A zero-configuration, plug-and-play PC game runner for Android: import a DRM-free Windows game and play it, with no Wine containers, driver setup, or keymapping.**

![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Kotlin](https://img.shields.io/badge/Kotlin-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white)
![C++](https://img.shields.io/badge/C++-00599C?style=for-the-badge&logo=cplusplus&logoColor=white)
![Vulkan](https://img.shields.io/badge/Vulkan-AC162C?style=for-the-badge&logo=vulkan&logoColor=white)

</div>

---

## Overview

Running Windows games on Android today means hand-building Wine containers, installing graphics drivers, toggling DXVK, and mapping controls. Nexus-PC aims to remove all of that. You import a DRM-free game folder or archive, and the app picks the right translation runtime and drivers for your device and launches the game.

> **Status: active development (Phase 3 of the plan).** The Android app foundation, adaptive shell, and native game library are being built. **Game import and launching are not yet available in the app.** Phase 0 proved on a real device that a Windows game can run through a pinned Wine/Box64 runtime. The features below marked *planned* are goals, not current functionality.

## Features

### Working Today

- **Verified runtime feasibility (Phase 0):** an original Windows GDI test game ran on a Xiaomi 17 Pro through a pinned Winlator-based Wine/Box64 runtime, with stock Vulkan presentation, input, and clean shutdown.
- **Modern Android foundation (Phase 1):** a typed Dart/Kotlin bridge (Pigeon), C++ Vulkan device profiling, bounded native diagnostics, and Android build CI, targeting API 36 on ARM64.
- **Adaptive app shell (Phase 2):** Home, Library, Device, and Settings with live device status, accessible adaptive layouts, and appearance controls.
- **Native game library (Phase 3, in progress):** an SQLite library with safe imports, which includes:
  - bounded file and ZIP copying with path, alias, and symlink validation
  - ZIP preflight and CRC checks
  - Windows executable (PE) inspection and SHA-256 fingerprints
  - transactional publication with crash recovery
  - validated title and executable editing

### Planned

- **Plug-and-play launching:** automatic runtime provisioning, Mesa Turnip drivers, and DXVK, with no Wine prefixes or container setup.
- **Cloud profile matching:** detect the device chipset and fetch community-verified launch settings.
- **System-on-chip (SoC) alias normalization:** support new Snapdragon generations from the server side, without app updates.
- **Touch and controller input:** contextual on-screen gamepads and direct controller translation.

## Tech Stack

| Area | Technology |
| --- | --- |
| App UI | Flutter, Dart |
| Native host | Kotlin, Android SDK 36 (minimum API 31, ARM64) |
| Native core | C++ (NDK, CMake), Vulkan device profiling |
| Bridge | Pigeon (typed Dart and Kotlin APIs) |
| Library storage | Android SQLite |
| Runtime (Phase 0 experiment) | Winlator, Wine, Box64, Mesa Turnip, DXVK |
| Landing page | Static HTML, CSS, and JavaScript |
| CI | GitHub Actions |

## Getting Started

### Prerequisites

- Flutter 3.44.8, Java 17, Android SDK 36, NDK 28.2.13676358, and CMake 3.22.1
- An ARM64 Android device (Android 12 or later) with USB debugging, for device checks

### Build the Production App

The app code currently lives on the `develop` branch.

```bash
git clone -b develop https://github.com/RithyBondeth/Nexus-PC.git
cd Nexus-PC/app/production
flutter pub get --enforce-lockfile
bash ../../tools/generate-production-api.sh
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

Run the on-device checks from the repository root:

```bash
ADB=/path/to/adb bash tools/run-production-device-check.sh DEVICE_SERIAL
```

See [`app/production/README.md`](app/production/README.md) for the full build and validation steps. The Phase 0 runtime experiment in [`app/feasibility`](app/feasibility) has its own setup in [`runtime/README.md`](runtime/README.md).

### Run the Landing Page

```bash
cd landing
npm install
npm run assets
npm run dev
```

Open [http://127.0.0.1:4173](http://127.0.0.1:4173).

## Roadmap

| Phase | Scope | Status |
| --- | --- | --- |
| 0 | Vulkan and Windows runtime feasibility on a real device | ✅ Verified |
| 1 | Modern-target Android foundation and typed native bridge | ✅ Done |
| 2 | Adaptive app shell with shared device state | ✅ Done |
| 3 | Local library and safe game imports | 🚧 In progress |
| 4+ | Runtime integration, launching, profiles, and input | ⏳ Planned |

## Project Structure

```text
Nexus-PC/
├── app/
│   ├── production/      # Flutter app: shell, library, native Kotlin and C++ core
│   └── feasibility/     # Phase 0 runtime spike (legacy Android target)
├── runtime/             # Pinned Winlator-based runtime build, patches, lock file
├── tools/               # Build, code generation, and device-check scripts
├── test/windows/        # Original Windows smoke-test game (C)
├── docs/                # Phase reports, architecture decisions, device evidence
└── landing/             # Project landing page
```

## Documentation

- [Phase 0: feasibility](docs/phase-0-feasibility.md)
- [Phase 1: foundation](docs/phase-1-foundation.md)
- [Phase 2: app shell](docs/phase-2-shell.md)
- [Phase 3: library and imports](docs/phase-3-library.md)
- Architecture decisions: [production bridge](docs/architecture/0001-production-bridge.md) and [local library](docs/architecture/0002-local-library.md)
- [Project report (PDF)](docs/nexus_pc_report.pdf)

## Third-Party Components

The Phase 0 runtime is prepared locally from pinned upstream sources and is not committed (see [`runtime/components.lock.json`](runtime/components.lock.json)). These components keep their own licenses, including [Winlator](https://github.com/brunodev85/winlator-app) (LGPL-2.1), [Wine](https://gitlab.winehq.org/wine/wine), [Box64](https://github.com/ptitSeb/box64), [Mesa](https://gitlab.freedesktop.org/mesa/mesa), and [DXVK](https://github.com/doitsujin/dxvk).

Nexus-PC is meant only for games you own.

## Author

**Rithy Bondeth** — Full Stack Developer & AI Engineer

[![Portfolio](https://img.shields.io/badge/Portfolio-0A0A0A?style=for-the-badge&logo=vercel&logoColor=white)](https://bondeth.dev)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/RithyBondeth)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/rithy-bondeth-484073282/)
