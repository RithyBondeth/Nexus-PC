#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
adb_bin="${ADB:-adb}"
serial="${1:?Usage: ADB=/path/to/adb bash tools/run-shell-device-check.sh DEVICE_SERIAL}"
cd "$task_root/app/production"
"$adb_bin" -s "$serial" get-state
flutter build apk --debug --target-platform android-arm64 -t integration_test/shell_device_test.dart
"$adb_bin" -s "$serial" install --no-streaming -r build/app/outputs/flutter-apk/app-debug.apk
"$adb_bin" -s "$serial" shell am force-stop com.nexuspc.app
"$adb_bin" -s "$serial" shell am start -W -n com.nexuspc.app/.MainActivity
app_pid="$("$adb_bin" -s "$serial" shell pidof -s com.nexuspc.app | tr -d '\r')"
[[ "$app_pid" =~ ^[0-9]+$ ]] || { echo 'App did not start.' >&2; exit 1; }
vm_uri=''
for attempt in $(seq 1 30); do
    vm_uri="$("$adb_bin" -s "$serial" logcat -d --pid="$app_pid" -s flutter:I | \
        sed -n 's/.*Dart VM service is listening on \(http[^ ]*\).*/\1/p' | tail -n 1 | tr -d '\r')"
    [[ -n "$vm_uri" ]] && break
    sleep 1
done
remote_port="$(printf '%s' "$vm_uri" | sed -nE 's|^http://127\.0\.0\.1:([0-9]+)/.*$|\1|p')"
[[ "$remote_port" =~ ^[0-9]+$ ]] || { echo 'No fresh Dart VM service found.' >&2; exit 1; }
local_port="$("$adb_bin" -s "$serial" forward tcp:0 "tcp:$remote_port" | tr -d '\r')"
[[ "$local_port" =~ ^[0-9]+$ ]] || { echo 'Could not forward the debug service.' >&2; exit 1; }
trap '"$adb_bin" -s "$serial" forward --remove "tcp:$local_port" || true' EXIT
auth_path="${vm_uri#http://127.0.0.1:$remote_port/}"
export NEXUS_EVIDENCE_DIR
NEXUS_EVIDENCE_DIR="$(mktemp -d "$task_root/app/production/build/shell-device.XXXXXX")"
flutter drive -d "$serial" --no-pub --no-dds --timeout=120 \
    --driver=test_driver/shell_driver.dart --use-existing-app="http://127.0.0.1:$local_port/$auth_path"
echo "Shell device checks passed. App-only evidence: $NEXUS_EVIDENCE_DIR"
echo 'This installed the integration-test APK. Rebuild/install lib/main.dart for normal use.'
