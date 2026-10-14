#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_adb="${ADB:-adb}"
task_serial="${1:?Usage: bash tools/run-device-smoke.sh SERIAL}"
task_output="$(mktemp -d /tmp/nexus-device-smoke.XXXXXX)"
apk="$task_root/app/feasibility/build/app/outputs/flutter-apk/app-debug.apk"
evidence_path="files/rootfs/home/xuser-1/.wine/drive_c/nexus-evidence.txt"

"$task_adb" -s "$task_serial" install --no-streaming -r "$apk"
"$task_adb" -s "$task_serial" shell am force-stop com.nexuspc
"$task_adb" -s "$task_serial" shell run-as com.nexuspc sh -c \
    "'if [ -f $evidence_path ]; then mv $evidence_path $evidence_path.previous; fi'"
"$task_adb" -s "$task_serial" shell am start -W \
    -n com.nexuspc/com.nexuspc.nexus_probe.MainActivity --ez runtimeProbe true --ez autoInput true
screenshot=0
for ((attempt=0; attempt<110; attempt++)); do
    evidence="$("$task_adb" -s "$task_serial" shell run-as com.nexuspc cat "$evidence_path" 2>/dev/null || true)"
    if [[ "$evidence" == *POINTER_INPUT_RECEIVED* && "$screenshot" == 0 ]]; then
        "$task_adb" -s "$task_serial" shell screencap -p /data/local/tmp/nexus-smoke-test.png
        "$task_adb" -s "$task_serial" pull /data/local/tmp/nexus-smoke-test.png "$task_output/windows.png"
        screenshot=1
    fi
    if [[ "$evidence" == *PROCESS_EXIT_0* ]]; then
        for marker in WINDOW_CREATED FRAME_PAINTED POINTER_INPUT_RECEIVED ESCAPE_RECEIVED CLEAN_SHUTDOWN; do
            [[ "$evidence" == *"$marker"* ]] || { echo "Missing marker: $marker" >&2; exit 1; }
        done
        [[ "$evidence" != *TIMEOUT_NO_INPUT* ]] || { echo "Game timed out" >&2; exit 1; }
        echo "$evidence"
        # Wine's daemon may linger briefly after the final client exits. Inspect
        # only this dedicated test package's UID; never terminate other app data.
        task_uid="$("$task_adb" -s "$task_serial" shell run-as com.nexuspc id -u | tr -d '\r')"
        task_username="u0_a$((task_uid - 10000))"
        for ((drain=0; drain<20; drain++)); do
            if ! "$task_adb" -s "$task_serial" shell ps -A | awk -v owner="$task_username" \
                '$1 == owner && $0 ~ /(wineserver|wine|box64|\.exe)/ && $0 !~ / Z / { found=1 } END { exit !found }'; then
                echo "PASS: guest rendered, received input, exited 0; no live guest processes."
                echo "Screenshot: $task_output/windows.png"
                exit 0
            fi
            sleep 1
        done
        echo "Guest processes did not drain" >&2; exit 1
    fi
    sleep 1
done
echo "Windows smoke test timed out" >&2
exit 1
