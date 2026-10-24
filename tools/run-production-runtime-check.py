#!/usr/bin/env python3
"""Bounded opt-in runtime test. Explicit emulator only; never selects a phone."""
import json
from datetime import datetime, timezone
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid

serial = sys.argv[1] if len(sys.argv) == 2 else ''
if not serial.startswith('emulator-'):
    raise SystemExit('Usage: ADB=/path/to/adb python3 tools/run-production-runtime-check.py emulator-SERIAL')
adb = [os.environ.get('ADB', 'adb'), '-s', serial]
def call(*args, timeout=20):
    return subprocess.check_output(adb + list(args), stderr=subprocess.STDOUT, timeout=timeout)
if call('shell', 'getprop', 'ro.kernel.qemu').strip() != b'1':
    raise SystemExit('Refusing a non-emulator target.')
check_id = str(uuid.uuid4())
out = Path(tempfile.mkdtemp(prefix='nexus-runtime-check-'))
call('shell', 'am', 'force-stop', 'com.nexuspc.app')
# New task + clear task prevents Android restoring state and skipping the
# onCreate-only debug test entry. A cold install can take longer to start.
try:
    call('shell', 'am', 'start', '-W', '-f', '0x10008000', '-n', 'com.nexuspc.app/.MainActivity',
         '--ez', 'runtimeBridgeChecks', 'true', '--ez', 'runtimeAutoInput', 'true', '--es', 'runtimeCheckId', check_id, timeout=60)
except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
    if error.output:
        print(error.output.decode(errors='replace'), file=sys.stderr)
    call('shell', 'am', 'force-stop', 'com.nexuspc.app')
    raise
pid = call('shell', 'pidof', '-s', 'com.nexuspc.app').strip()
deadline = time.monotonic() + 160
try:
    while time.monotonic() < deadline:
        try:
            raw = call('exec-out', 'run-as', 'com.nexuspc.app', 'cat', 'files/runtime-bridge-checks.json')
            report = json.loads(raw)
            if report.get('checkId') == check_id:
                apk_paths = call('shell', 'pm', 'path', 'com.nexuspc.app').decode().splitlines()
                base = next(line.removeprefix('package:') for line in apk_paths if line.endswith('/base.apk'))
                report['installedApkSha256'] = call('shell', 'sha256sum', base).decode().split()[0]
                report['testedAtUtc'] = datetime.now(timezone.utc).isoformat()
                report['emulator'] = {
                    'serial': serial, 'qemu': True,
                    'fingerprint': call('shell', 'getprop', 'ro.build.fingerprint').decode().strip(),
                    'linkerPageCompat': call('shell', 'getprop', 'bionic.linker.16kb.app_compat.enabled').decode().strip(),
                    'packagePageCompatDisabled': call('shell', 'getprop', 'pm.16kb.app_compat.disabled').decode().strip(),
                }
                raw = json.dumps(report, indent=2).encode()
                (out / 'report.json').write_bytes(raw)
                print(raw.decode())
                print(f'Evidence: {out}')
                if report.get('passed') is not True:
                    raise SystemExit(1)
                break
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            pass
        try:
            if call('shell', 'pidof', '-s', 'com.nexuspc.app').strip() != pid:
                raise SystemExit(f'Runtime process restarted unexpectedly. Evidence: {out}')
        except subprocess.CalledProcessError:
            raise SystemExit(f'Runtime process terminated unexpectedly. Evidence: {out}')
        # Capture only the runtime Activity, never an unrelated foreground app.
        foreground = call('shell', 'dumpsys', 'activity', 'activities').decode(errors='replace')
        if any(('mResumedActivity' in line or 'topResumedActivity' in line) and 'com.nexuspc.app/' in line and 'runtime.RuntimeDisplayActivity' in line for line in foreground.splitlines()):
            try:
                evidence = call('exec-out', 'run-as', 'com.nexuspc.app', 'cat', 'files/r/home/xuser/.wine/drive_c/nexus-evidence.txt')
                if b'POINTER_INPUT_RECEIVED' in evidence and b'ESCAPE_RECEIVED' not in evidence:
                    (out / 'windows.png').write_bytes(call('exec-out', 'screencap', '-p'))
            except subprocess.CalledProcessError:
                pass
        time.sleep(1)
    else:
        raise SystemExit(f'Runtime test timed out. Evidence: {out}')
finally:
    (out / 'guest.log').write_bytes(call('logcat', '-d', '-s', 'NexusGuest:I', 'NexusRuntime:I', 'AndroidRuntime:E'))
    call('shell', 'am', 'force-stop', 'com.nexuspc.app')
