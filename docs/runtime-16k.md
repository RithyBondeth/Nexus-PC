# Experimental Windows runtime: 4 KB and 16 KB hosts

The experimental ARM64 runtime now builds for both host page sizes. This remains a
foreground GDI/interpreter profile, not a general Windows compatibility or release
claim. The primary Android user restriction still applies.

The final debug APK was validated on 2026-10-21 (Asia/Phnom_Penh): both Windows
smoke runs passed, and Fifteen passed moves, save/load, undo/redo, normal quit,
relaunch/load and Android Back/Exit on the 16 KB emulator. All 444 packaged ARM64
libraries passed the ELF/ZIP audit. The final Android run passed 24 unit tests and
lint; seven auditor tests and the guest-memory guard checks passed. Flutter
analysis and 53 tests passed earlier in this change, with no subsequent Dart edits.
The reports below bind the runs to the final APK SHA-256. Temporary emulator
compatibility properties were restored after testing. No phone was connected.

## Implementation

The old Box64 0.4.4 bundle passed 4 KB Windows protection requests directly to the
host and failed with Wine image-protection errors on a 16 KB kernel. The updated
interpreter is built from Box64 source commit
`ae3412c1bf9179b341996e18b656f11fd145f01e` (0.4.5 development snapshot). Its upstream
large-page code tracks guest subpage protections separately and preserves adjacent
host-page permissions. The existing narrowly scoped PE/EXEC adapter is retained.

The build uses checksum-pinned source/toolchain archives in
[`production-16k.lock.json`](../runtime/production-16k.lock.json). Zig 0.14.1
cross-compiles the glibc interpreter; NDK 28.2 rebuilds the Android display/driver
libraries with 16 KB LOAD alignment and RELRO isolation. The ION allocation helper
uses the actual host page size. Missing upstream C header includes are corrected
without suppressing compiler errors. Zstandard JNI 1.5.7-6 replaces the older
experimental dependency whose RELRO shared a host page with writable data; this
version also remains compatible with the current compile SDK.

MIDI synthesis and PulseAudio binaries/dependencies are excluded from this
experimental profile. MIDI allocation reports unavailable; selecting PulseAudio
fails explicitly. The existing Java AudioTrack/ALSA path remains, but sound has
not been validated. The Phase 0 feasibility bundle is preserved separately.

Wine 10.10 also places its syscall dispatcher at `0x7ffe1000`. Remapping the
4 KB shared user-data view on a 16 KB kernel replaces that pointer, causing
some GDI calls to jump to zero. The production build relocates the dispatcher to
`0x7ffe4000`: both the Unix initialization/instrumentation references and the
244 NTDLL / 463 Win32U x64 syscall stubs use the same address. The shared data
remains a real shared mapping; its clocks are not replaced by a stale private copy.
[`wine_dispatch.py`](../tools/wine_dispatch.py) checks the complete input SHA-256
and exact instructions/counts before adapting these three pinned Wine files.
It never edits imported game executables. This is a build-time binary adaptation,
not a source-built Wine release. Updating Wine requires reviewing this adaptation.
The APK includes a checksum map for these guest files; preparation upgrades them
before creating the new prefix. The new files are installed with atomic replacement.

Wine esync is disabled on 16 KB hosts. This bundle uses 4 KB shared-file offsets
for esync objects, which can abort wineserver when it allocates a second page.
The regular Wine server synchronization path is used instead; 4 KB hosts retain
the original setting. This is an experimental interpreter profile with no game
performance guarantee.

Legacy Wine prefixes are preserved. The adapter selects a new, versioned prefix
per host page size (`host-pages-v2-4096` / `host-pages-v2-16384`) rather than
reusing prefix state created by the old interpreter. Imported game folders and
their saves are unchanged. C: saves in a legacy prefix are retained there; automatic
transfer into the new C: is not implemented.

The runtime manifest disables Android page-size backcompat for this package.
The acceptance run additionally forces the emulator linker into `fatal` mode and
turns package backcompat off. A failure cannot be accepted just by dismissing the
Android compatibility warning.

## Build and verification

```sh
JAVA_HOME=/path/to/jdk17 bash tools/build-production-runtime.sh
python3 tools/test_runtime_pages.py
python3 tools/check_runtime_pages.py \
  app/production/build/runtime-apk/nexus-pc-runtime-debug.apk
```

The first build downloads the pinned Box64 source and host Zig compiler. Native
compilation requires the Android SDK's CMake 3.22.1/NDK 28.2 toolchain in addition
to the [existing build requirements](runtime-emulator.md). Later builds reuse
verified downloads and native objects. No runtime downloads occur on Android.
The build audits every packaged ARM64 ELF before copying the downloadable APK.
The audit checks LOAD offset/address congruence, minimum alignment, RELRO isolation
and uncompressed ZIP entry placement. NDK padding in a separate LOAD is allowed;
real writable data in a rounded RELRO page is rejected.

Use explicit emulator serials only. Confirm both the emulator property and actual
page size before installing or running checks:

```sh
ADB=/path/to/adb
"$ADB" -s emulator-5554 shell getprop ro.kernel.qemu
"$ADB" -s emulator-5554 shell getconf PAGE_SIZE
"$ADB" -s emulator-5554 install --no-streaming -r \
  app/production/build/runtime-apk/nexus-pc-runtime-debug.apk
ADB="$ADB" python3 tools/run-production-runtime-check.py emulator-5554
```

The locally used `Pixel_10` ARM64 emulator has API 37 and 16384-byte pages.
`Nexus_Runtime_API36` (`emulator-5556`) has API 36 and 4096-byte pages.
The application continues to target API 36 with minimum API 31.

For a strict API 37 acceptance run, save the existing values of the following
properties, set them only on the emulator, force-stop/relaunch this package, and
restore the saved values after testing:

```sh
"$ADB" -s emulator-5554 shell setprop bionic.linker.16kb.app_compat.enabled fatal
"$ADB" -s emulator-5554 shell setprop pm.16kb.app_compat.disabled true
```

The original Windows smoke game now tests a 4 KB read-only subpage inside a 64 KB
allocation, verifies `VirtualQuery` reports the requested guest protection, writes
both neighbours, restores the subpage and writes it again. The required marker is
`GUEST_SUBPAGE_PROTECTION_PASSED`. Every paint also creates, selects and restores
a font; `FONT_SELECTED` is required in addition to rendering/input/clean-exit and
library-lease checks. A fresh runtime prefix also exercises native Zstandard
extraction instead of relying only on an existing installation.

For a real game, follow the [Fifteen procedure](fifteen-emulator.md): system ZIP
import, launch, move, save/load, quit/relaunch and Back/Exit. The original 4 KB
results remain historical evidence; the new report records the final APK on 16 KB pages.

## Evidence

Validation results and artifact hashes are recorded with the final APK. See the
[16 KB Windows regression](evidence/runtime-emulator-16k.json),
[4 KB regression](evidence/runtime-emulator-4k.json),
[packaged ELF audit](evidence/runtime-page-audit.json), and
[16 KB Fifteen result](evidence/fifteen-emulator-16k.json).
The earlier [16 KB guard result](evidence/runtime-emulator-16k-guard.json) documents
the old restriction and is superseded by this implementation.

Only the tested puzzle and original GDI game are covered. JIT, 32-bit Windows,
Direct3D, sound, controllers, additional host versions, secondary Android users,
physical devices, signing/distribution and final release review remain outside
this acceptance result. Runtime content still runs with the app's UID and shared
Windows prefix; run trusted games only.

Sources: [Android 16 KB guidance](https://developer.android.com/guide/practices/page-sizes),
[pinned Box64 guest memory implementation](https://github.com/ptitSeb/box64/blob/ae3412c1bf9179b341996e18b656f11fd145f01e/src/wrapped/wrappedlibc.c),
[Zstandard JNI](https://github.com/luben/zstd-jni).
