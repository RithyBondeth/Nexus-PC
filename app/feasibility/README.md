# Nexus-PC feasibility probe

Phase 0 diagnostic spike for ARM64 Android 12+ devices. Collects hardware,
RAM and ABI data through Kotlin and probes an Android Vulkan surface through
the NDK. Presents a single blue swapchain frame using the stock Vulkan driver.
Runs an original MIT-licensed Windows GDI target-click game via pinned Wine and
Box64, with a guest X server and app-owned input test.

## Run and validate

```sh
cd ../..
bash tools/prepare-runtime.sh
bash tools/build-smoke.sh
cd app/feasibility
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
flutter run
```

Runtime preparation requires curl, unzip, patch, Perl, ripgrep and zstd. The game
build requires MinGW-w64. This experimental APK uses package `com.nexuspc` and
legacy target API 28; it is not a production app or a Play release. See the
[runtime limitations and provenance](../../runtime/README.md).

See [Phase 0 evidence and acceptance gate](../../docs/phase-0-feasibility.md).
