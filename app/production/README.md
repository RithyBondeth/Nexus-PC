# Nexus-PC production foundation

Android-only Flutter app, separate from the legacy-target Phase 0 spike.
Package: `com.nexuspc.app`. Minimum API 31; compile/target API 36; ARM64 only.
The ordinary APK excludes Wine/Box64. An explicit experimental runtime build is
available; runtime downloads and cloud services are not integrated.

## Build and validate

Requires Flutter 3.44.8, Java 17, Android SDK 36, NDK 28.2.13676358 and
CMake 3.22.1. From this directory:

```sh
flutter pub get --enforce-lockfile
bash ../../tools/generate-production-api.sh
dart format --output=none --set-exit-if-changed lib pigeons test integration_test test_driver
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
cd android
./gradlew lintDebug
cd ..
flutter build apk --release --target-platform android-arm64 -t lib/main.dart
```

Generated Dart/Kotlin bindings are committed. Change `pigeons/nexus_api.dart`,
regenerate both sides together, and do not edit generated bindings manually.
Pigeon is a pinned build-time dependency, not a runtime engine.

From the repository root, with an unlocked, USB-debugging-authorized device:

```sh
ADB=/path/to/adb bash tools/run-production-device-check.sh DEVICE_SERIAL
```

Accept the installation prompt if shown. The script installs only this package,
restarts it, runs native checks, rejects stale reports, and saves JSON/log/screenshot
evidence in a new temporary directory. Python 3 is used to validate the JSON.
Screenshot capture is skipped if the app is no longer foreground; inspect the
image before publishing evidence, since the user can switch apps during capture.

The app displays actual device/GPU data and a packaged-executable diagnostic.
The helper is a tiny libc-independent ARM64 ELF, not a Windows runtime.
In the ordinary build, prepare/launch return `runtime_unavailable`; stop/status
remain unavailable.
Release signing is intentionally unconfigured. Debug APKs are development
artifacts, not distributable releases.

See [Phase 1 acceptance](../../docs/phase-1-foundation.md) and the
[bridge decision](../../docs/architecture/0001-production-bridge.md).

The Phase 2 shell adds Home, Library, Device and Settings. Appearance follows the
system at launch and can be changed for the current session. The Library now
supports folder/ZIP imports and private-copy management. Native diagnostics remain
accessible on Device.
See [Phase 2 validation](../../docs/phase-2-shell.md), including the repeatable
physical-device UI test and restoring the normal APK afterward.

The Phase 3 Library has import progress and cancellation, paged title search,
executable selection, editable titles, SHA-256 details and confirmed removal.
Original sources are preserved. Keep the app open during copying. Windows game
launching remains unavailable. See [Phase 3 validation](../../docs/phase-3-library.md)
for emulator coverage and outstanding physical-device acceptance.

## Optional experimental Windows runtime

From the repository root, run `JAVA_HOME=/path/to/jdk17 bash tools/build-production-runtime.sh`.
This packages pinned Wine/Box64 for 4 KB- and 16 KB-page ARM64 devices and the primary Android
user, adds native prepare/launch/stop state and enables experimental library launch.
The original Windows GDI smoke game passed on the API 36 emulator without a phone.
The regular build remains runtime-free. See [runtime procedure and limits](../../docs/runtime-emulator.md).

The experimental runtime now uses a source-built Box64 interpreter and rebuilt
Android display libraries. See [16 KB support and validation](../../docs/runtime-16k.md)
for page-specific prefixes, excluded MIDI/PulseAudio features, and emulator checks.
