# Phase 0: feasibility evidence

Status: in progress. Xiaomi 17 Pro connected and ADB authorized on 2026-10-14.
The diagnostic app is a standalone spike, not the production app.

Local validation: Flutter analysis passed, both widget tests passed, the ARM64
NDK C++ syntax check passed with warnings treated as errors, and the debug ARM64
APK built successfully. These checks do not establish device/runtime compatibility.

## First device observations

ADB reports model `25098PN5AC`, Android 16 / API 36, hardware `qcom`, board
`canoe`, SoC manufacturer `QTI`, SoC model `SM8850`, and ABI `arm64-v8a`.
`/proc/meminfo` reports `MemTotal: 11285264 kB` (about 10.8 GiB usable system RAM).
The Android GPU service reports `Adreno (TM) 840`, Vulkan API version `4210983`.
These observations describe the stock driver, not Mesa Turnip compatibility.

Streamed APK installation was rejected with `INSTALL_FAILED_USER_RESTRICTED`.
Installation succeeded using `adb install --no-streaming -r`. The Flutter app
hardware report agrees with ADB, including `ramBytes: 11556110336`.

On-device native results: instance creation, Android surface creation and device
enumeration returned `VK_SUCCESS` (0). Queue 0 supports graphics and presentation.
The swapchain acquired an image, cleared it blue, and presented successfully.
A device screenshot confirmed visible blue output. Returning from the home screen
and a cold app restart were also exercised; the latter presented successfully.
This is a one-frame smoke test using the stock driver, not a sustained renderer or
validation of Mesa Turnip, DXVK, Wine, Box64, audio, input or game execution.

The activity re-creates and destroys all Vulkan resources on each size/surface
callback. The debug build accepts `--ez surfaceProbe true` on MainActivity so
tests can launch app-owned diagnostics without enabling system input injection.

```sh
adb install --no-streaming -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am force-stop com.nexuspc.nexus_probe
adb shell am start -W -n com.nexuspc.nexus_probe/.MainActivity --ez surfaceProbe true
adb logcat -d -s NexusProbe:I
```

Initial CI validation passed. Updated native rendering changes require another CI run.

## Run

Requires Flutter 3.44.8, Java 17, Android SDK, NDK 28.2.13676358,
CMake 3.22.1 and an ARM64 Android 12+ device with USB debugging enabled.

```sh
cd app/feasibility
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
flutter run
```

Run the device probe and copy its report. Open the native Vulkan surface probe
and record its GPU, Vulkan version and queue support results. Result code 0
means success. The native test creates a swapchain and presents a single blue
frame. The report explicitly separates frame presentation from Windows execution.

## Acceptance gate before merging this phase

- [x] Record actual Snapdragon hardware identifiers, RAM and ARM64 ABI.
- [x] Create Vulkan instance and Android surface on the device.
- [x] Implement and demonstrate one-frame swapchain presentation, home return and cold restart.
- [ ] Select and pin compatible runtime builds with their source/license records.
- [ ] Integrate guest display, audio and input transport. A Vulkan SurfaceView
      alone does not route Wine's desktop display into Android.
- [ ] Launch one owned DRM-free Windows test game, record architecture, runtime
      versions, launch command, logs, visible output and clean shutdown.

The later production runtime phase expands this initial single-game experiment.
Cloud profiles cannot prove that a GPU or new chipset supports a runtime build.
PRoot is a userspace filesystem translation tool, not a security boundary.
Performance tiers require measured compatibility rather than marketing names.

## References

- Android NDK samples: https://developer.android.com/ndk/samples
- Android Vulkan sample: https://github.com/android/getting-started-with-vulkan-on-android-codelab
- Existing Wine/Box64 Android integration: https://github.com/brunodev85/winlator

## Phase sequence

0. Feasibility: this gate must pass first.
1. Production project foundation and CI.
2. Flutter application shell.
3. Local library and game import.
4. Production Android device profiler.
5. Cloud profile service.
6. Server alias normalization and compatibility fallback.
7. Native runtime manager.
8. Runtime component integration and version management.
9. Typed Flutter launcher bridge and events.
10. Physical controller and touch input.
11. Offline behavior and recovery.
12. Distribution, licensing and security review.
13. Cross-device acceptance testing.
14. Controlled beta release.

For every phase: branch from develop, implement, validate acceptance evidence,
commit, open PR targeting develop, verify CI/review, merge, then start the next.
Incomplete phases remain draft PRs. Device evidence must come from real hardware.
