#!/usr/bin/env python3
"""Build an opt-in, APK-packaged native runtime from the pinned Phase 0 bundle.
Never edits the feasibility vendor tree. Requires Python 3, zstd and patchelf.
"""
import hashlib
import json
import platform
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import zipfile
from wine_dispatch import INPUTS as WINE_DISPATCH_INPUTS, relocate

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'runtime/vendor/production'
APK = ROOT / 'runtime/cache/winlator.apk'
EXPECTED = 'ea5c81bf0e5b90a6b9ccb8007121ab6738c8646a5a60b341ce0ac2b33f1d100a'
subprocess.run(['bash', str(ROOT / 'tools/prepare-runtime.sh')], check=True)
assert hashlib.sha256(APK.read_bytes()).hexdigest() == EXPECTED
if OUT.exists():
    shutil.rmtree(OUT)
OUT.mkdir()
source = ROOT / 'runtime/vendor/winlator-app-3981d86efa4f333b2a34a7da8b6521476cd8c8b9'
shutil.copytree(source, OUT / 'source')
with zipfile.ZipFile(APK) as bundle:
    for name in bundle.namelist():
        if name.startswith(('assets/', 'lib/arm64-v8a/')) and not name.endswith('/'):
            target = OUT / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(bundle.read(name))
# The Java adapter uses the packaged Box64 rather than exec'ing app-writable code.
launcher = OUT / 'source/app/src/main/java/com/winlator/xenvironment/components/GuestProgramLauncherComponent.java'
s = launcher.read_text().replace('String command = rootDir+"/usr/local/bin/box64 "+guestExecutable;',
    'String command = environment.getContext().getApplicationInfo().nativeLibraryDir+"/libnexus_box64.so "+guestExecutable;')
s = s.replace('String command = environment.getContext()', 'com.winlator.core.NexusPackagedRuntime.install(environment.getContext());\n        String command = environment.getContext()')
s = s.replace('private String guestExecutable;', 'private String guestExecutable;\n    private File workingDirectory;\n    public void setWorkingDirectory(File directory) { workingDirectory = directory; }')
s = s.replace('ProcessHelper.exec(command, envVars, rootDir,', 'ProcessHelper.exec(command, envVars, workingDirectory != null ? workingDirectory : rootDir,')
s = s.replace('if (this.envVars != null) envVars.putAll(this.envVars);',
    'if (this.envVars != null) envVars.putAll(this.envVars);\n        envVars.put("LD_PRELOAD", environment.getContext().getApplicationInfo().nativeLibraryDir+"/libnexus_guest_memory.so");')
launcher.write_text(s)
process = OUT / 'source/app/src/main/java/com/winlator/core/ProcessHelper.java'
p = process.read_text().replace('catch (Exception e) {}',
    'catch (Exception e) { android.util.Log.e("NexusRuntime", "Guest spawn failed", e); if (terminationCallback != null) terminationCallback.call(-1); }', 1)
for begin, end in [('private static void createDebugThread(', 'private static void createWaitForThread('),
                   ('private static void createWaitForThread(', 'public static void removeAllDebugCallbacks(')]:
    start, stop = p.index(begin), p.index(end)
    block = p[start:stop].replace('Executors.newSingleThreadExecutor().execute(() -> {', 'new Thread(() -> {', 1)
    last = block.rfind('});')
    block = block[:last] + '}, "NexusGuestIO").start();' + block[last+3:]
    p = p[:start] + block + p[stop:]
process.write_text(p)
# Strip optional upstream foreground-session service in the experimental adapter;
# a visible activity owns execution. No background-runtime claim is made.
display = OUT / 'source/app/src/main/java/com/winlator/XServerDisplayActivity.java'
s = display.read_text()
s = s.replace('ForegroundService.startSession(this);', '').replace('ForegroundService.stopSession(this);', '')
# Library games need a DOS drive and their executable directory as cwd, so
# relative assets resolve and file dialogs open in the game instead of Z:.
s = s.replace('WineUtils.createDosdevicesSymlinks(container, true);',
    'if (getIntent().getBooleanExtra("librarySession", false)) container.setDrives("G:" + new File(getIntent().getStringExtra("exec_path")).getParent());\n        WineUtils.createDosdevicesSymlinks(container, true);')
s = s.replace('guestProgramLauncherComponent.setGuestExecutable(guestExecutable);',
    'guestProgramLauncherComponent.setGuestExecutable(guestExecutable);\n            if (getIntent().getBooleanExtra("librarySession", false)) guestProgramLauncherComponent.setWorkingDirectory(new File(getIntent().getStringExtra("exec_path")).getParentFile());')

s = s.replace('guestProgramLauncherComponent.setTerminationCallback((status) -> exit());',
    'guestProgramLauncherComponent.setTerminationCallback((status) -> { getIntent().putExtra("nexus_exit_code", status); exit(); });')
s = s.replace('guestExecutable = "wine " + getIntent().getStringExtra("exec_path");',
    r'guestExecutable = "wine " + getIntent().getStringExtra("exec_path").replace(" ", "\\ ");')
s = s.replace('String guestExecutable = "wine explorer /desktop="',
    'String guestExecutable = getIntent().getBooleanExtra("nexus_smoke", false) ? "" : "wine explorer /desktop="')
# Convert startup failures into a failed session rather than a background-thread crash.
s = s.replace('            if (!isGenerateWineprefix()) {\n                setupWineSystemFiles();\n                extractGraphicsDriverFiles();\n                changeWineAudioDriver();\n            }\n            setupXEnvironment();', '            try {\n                if (!isGenerateWineprefix()) {\n                    setupWineSystemFiles();\n                    extractGraphicsDriverFiles();\n                    changeWineAudioDriver();\n                }\n                setupXEnvironment();\n            } catch (Exception | LinkageError error) {\n                android.util.Log.e("NexusRuntime", "Guest startup failed", error);\n                getIntent().putExtra("nexus_exit_code", -1);\n                runOnUiThread(this::finish);\n            }')
display.write_text(s)
# Background protection is not part of this foreground-only adapter. Remove
# notification posting from the unused upstream helper instead of requesting a
# notification permission or suppressing modern-target lint checks.
notifications = OUT / 'source/app/src/main/java/com/winlator/services/NotificationUtils.java'
notifications.write_text(notifications.read_text().replace('notificationManager.notify(id, notification);',
    'android.util.Log.i("NexusRuntime", "Background notifications are disabled in this adapter");'))
rootfs_source = OUT / 'source/app/src/main/java/com/winlator/xenvironment/RootFS.java'
rootfs_source.write_text(rootfs_source.read_text().replace('new File(context.getFilesDir(), "rootfs")', 'new File(context.getFilesDir(), "r")'))
manifest = []
guest_manifest = []
# Native-code placement is fixed by the signed APK. Rootfs entries become symlinks
# into nativeLibraryDir after extraction; Windows/x86 code is interpreted by Box64.
with tempfile.TemporaryDirectory(prefix='nexus-runtime-') as tmp:
    root = Path(tmp)
    for name in ['rootfs.tzst', 'rootfs_patches.tzst', 'container_pattern.tzst', 'box64/box64-0.4.4.tzst']:
        dest = root / name.replace('/', '_')
        dest.mkdir()
        raw = subprocess.check_output(['zstd', '-dc', str(OUT / 'assets' / name)])
        archive = dest / 'payload.tar'
        archive.write_bytes(raw)
        with tarfile.open(archive) as tar:
            tar.extractall(dest)  # checksum-pinned upstream archive
        archive.unlink()
        for p in sorted(dest.rglob('*')):
            if not p.is_file() or p.is_symlink():
                continue
            data = p.read_bytes()
            # Use a shorter production-only root so embedded strings retain ELF
            # offsets. Never edit another package's directory or lower target API.
            old = b'/data/data/com.winlator/files/rootfs'
            new = b'/data/data/com.nexuspc.app/files/r//'
            assert len(old) == len(new)
            if old in data:
                data = data.replace(old, new)
                p.write_bytes(data)
            rel = p.relative_to(dest).as_posix()
            if name == 'rootfs.tzst' and rel in WINE_DISPATCH_INPUTS:
                data = relocate(rel, data)
                p.write_bytes(data)
                asset = 'nexus-guest/' + p.name
                target = OUT / 'assets' / asset
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                guest_manifest.append({'path': rel, 'asset': asset,
                    'sha256': hashlib.sha256(data).hexdigest()})
            if data[:4] != b'\x7fELF' or data[18:20] != b'\xb7\x00':
                continue
            rel = p.relative_to(dest).as_posix()
            libname = 'libnexus_box64.so' if rel.endswith('/box64') else 'libnexus_rt_' + hashlib.sha256(rel.encode()).hexdigest()[:16] + '.so'
            binary = OUT / 'lib/arm64-v8a' / libname
            shutil.copy2(p, binary)
            if rel.endswith('/box64'):
                subprocess.run(['patchelf', '--set-interpreter', '/data/data/com.nexuspc.app/files/r/usr/lib/ld-linux-aarch64.so.1', str(binary)], check=True)
            manifest.append({'archive': name, 'path': rel, 'library': libname, 'sha256': hashlib.sha256(binary.read_bytes()).hexdigest()})
        # Preserve the adapted data/guest payload in its original asset location.
        packed = root / 'adapted.tar'
        with tarfile.open(packed, 'w') as tar:
            tar.add(dest, arcname='.')
        subprocess.run(['zstd', '-q', '-f', str(packed), '-o', str(OUT / 'assets' / name)], check=True)
        packed.unlink()
# Stage smoke PE built from the project's original source; not an imported fixture.
subprocess.run(['bash', str(ROOT / 'tools/build-smoke.sh')], check=True)
shutil.copy2(ROOT / 'app/feasibility/android/app/src/main/assets/nexus-smoke.exe', OUT / 'assets/nexus-smoke.exe')
assert len(guest_manifest) == len(WINE_DISPATCH_INPUTS)
(OUT / 'assets/nexus-guest-map.json').write_text(json.dumps(guest_manifest, indent=2))
(OUT / 'assets/nexus-native-map.json').write_text(json.dumps(manifest, indent=2))
print(f'Prepared {len(manifest)} packaged ARM64 ELF entries in {OUT}')

# No Bionic dependencies: this shim is loaded only by the pinned glibc loader.
props_file = ROOT / 'app/production/android/local.properties'
props = dict(line.split('=', 1) for line in props_file.read_text().splitlines() if '=' in line) if props_file.is_file() else {}
props.setdefault('sdk.dir', os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or str(Path.home() / ('Library/Android/sdk' if platform.system() == 'Darwin' else 'Android/Sdk')))
host = {'Darwin': 'darwin-x86_64', 'Linux': 'linux-x86_64'}[platform.system()]
clang = Path(props['sdk.dir']) / f'ndk/28.2.13676358/toolchains/llvm/prebuilt/{host}/bin/aarch64-linux-android31-clang'
subprocess.run([str(clang), '-shared', '-fPIC', '-O2', '-std=c11', '-Wall', '-Wextra', '-Werror',
    '-mno-outline-atomics', '-ffreestanding', '-fno-builtin', '-fno-stack-protector', '-nostdlib', '-Wl,-z,max-page-size=16384',
    '-Wl,-soname,libnexus_guest_memory.so', str(ROOT / 'runtime/production-compat/guest_memory.c'),
    '-o', str(OUT / 'lib/arm64-v8a/libnexus_guest_memory.so')], check=True)

subprocess.run([os.sys.executable, str(ROOT / 'tools/prepare-16k-runtime.py')], check=True)
extra = json.loads((OUT / 'assets/nexus-16k-build.json').read_text())

(OUT / 'assets/nexus-runtime-build.json').write_text(json.dumps({
    'schemaVersion': 1, 'bundleSha256': EXPECTED, 'sourceCommit': '3981d86efa4f333b2a34a7da8b6521476cd8c8b9',
    'nativeMapSha256': hashlib.sha256((OUT / 'assets/nexus-native-map.json').read_bytes()).hexdigest(),
    'memoryAdapterSha256': hashlib.sha256((OUT / 'lib/arm64-v8a/libnexus_guest_memory.so').read_bytes()).hexdigest(),
    'guestMapSha256': hashlib.sha256((OUT / 'assets/nexus-guest-map.json').read_bytes()).hexdigest(),
    'wineDispatcherAddress': '0x7ffe4000',
    'supportedPageSizes': [4096, 16384], 'box64Dynarec': False, **extra,
}, indent=2))
