#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
adb_bin="${ADB:-adb}"
serial="${1:?Usage: ADB=/path/to/adb bash tools/run-library-storage-check.sh DEVICE_SERIAL}"
apk="$task_root/app/production/build/app/outputs/flutter-apk/app-debug.apk"
[[ -f "$apk" ]] || { echo "Build the production debug ARM64 APK first." >&2; exit 1; }
command -v python3 >/dev/null
check_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
evidence_dir="$(mktemp -d "${TMPDIR:-/tmp}/nexus-library-check.XXXXXX")"
"$adb_bin" -s "$serial" get-state
"$adb_bin" -s "$serial" install --no-streaming -r "$apk"
"$adb_bin" -s "$serial" shell am start -W -n com.nexuspc.app/.library.LibraryCheckActivity --es checkId "$check_id"
for attempt in $(seq 1 45); do
    report="$("$adb_bin" -s "$serial" exec-out run-as com.nexuspc.app cat files/library-checks.json 2>/dev/null || true)"
    if printf '%s' "$report" | python3 -c \
        'import json, sys; r=json.load(sys.stdin); sys.exit(0 if r.get("checkId")==sys.argv[1] else 1)' \
        "$check_id" 2>/dev/null; then
        printf '%s\n' "$report" | tee "$evidence_dir/library-checks.json"
        printf '%s' "$report" | python3 -c \
            'import json, sys; r=json.load(sys.stdin); sys.exit(0 if r.get("passed") is True else 1)'
        echo "Native storage checks passed. Evidence: $evidence_dir"
        exit 0
    fi
    sleep 1
done
echo "No fresh storage report. Inspect adb logcat -s NexusLibraryChecks." >&2
exit 1
