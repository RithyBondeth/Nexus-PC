# Nexus-PC production foundation

Android-only Flutter app, separate from the legacy-target Phase 0 spike.
Package: `com.nexuspc.app`. Minimum API 31; compile/target API 36; ARM64 only.
No Wine, Box64, runtime downloads or cloud service is integrated here yet.

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
Prepare/launch return `runtime_unavailable`; stop/status remain unavailable.
Release signing is intentionally unconfigured. Debug APKs are development
artifacts, not distributable releases.

See [Phase 1 acceptance](../../docs/phase-1-foundation.md) and the
[bridge decision](../../docs/architecture/0001-production-bridge.md).

The Phase 2 shell adds Home, Library, Device and Settings. Appearance follows the
system at launch and can be changed for the current session. Library import is
explicitly disabled until Phase 3. Native diagnostics remain accessible on Device.
See [Phase 2 validation](../../docs/phase-2-shell.md), including the repeatable
physical-device UI test and restoring the normal APK afterward.
