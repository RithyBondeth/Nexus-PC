#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
cache="$task_root/runtime/cache"
vendor="$task_root/runtime/vendor"
mkdir -p "$cache" "$vendor/binary"

fetch() {
    local filename="$1" checksum="$2" url="$3"
    if [[ ! -f "$cache/$filename" ]]; then
        curl --fail --location --retry 2 --output "$cache/$filename" "$url"
    fi
    local actual
    actual="$(shasum -a 256 "$cache/$filename" | cut -d ' ' -f 1)"
    [[ "$actual" == "$checksum" ]] || { echo "Checksum mismatch: $filename" >&2; exit 1; }
}
fetch source.zip 9b0a026546d87e13a5622d05c65b513d651226a53f4add822f26909411703ba4 \
    https://codeload.github.com/brunodev85/winlator-app/zip/3981d86efa4f333b2a34a7da8b6521476cd8c8b9
fetch winlator.apk ea5c81bf0e5b90a6b9ccb8007121ab6738c8646a5a60b341ce0ac2b33f1d100a \
    https://github.com/brunodev85/winlator/releases/download/v11.2.0/Winlator_11.2.apk
if [[ ! -f "$vendor/.prepared-v5" ]]; then
    unzip -qo "$cache/source.zip" -d "$vendor"
    unzip -qo "$cache/winlator.apk" 'assets/*' 'lib/arm64-v8a/*' -d "$vendor/binary"
    patch --batch -d "$vendor/winlator-app-3981d86efa4f333b2a34a7da8b6521476cd8c8b9" -p1 < "$task_root/runtime/host.patch"
    java_dir="$vendor/winlator-app-3981d86efa4f333b2a34a7da8b6521476cd8c8b9/app/src/main/java"
    # Deterministic migration from an application module to library resource IDs.
    while IFS= read -r file; do
        perl -0pi -e 's/switch\s*\((itemId|item\.getItemId\(\)|menuItem\.getItemId\(\)|v\.getId\(\))\)/switch (com.winlator.core.NexusResourceNames.name($1))/g; s/case R\.id\.(\w+)\s*:/case "$1":/g' "$file"
    done < <(rg -l 'case R\.id\.' "$java_dir")
    while IFS= read -r file; do
        perl -pi -e 's/(?<![\w.])R\.attr\.colorAccent/androidx.appcompat.R.attr.colorAccent/g; s/(?<![\w.])R\.attr\.colorError/com.google.android.material.R.attr.colorError/g; s/(?<![\w.])R\.attr\.colorPrimarySurface/com.google.android.material.R.attr.colorPrimarySurface/g' "$file"
    done < <(rg -l 'R\.attr\.(colorAccent|colorError|colorPrimarySurface)' "$java_dir")
    # Upstream glibc/Wine files contain fixed package paths. The replacement has
    # exactly the same byte length; the extra slash is POSIX-equivalent, preserving
    # ELF offsets. Use a distinct package rather than touching com.winlator data.
    for archive in rootfs.tzst rootfs_patches.tzst container_pattern.tzst box64/box64-0.4.4.tzst; do
        extract_dir="$(mktemp -d "$cache/adapt.XXXXXX")"
        zstd -dc "$vendor/binary/assets/$archive" | tar -xf - -C "$extract_dir"
        find "$extract_dir" -type f -print0 | xargs -0 perl -pi -e 's{/data/data/com.winlator/}{/data/data/com.nexuspc//}g'
        tar -cf - -C "$extract_dir" . | zstd -q -f -o "$vendor/binary/assets/$archive"
    done
    touch "$vendor/.prepared-v5"
fi
echo "Pinned runtime prepared. Build the smoke game with tools/build-smoke.sh."
