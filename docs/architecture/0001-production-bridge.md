# ADR 0001: Typed production bridge and separate modern-target app

Status: accepted for Phase 1, 2026-10-14.

## Context

Phase 0 demonstrated a minimal Wine/Box64 Windows GDI game using legacy target
API 28. It must remain reproducible without constraining the production app to
that target. Flutter owns the product UI; Android owns process control and device
APIs; C++ owns native GPU queries and later rendering/runtime integration.

## Decision

Create `app/production` with package `com.nexuspc.app`, minimum API 31 and target
API 36. Leave `app/feasibility` and its pinned runtime independent.

Use Pigeon 29.0.8 to generate typed Dart/Kotlin channels from one schema. Kotlin
uses an owned serial executor for potentially blocking host work and main-thread
callbacks. Flutter uses one platform adapter per engine with cancellable event
subscriptions. JNI exposes a small C++ Vulkan query; no game-rendering data passes
through these channels. Logs are bounded to 128 native entries and 20 UI entries.

Prepare and launch accept a game identifier and relative executable path. They
validate the shape now, but explicitly fail with `runtime_unavailable` until an
engine is integrated. The future importer/runtime must independently enforce
canonical containment, symlink policy, archive safety and executable selection.
Current path validation is not a filesystem sandbox.

Modern Android targets cannot execute code from writable app home directories.
Android recommends embedding executable code in the APK; see
[Android 10 execution restrictions](https://developer.android.com/about/versions/10/behavior-changes-10#execute-permission).
Package a tiny ARM64 helper as an extracted native library and launch only that
fixed path in `nativeLibraryDir`. Enable legacy JNI packaging/extraction for this
placement test. The helper uses direct write/exit syscalls with no libc dependency.

## Alternatives

- Raw MethodChannels: fewer generated files, but duplicated stringly-typed
  protocol validation and less dependable Dart/Kotlin evolution.
- Direct Dart FFI for everything: suitable for future hot-path native APIs, but
  does not replace Android activity/process APIs and lifecycle ownership.
- Extend the Phase 0 spike: shares legacy targeting and experimental runtime
  assumptions with the product, defeating independent modern-target validation.

## Consequences and limits

CI regenerates bindings and rejects drift. Both generated sides must be upgraded
together. Schema/generated files add mechanical volume to the initial scaffold.
Device integration checks complement Flutter codec/widget tests; neither replaces
cross-device testing. Release signing is deferred to the distribution phase.

A successful helper proves only fixed-path native execution at target API 36 on
the measured phone. It does not prove glibc loading, Box64 JIT, Wine, downloadable
runtime updates, Mesa Turnip, DXVK or commercial-game compatibility. Those remain
explicit acceptance gates for runtime phases 7–8. The Phase 0 app remains available
to compare behavior without presenting it as production support.
