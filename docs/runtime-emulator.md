# Experimental Windows runtime on an emulator

Status: original GDI smoke proof plus a tested third-party x86-64 puzzle game; not a release or general compatibility claim.

See [Fifteen compatibility check and fixes](fifteen-emulator.md) for the real MIT Windows game, save/load, relaunch and Android Back/Exit results.

## Build

The ordinary production APK excludes the Windows runtime. Use the explicit
experimental build below. Requirements include the existing Flutter/Java/Android
SDK/NDK toolchain, Python 3, zstd, patchelf and MinGW-w64. The preparation script
verifies the locked upstream downloads and preserves the separate Phase 0 tree.

```sh
JAVA_HOME=/path/to/jdk17 bash tools/build-production-runtime.sh
```

Output: `app/production/build/runtime-apk/nexus-pc-runtime-debug.apk`.
The runtime APK is large (approximately 291 MiB) because it includes the pinned
runtime and its native libraries. It is a debug artifact with release signing and
distribution review still outstanding. Installing it over the ordinary app uses
the same package and library; uninstalling/clearing app data removes those copies.

The experimental runtime supports 4 KB and 16 KB host pages on the primary Android
user. See [16 KB implementation and validation](runtime-16k.md) for the source-built
Box64 interpreter, native rebuilds and strict emulator procedure. See
[ADR 0003](architecture/0003-experimental-windows-runtime.md) for process ownership
and the same-UID trust limitation.

## Reproduce without a phone

Use an explicit ARM64 emulator with 4 KB pages, such as the locally tested
`Nexus_Runtime_API36` AVD (`system-images;android-36;google_apis;arm64-v8a`). This
AVD was created for this test; the original Pixel_10 emulator uses 16 KB pages.

```sh
ADB=/path/to/adb
"$ADB" -s emulator-5556 shell getconf PAGE_SIZE
"$ADB" -s emulator-5556 install --no-streaming -r \
  app/production/build/runtime-apk/nexus-pc-runtime-debug.apk
ADB="$ADB" python3 tools/run-production-runtime-check.py emulator-5556
```

Dismiss Android’s first-use full-screen tip (“Got it”) if shown so the game is
visible in screenshots. This tip may be absent from Android’s accessibility tree.

The runtime-check script refuses non-emulator serials and requires the emulator
property. It never selects a connected phone. It starts a debug-only check through
the production host, imports the original bundled smoke PE with the real SafeCopy /
SQLite path, calls typed prepare and launch, verifies that the library is locked,
verifies the actual guest working directory and G: mapping, and injects pointer/Escape into the app-owned X server. It waits for fresh guest
markers, idle state and fixture removal. Reports use a unique nonce; old reports
cannot satisfy a new run. The script has a deadline, records logs and stops only
this test package on this explicit emulator. A fixture marker supports cleanup on
a later run if the check is interrupted. Its report and any in-activity screenshot
are saved to a new temporary directory.

Required guest markers:

```text
WINDOW_CREATED
FRAME_PAINTED
POINTER_INPUT_RECEIVED
ESCAPE_RECEIVED
CLEAN_SHUTDOWN
PROCESS_EXIT_0
```

Other checks:

```sh
bash tools/run-guest-memory-tests.sh
cd app/production
flutter analyze
flutter test
cd android
JAVA_HOME=/path/to/jdk17 ./gradlew -PnexusRuntime=true :app:testDebugUnitTest :app:lintDebug
cd ../../..
ADB=/path/to/adb bash tools/run-library-storage-check.sh emulator-5556
```

The last command requires the corresponding debug APK in the standard Flutter
output path. Native storage checks use an isolated sandbox rather than the user's
library. The added check verifies executable selection/hash and lease ownership,
including rejected imports/edits and wrong-token release.

## Evidence and limitations

On 2026-10-20, the real Windows game passed on the API 36 ARM64 emulator with
4 KB pages while the app retained target API 36. It was imported, prepared,
launched, rendered, received input, exited 0 and was removed. The normal UI has
experimental launch/stop controls and disables launch until changes are saved.

Local gates: 53 Flutter tests, static analysis, 24 JVM import-safety tests, the
memory-adapter guard tests, Android lint and native library/lease checks.
Saved evidence: [Windows run](evidence/runtime-emulator-windows.json),
[rendered window](evidence/runtime-emulator-windows.png),
[native storage/lease checks](evidence/runtime-emulator-storage.json), and
[APK SHA-256](evidence/runtime-apk.json). Repeated successful Windows runs were observed; the saved Windows report
corresponds to the final runtime APK and includes the game-directory regression.

The first 16 KB attempt failed and originally led to an unsupported-device guard.
That historical guard is now superseded by the [16 KB implementation](runtime-16k.md).
No phone testing, commercial games, Direct3D, DXVK/Turnip, audio playback, controller
validation or performance measurements were performed. Interpreter mode remains
intentional. MIDI synthesis and PulseAudio are not packaged in this profile.
