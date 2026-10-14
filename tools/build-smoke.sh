#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$task_root/app/feasibility/android/app/src/main/assets"
x86_64-w64-mingw32-gcc -std=c11 -Wall -Wextra -Werror -O2 -static -mwindows \
    "$task_root/test/windows/smoke.c" -lgdi32 -luser32 \
    -o "$task_root/app/feasibility/android/app/src/main/assets/nexus-smoke.exe"
