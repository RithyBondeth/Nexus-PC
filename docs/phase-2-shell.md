# Phase 2: application shell

Implementation: Home, Library, Device and Settings in the production Android app.
Game import/storage remain Phase 3; cloud profiles and Windows runtime integration
remain later work. The Phase 0 spike and native bridge schema are unchanged.

## Behavior and acceptance

- Bottom navigation below 600 logical pixels; labeled, scrollable navigation rail
  at wider widths. Safe areas and independently scrollable pages support portrait,
  short landscape layouts and large text.
- Home and Device share one typed device/runtime controller. Tab navigation does
  not repeat native calls. An explicit refresh updates both views.
- Profile and runtime reads fail independently, with visible retry controls.
  Reads have a ten-second UI timeout. A failed status read displays unknown,
  not a fabricated unavailable/success result. New native events cannot be
  overwritten by an older refresh response. Disposal cancels the subscription
  and ignores pending responses.
- Library is an honest empty state. Its import control is disabled and explicitly
  labeled Phase 3; no examples, persistence, imports or launches are fabricated.
- Settings offers System, Light and Dark appearance. Changes apply immediately
  and persist only in memory for this app session; cold start follows the system.
  There are no inactive runtime tuning switches.
- Device links to the existing native diagnostics route. Returning from it keeps
  the Device tab selected. Android Back from a secondary tab returns Home before
  the normal root-route exit behavior.

## Verification

All 20 automated tests pass locally. The suite covers the existing bridge/diagnostics contracts plus tab
navigation, Back, profile call counts, theme changes, independent error recovery,
keyboard activation, late native events and lifecycle disposal. Layout tests use
320, 768, 1024 and 1440 logical-pixel widths at 200% text, plus an 844×390 short
landscape viewport. Flutter accessibility checks cover labeled controls and
Android touch-target sizes, plus visible-content contrast in Light and Dark
themes. These checks are not a full TalkBack audit. Flutter analysis, the normal
ARM64 debug APK, Android lint and the unsigned production release all pass locally.

Production CI continues to verify lockfile enforcement, generator drift, Dart
formatting/analysis, tests, the ARM64 debug build, Android lint and unsigned release
compilation. Release compilation uses Flutter's release command so the SDK can
regenerate plugin registration without the debug-only integration-test plugin;
direct Gradle release compilation after a debug test build would retain a stale
registration. Formatting includes the integration test and driver directories.
Release signing and the previously documented toolchain/target advisories remain
unchanged.

The physical-device UI gate is pending until the integration driver completes on
the Xiaomi. No successful Phase 2 hardware result has been recorded yet.

## Repeat the physical-device test

Requires the Phase 1 toolchain, Python-free Flutter integration driver, an unlocked
USB-debugging-authorized ARM64 Android device, and installation approval if shown.
From the repository root:

```sh
ADB=/path/to/adb bash tools/run-shell-device-check.sh DEVICE_SERIAL
```

The script builds the SDK integration-test entry point, installs using
`--no-streaming`, cold-starts only `com.nexuspc.app`, finds that process's fresh
authenticated VM service and creates/removes its own temporary port forward.
It runs the real native profile/status APIs and exercises all four destinations,
the disabled import control, Dark appearance and Back to Home. The driver has a
120-second timeout. Evidence is saved in a new `app/production/build/shell-device.*`
directory, with an aggregate report and four screenshots of the app's Flutter
surface only (not screenshots of unrelated foreground apps).

The installed APK is the integration-test runner. Restore the normal app after
the test, from `app/production`:

```sh
flutter build apk --debug --target-platform android-arm64 -t lib/main.dart
adb -s DEVICE_SERIAL install --no-streaming -r build/app/outputs/flutter-apk/app-debug.apk
adb -s DEVICE_SERIAL shell am force-stop com.nexuspc.app
adb -s DEVICE_SERIAL shell am start -W -n com.nexuspc.app/.MainActivity
```

## Review

The frontend UI skill guided adaptive navigation, meaningful loading/error/empty
states, semantic headings/statuses, keyboard activation, accessible targets and
large-text verification. Review checks ownership of the shared controller,
out-of-order event protection, independent page scroll state, route Back behavior,
session-only preference semantics and the absence of fake runtime capabilities.
No new third-party production package is required; device-test tooling comes from
the pinned Flutter SDK's `integration_test` development dependency and its locked
transitive driver dependencies.

Merge Phase 2 into `develop` only after review, CI and the agreed hardware gate.
Next: Phase 3, local library and safe game import.
