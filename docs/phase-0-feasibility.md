# Phase 0: feasibility evidence

Status: in progress. No physical Android device connected on 2026-10-14.
The diagnostic app is a standalone spike, not the production app.

Local validation: Flutter analysis passed, both widget tests passed, the ARM64
NDK C++ syntax check passed with warnings treated as errors, and the debug ARM64
APK built successfully. These checks do not establish device/runtime compatibility.

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
means success. This creates an Android Vulkan surface; it does not yet create a
swapchain or render frames. It must not be reported as a rendering test.

## Acceptance gate before merging this phase

- [ ] Record actual Snapdragon hardware identifiers, RAM and ARM64 ABI.
- [ ] Create Vulkan instance and Android surface on the device.
- [ ] Implement and demonstrate swapchain frame presentation and lifecycle recovery.
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
