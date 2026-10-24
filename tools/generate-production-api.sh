#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$task_root/app/production"
dart run pigeon --input pigeons/nexus_api.dart
dart format lib/platform/nexus_api.g.dart
# Pigeon currently emits trailing spaces in Kotlin callback closures.
perl -pi -e 's/[ \t]+$//' android/app/src/main/kotlin/com/nexuspc/app/NexusApi.g.kt
