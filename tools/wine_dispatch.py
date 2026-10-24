"""Relocate the pinned Wine x64 dispatcher out of its shared-data host page.

Only these three checksum-pinned Wine files are eligible. This is a build-time
adaptation of Wine, never a patch to an imported Windows executable.
"""
import hashlib

INPUTS = {
    'opt/wine/lib/wine/x86_64-unix/ntdll.so': ('f115d281588a7953f50aa7d3be5c3e01870fc3891cd25ff6ef5ed14b5b89bf99', None),
    'opt/wine/lib/wine/x86_64-windows/ntdll.dll': ('2cd33cd334038db50669e374c56b96b34eee9cbda9fb436fdcb314e2f7ad849e', 244),
    'opt/wine/lib/wine/x86_64-windows/win32u.dll': ('fdf0431ec46be0ec7fed54f1c6294477b36d3e64ae791de904a1f6165dcb40ed', 463),
}


def relocate(path, data):
    if path not in INPUTS:
        return data
    expected, stubs = INPUTS[path]
    if hashlib.sha256(data).hexdigest() != expected:
        raise ValueError('Unrecognized Wine dispatcher input: ' + path)
    if stubs is not None:
        old = bytes.fromhex('ff14250010fe7f')  # call *0x7ffe1000
        new = bytes.fromhex('ff14250040fe7f')  # call *0x7ffe4000
        if data.count(old) != stubs:
            raise ValueError('Unexpected Wine syscall stub count: ' + path)
        return data.replace(old, new)
    data = bytearray(data)
    # ELF LOAD offsets equal virtual addresses here. In signal_init_process,
    # move both the anonymous mapping and dispatcher store to USD + 0x4000.
    # set_process_instrumentation_callback must use the same relocated slot.
    for offset, old, new in [
        (0x47367, '498dbd00100000', '498dbd00400000'),
        (0x4738d, '49898500100000', '49898500400000'),
        (0x44812, '4881c500100000', '4881c500400000'),
    ]:
        old, new = bytes.fromhex(old), bytes.fromhex(new)
        if data[offset:offset + len(old)] != old:
            raise ValueError('Unexpected Wine dispatcher instruction')
        data[offset:offset + len(old)] = new
    return bytes(data)
