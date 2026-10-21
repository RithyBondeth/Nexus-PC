#!/usr/bin/env python3
"""Audit ELF LOAD alignment and RELRO page isolation; inspect actual APK entries.

NDK RELRO padding need not end on 16 KB if its containing LOAD ends there and
other writable LOAD data starts after the rounded host-page boundary.
"""
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile

PAGE = 16384

def segments(data):
    if data[:6] != b'\x7fELF\x02\x01' or len(data) < 64:
        raise ValueError('Expected a little-endian ELF64 file')
    machine = struct.unpack_from('<H', data, 18)[0]
    if machine != 183:
        raise ValueError('Expected ARM64 ELF')
    offset = struct.unpack_from('<Q', data, 32)[0]
    size, count = struct.unpack_from('<HH', data, 54)
    if size < 56 or offset + size * count > len(data):
        raise ValueError('Truncated program headers')
    return [struct.unpack_from('<IIQQQQQQ', data, offset + i * size) for i in range(count)]

def audit(data):
    headers = segments(data)
    loads = [h for h in headers if h[0] == 1]
    if not loads:
        raise ValueError('No LOAD segments')
    for _, flags, off, va, _, file_size, memory_size, align in loads:
        if align < PAGE or align & (align - 1) or (off - va) % PAGE:
            raise ValueError('LOAD is not 16 KB aligned')
        if file_size > memory_size or off + file_size > len(data):
            raise ValueError('Invalid LOAD file/memory bounds')
    for h in headers:
        if h[0] != 0x6474e552 or not h[6]:
            continue
        start, end = h[3], h[3] + h[6]
        first, last = start & ~(PAGE - 1), (end + PAGE - 1) & ~(PAGE - 1)
        for load in loads:
            if not load[1] & 2:
                continue
            a, b = load[3], load[3] + load[6]
            # Writable memory outside the declared RELRO must not fall into a
            # rounded read-only host page. Separate LOAD padding is safe.
            for low, high in [(a, min(b, start)), (max(a, end), b)]:
                if low < high and max(low, first) < min(high, last):
                    raise ValueError('RELRO would protect neighbouring writable LOAD data')
    return {'loadSegments': len(loads), 'minimumLoadAlignment': min(h[7] for h in loads)}

def main():
    path = Path(sys.argv[1])
    results = []
    with zipfile.ZipFile(path) as apk:
        for name in sorted(apk.namelist()):
            if not (name.startswith('lib/arm64-v8a/') and name.endswith('.so')):
                continue
            data = apk.read(name)
            try:
                result = audit(data)
            except ValueError as error:
                raise ValueError(name + ': ' + str(error)) from error
            # Compressed native libraries are extracted by Android. Check direct
            # ZIP mapping alignment only for uncompressed libraries.
            info = apk.getinfo(name)
            if info.compress_type == zipfile.ZIP_STORED:
                with path.open('rb') as stream:
                    stream.seek(info.header_offset + 26)
                    filename, extra = struct.unpack('<HH', stream.read(4))
                if (info.header_offset + 30 + filename + extra) % PAGE:
                    raise ValueError(name + ': uncompressed ZIP data is not 16 KB aligned')
            results.append({'library': name, **result})
    if not results:
        raise ValueError('No ARM64 libraries in APK')
    print(json.dumps({'passed': True, 'pageSize': PAGE, 'apkSha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                      'nativeLibraries': len(results), 'libraries': results}, indent=2))

if __name__ == '__main__':
    main()
