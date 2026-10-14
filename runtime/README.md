# Phase 0 runtime dependency

The experiment integrates pinned Winlator Java display/input code as an Android
library. Native libraries and runtime archives come from the checksum-verified
official Winlator 11.2 APK (version code 33). Dependencies are generated under
`vendor/`, excluded from Git, and prepared by `bash tools/prepare-runtime.sh`.
The Windows game is built from the original MIT-licensed `test/windows/smoke.c`
using `bash tools/build-smoke.sh` (requires MinGW-w64). Preparation also requires
curl, unzip, patch, Perl, ripgrep and zstd. Run `tools/run-device-smoke.sh SERIAL`
with `ADB` set to your adb binary to verify guest evidence and process shutdown.

Source, binary versions and checksums are recorded in `components.lock.json`.
The library retains the upstream LGPL-2.1 license in its downloaded source.
Original source: https://github.com/brunodev85/winlator-app/tree/3981d86efa4f333b2a34a7da8b6521476cd8c8b9

`host.patch` changes guest-session exit to return to the host rather than restart
the entire application and directly launches the fixed smoke executable through
Wine, avoiding the upstream Explorer/helper path that hung on a repeat run.
The preparation script also mechanically migrates menu
switches to resource names because library resource IDs are not Java constants;
`compat/` supplies the resource-name lookup. It qualifies dependency-owned theme
attributes. It adapts fixed upstream filesystem paths from `/data/data/com.winlator/`
to the equal-length `/data/data/com.nexuspc//`. The extra slash resolves to the same
directory and preserves ELF offsets. No files belonging to another Android app are
changed. These adaptations retain the guest CPU and graphics algorithms.

This proof uses the upstream glibc runtime, without PRoot. It targets Android API
28 to match upstream execution of binaries from app data, while requiring API 31
devices. It is an engineering experiment, not a production or Play release.
The production architecture must resolve modern Android executable-placement
restrictions before adopting this runtime. No device security settings are
changed by the launcher.

The selected smoke game uses Windows GDI. It does not prove Direct3D, Vulkan in
the Windows guest, Turnip, DXVK, sound playback, or compatibility with commercial
games. Turnip 26.2.0 is bundled but is not selected for this initial GDI proof.

Redistribution/source records retained for the upstream components:

- Winlator Android source/license: https://github.com/brunodev85/winlator-app
- Wine source/license: https://gitlab.winehq.org/wine/wine
- Box64 source/license: https://github.com/ptitSeb/box64
- Mesa source/license: https://gitlab.freedesktop.org/mesa/mesa
- DXVK source/license: https://github.com/doitsujin/dxvk
- Vortek source/license: https://github.com/brunodev85/vortek
- Gladio source/license: https://github.com/brunodev85/gladio

This is provenance for a locally tested bundle, not an assertion that every
bundled binary has been independently rebuilt or that distribution review is
complete. The planned distribution review remains a separate phase.
