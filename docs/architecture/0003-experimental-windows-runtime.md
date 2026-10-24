# ADR 0003: opt-in modern-target Windows runtime

Status: experimental; emulator proof, not release approval.
Date: 2026-10-20 (Asia/Phnom_Penh).

## Scope

The owner requested runtime integration and emulator testing without connecting a
phone. This explicitly brings forward runtime work from the original phase order;
it does not declare the intervening phases or physical acceptance complete.
The ordinary production build remains independent of Wine/Box64. A Gradle property,
`nexusRuntime=true`, enables the pinned runtime module and adapter sources in the
same `com.nexuspc.app` package. Target API remains 36, minimum API 31, ARM64 only.

The experimental adapter accepts the primary Android user on 4 KB or 16 KB host
pages. The initial 16 KB failure was resolved with a pinned source-built Box64
interpreter, rebuilt Android native libraries and relocation of Wine’s syscall
dispatcher outside the shared-data host page; see the
[16 KB implementation](../runtime-16k.md). Other page sizes/users are rejected.
Box64 has no JIT in this build. Direct3D, graphics-driver compatibility, sound and
commercial games remain unverified. MIDI synthesis/PulseAudio are excluded from
this experimental profile.

## Placement and reproducibility

`tools/prepare-production-runtime.py` starts from the checksum-pinned Winlator
11.2 bundle and source recorded in `runtime/components.lock.json`. It creates a
separate ignored production vendor tree, preserving the Phase 0 inputs. Native
ARM64 ELF files are packaged as APK native libraries. A generated path/hash map
connects rootfs entries to those installed files through symlinks; every mapped
binary is hashed before launch. The Box64 ELF interpreter is relocated with
patchelf. Rootfs-native symlinks are refreshed after APK installation paths change.

The production root is `files/r`. Its shorter path allows equal-length replacement
of the embedded `/data/data/com.winlator/files/rootfs` prefix with
`/data/data/com.nexuspc.app/files/r//`, preserving binary offsets. The primary-user
restriction makes the embedded Android path assumption explicit. Data/guest assets
are repacked; ARM64 code executes from the installed APK location. No runtime
update/download mechanism or independently rebuilt Wine/glibc claim is introduced.
Existing upstream source/license records remain relevant; distribution review is
still pending.

Android's modern executable-placement restriction is documented in
[Android 10 behavior changes](https://developer.android.com/about/versions/10/behavior-changes-10#execute-permission).
The implementation keeps the modern target rather than relying on legacy targeting.

## Guest memory adaptation

Wine requests executable protection for x86 PE mappings, although the ARM64 kernel
never executes those PE bytes. On both tested emulator page sizes, the original
modern-target path failed while protecting app-data PE sections. The bundled
`libnexus_guest_memory.so` is preloaded only into the glibc guest process.

It first attempts the unchanged `mprotect`. Only an EXEC request denied with
EACCES/EPERM is eligible for adaptation. The adapter verifies complete mapping
coverage in `/proc/self/maps`, limits files to this package's runtime or imported
library root, and validates the MZ/PE signature and x86/x86-64 machine field. It
then retries with native EXEC removed; Box64 retains guest execution semantics.
Native ARM64 files, foreign paths, malformed headers, unmapped gaps, overflow,
and other kernel errors are not adapted. Native executable permission is not
added by this adapter; no SELinux policy, root access, or device setting changes.

Host-side tests cover these guards through the public protection operation with
controlled kernel results. The end-to-end Windows test covers actual Wine mappings.
This is an experimental compatibility adapter, not a security boundary for games.

## Ownership and launcher boundary

The optional `RuntimeBackend` is loaded by the existing typed host bridge. Native
state survives Flutter engine replacement; closing an engine detaches its events.
Prepare/launch acquire a library lease on the existing serial worker. The selected
saved executable must belong to an owned import, be x86-64, and match its recorded
SHA-256. Import, reads, edits and removal are rejected while leased. UI launch is
disabled for unsaved changes. Commands use argument splitting with escaped spaces,
not a shell or game-title interpolation.

Library launches map the selected executable directory as G: and use that directory
as the child working directory. This preserves relative assets and game-local save
paths. Android Back opens the runtime drawer; intentional Exit enters STOPPING
before cleanup.

Preparing provisions one local prefix. Launch opens the app's foreground X-server
activity. RUNNING means a process was requested; it does not claim a rendered frame
or compatibility. A failed exit becomes FAILED. Stop/teardown terminates only this
UID's processes whose executable is the exact packaged Box64 path, waits for them
to drain, then releases the lease. Cleanup failure retains the lease and exposes a
retryable stop state. Session generation checks prevent obsolete cleanup from
releasing a newer session. The adapter does not enable upstream background
protection or notification posting, and removes the unused foreground service.

Windows content runs with this application's UID. It can access Nexus-PC app data;
the lease protects cooperating app operations, not against a hostile game. The UI
states this trust requirement. No per-game OS sandbox, background-service promise,
resumable session or general compatibility claim is made.

## Validation and outstanding work

See [emulator procedure and evidence](../runtime-emulator.md). A Windows GDI game
built from the project's original MIT source ran through the real import store
and typed prepare/launch/stop methods on an API 36, 4 KB ARM64 emulator. It rendered,
received pointer/Escape input and exited 0. No phone was connected or targeted.

The third-party MIT Windows game Fifteen also passed the scoped
[compatibility procedure](../fifteen-emulator.md), including save/load and relaunch.

Physical devices, broader memory/protection workloads, additional games, graphics
and sound paths, cross-device performance, process interruption/prefix recovery,
component upgrades, supply-chain/distribution review, signing and final CI/review
remain separate acceptance work. This decision does not authorize a public release.
