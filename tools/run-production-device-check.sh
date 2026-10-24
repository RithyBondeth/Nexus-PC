#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
adb_bin="${ADB:-adb}"
serial="${1:?Usage: ADB=/path/to/adb bash tools/run-production-device-check.sh DEVICE_SERIAL}"
apk="$task_root/app/production/build/app/outputs/flutter-apk/app-debug.apk"
[[ -f "$apk" ]] || { echo "Build the production debug ARM64 APK first." >&2; exit 1; }
command -v python3 >/dev/null
check_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
evidence_dir="$(mktemp -d "${TMPDIR:-/tmp}/nexus-phase1.XXXXXX")"
"$adb_bin" -s "$serial" get-state
"$adb_bin" -s "$serial" install --no-streaming -r "$apk"
"$adb_bin" -s "$serial" shell am force-stop com.nexuspc.app
"$adb_bin" -s "$serial" shell am start -W -n com.nexuspc.app/.MainActivity \
    --ez foundationChecks true --es foundationCheckId "$check_id"
# Match this run's nonce; a stale success report cannot satisfy the gate.
for attempt in $(seq 1 30); do
    report="$("$adb_bin" -s "$serial" exec-out run-as com.nexuspc.app cat files/foundation-checks.json 2>/dev/null || true)"
    if printf '%s' "$report" | python3 -c \
        'import json, sys; r=json.load(sys.stdin); sys.exit(0 if r.get("checkId")==sys.argv[1] else 1)' \
        "$check_id" 2>/dev/null; then
        printf '%s\n' "$report" | tee "$evidence_dir/foundation-checks.json"
        printf '%s' "$report" | python3 -c \
            'import json, sys; r=json.load(sys.stdin); sys.exit(0 if r.get("passed") is True else 1)'
        "$adb_bin" -s "$serial" logcat -d -s NexusFoundation:I > "$evidence_dir/native.log"
        # Never deliberately capture another app if the user switches away.
        if "$adb_bin" -s "$serial" shell dumpsys activity activities | \
            grep -Eq 'mResumedActivity:.*com\.nexuspc\.app/'; then
            # Multi-display warnings can corrupt exec-out PNG stdout.
            remote_screen="/sdcard/nexus-foundation-$check_id.png"
            "$adb_bin" -s "$serial" shell screencap -p "$remote_screen"
            "$adb_bin" -s "$serial" pull "$remote_screen" "$evidence_dir/screen.png"
            "$adb_bin" -s "$serial" shell rm "$remote_screen"
        else
            echo "UI screenshot skipped: Nexus-PC is no longer foreground."
        fi
        echo "Phase 1 native checks passed. Evidence: $evidence_dir"
        exit 0
    fi
    sleep 1
done
echo "No fresh native report after 30 checks. Inspect adb logcat -s NexusFoundation." >&2
exit 1
