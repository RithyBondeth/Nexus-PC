#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$task_root/tools/prepare-production-runtime.py"
cd "$task_root/app/production"
flutter pub get --enforce-lockfile
ORG_GRADLE_PROJECT_nexusRuntime=true flutter build apk --debug --target-platform android-arm64 -t lib/main.dart
python3 "$task_root/tools/check_runtime_pages.py" build/app/outputs/flutter-apk/app-debug.apk > build/runtime-page-audit.json
mkdir -p build/runtime-apk
cp build/app/outputs/flutter-apk/app-debug.apk build/runtime-apk/nexus-pc-runtime-debug.apk
echo "Experimental APK: $task_root/app/production/build/runtime-apk/nexus-pc-runtime-debug.apk"
