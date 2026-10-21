# Real Windows game compatibility check: Fifteen

Date: 2026-10-20 (Asia/Phnom_Penh). Experimental compatibility result, not release approval.

The original report below covers the 4 KB baseline. See the newer
[16 KB runtime validation](runtime-16k.md) for the current build and emulator results.

## Game and target

Simon Tatham's **Fifteen**, Windows x86-64 version `20260923.616da16`, from the
[author's download page](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/).
The [MIT licence](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/doc/licence.html)
permits downloading, running and redistributing it with the licence. This is the
unmodified public Windows game, not the project's synthetic smoke executable.

Executable SHA-256:
`4e576db74c72107ec3e4eea6d1d4f6ddc34c1ebe6e14281da88d9557d71a59c5`.

Target: `Nexus_Runtime_API36`, explicit `emulator-5556`, ARM64, Android API 36,
4096-byte pages, application target API 36, Box64 interpreter mode. No physical
device was selected. The ordinary runtime-free app build is unchanged.

## Reproduction

1. Build/install the [experimental APK](runtime-emulator.md).
2. Run `python3 tools/prepare-fifteen-check.py`. It prepares an ignored local ZIP
   containing the pinned executable and its licence. The rolling upstream URL may
   change; a mismatched executable is rejected rather than silently substituted.
3. Verify `adb -s emulator-5556 shell getprop ro.kernel.qemu` is `1`, then push
   `runtime/cache/compatibility/fifteen/Fifteen.zip` to `/sdcard/Download/Fifteen.zip`
   on that explicit emulator. Never use an unqualified device command.
4. In Nexus-PC, choose Library → Import ZIP and select Fifteen.zip in Downloads.
   Open its details and launch `fifteen.exe`.
5. Move a tile using an arrow key or the mouse/touchpad. Check the board changes
   and the move counter increases. Android touches operate as a relative touchpad.
6. Open the Windows Game menu and select Save. Its initial folder must be **G:**,
   the imported executable's directory. Enter `nexus.sav` and save.
7. Start a new puzzle with N, then Game → Load → `nexus.sav`. Check the original
   board and move count return. U/R should undo/redo the saved move.
8. Q quits the Windows game. Check that the details screen reports
   `Windows session stopped.`, allows relaunch, and no owned Wine processes remain.
9. Relaunch and load the same file. Press Android Back: it must open the runtime
   drawer. Scroll to Exit and select it. Check idle/cleanup again.
10. For interruption recovery, force-stop only this app on the emulator while the
    game is running, reopen Nexus-PC, relaunch Fifteen and load the saved file.
    The imported copy and save must remain intact. This tests process restart,
    not automatic restoration of an unsaved Windows session.

Windows dialogs take time to populate in interpreter mode; wait for the dialog
before typing. Android's initial cold boot can also take several minutes.

## Failures found and fixes

**Wrong working directory.** The launcher always used the runtime root as cwd.
Wine consequently opened Save at Z:, and a real save-dialog attempt led to severe
memory growth (Android reported about 2.6 GB for `fifteen.exe`) and an Android
low-memory kill. Library launches now map only the selected executable's parent
as G: and pass that directory to the child process. Relative assets and save-dialog
defaults use the game's folder. Retesting Save/Load stayed around 37 MB RSS, with
no recurrence in the tested flow. This is not a general memory/performance guarantee
or proof that browsing every Wine folder is safe.

The automated bridge regression now observes the actual smoke process's
`/proc/PID/cwd` under the exact packaged Box64 executable/UID and verifies its G:
link. A launch that falls back to the runtime root cannot pass.

**Back and intentional exit.** Modern Android Back finished the native screen and
reported exit code -1. The adapter now registers a modern Back callback to open
its drawer. Exit enters STOPPING before activity teardown, drains the owned guest
processes and releases the library lease, so a user stop is not labelled a crash.
API 31–32 retain the upstream legacy Back handling; those versions were not tested.

## Evidence and limits

See [structured result](evidence/fifteen-emulator.json),
[restored Windows board](evidence/fifteen-emulator-loaded.png), and
[save dialog in G:](evidence/fifteen-emulator-save.png).
The report distinguishes manual UI observations from automated regression checks.

This result covers one small GDI puzzle game. It does not establish Direct3D,
audio, controller, 32-bit Windows, 16 KB page, multi-user, or commercial-game
compatibility. Saves in the imported game directory are private app data and are
removed with that game. The current shared Windows prefix and same-UID trust
limitations still apply. Signing, distribution review and physical-device
acceptance remain outstanding.
