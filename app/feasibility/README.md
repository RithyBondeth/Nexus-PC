# Nexus-PC feasibility probe

Phase 0 diagnostic spike for ARM64 Android 12+ devices. Collects hardware,
RAM and ABI data through Kotlin and probes an Android Vulkan surface through
the NDK. Does not render frames or launch Windows games yet.

## Run and validate

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
flutter run
```

See [Phase 0 evidence and acceptance gate](../../docs/phase-0-feasibility.md).

