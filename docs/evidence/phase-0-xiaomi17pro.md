# Phase 0 device evidence - 2026-10-14

Device: Xiaomi 17 Pro, model 25098PN5AC, Android 16/API 36, SM8850,
Adreno 840, ARM64, 4096-byte pages, 11556110336 bytes usable system RAM.

Test: original MIT-licensed x86_64 Windows GDI target-click game, compiled with
MinGW-w64 14.0.0_3. Runtime: Wine 10.10, Box64 0.4.4, upstream Winlator X server,
Vortek/Gladio profile, 800x600. Windows GDI does not exercise Direct3D or Turnip.

Launch:

```sh
adb shell am start -W -n com.nexuspc/com.nexuspc.nexus_probe.MainActivity --ez runtimeProbe true --ez autoInput true
```

Observed first successful run at 14:32-14:33 Asia/Phnom_Penh:

```text
WINDOW_CREATED
FRAME_PAINTED
POINTER_INPUT_RECEIVED
FRAME_PAINTED
ESCAPE_RECEIVED
CLEAN_SHUTDOWN
PROCESS_EXIT_0
```

The final direct-launch adapter was verified again at 14:41 Asia/Phnom_Penh:

```text
14:41:20.095 NexusRuntime: X server pointer test injected
14:41:24.095 NexusRuntime: X server ESC test injected
14:41:24.123 NexusRuntime: Guest session terminated; environment stopped
PASS: guest rendered, received input, exited 0; no live guest processes.
```

Screenshot: [Windows guest rendered with Targets hit: 1](phase-0-windows.png).
Two consecutive bounded direct-launch test runs passed all required markers.
Android returned to MainActivity. After Wine's normal server linger, inspection
of the test package's UID found no live Wine/Box64/.exe processes.

Limitations: a tiny GDI executable with app-owned X server pointer/keyboard
injection; no system input permissions granted, no physical controller tested,
no Direct3D/Turnip validation and no audible audio test. The experimental APK
targets API 28 while requiring API 31; modern executable placement is unresolved
for the production runtime. Dependency provenance is in runtime/components.lock.json.
