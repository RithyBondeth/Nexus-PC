#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_dir="$(mktemp -d "${TMPDIR:-/tmp}/nexus-memory-tests.XXXXXX")"
trap 'rm -rf "$task_dir"' EXIT
"${CC:-cc}" -std=c11 -Wall -Wextra -Werror -DNEXUS_GUEST_MEMORY_TEST \
  "$task_root/runtime/production-compat/guest_memory.c" \
  "$task_root/runtime/production-compat/guest_memory_test.c" -o "$task_dir/check"
"$task_dir/check"
