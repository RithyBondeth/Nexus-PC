#!/usr/bin/env python3
"""Rebuild the experimental native profile and Box64 from checksum-pinned inputs.
Called only after prepare-production-runtime.py has staged the pinned base bundle.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'runtime/vendor/production'
CACHE = ROOT / 'runtime/cache'
LOCK = json.loads((ROOT / 'runtime/production-16k.lock.json').read_text())
LIB = OUT / 'lib/arm64-v8a'

def run(args):
    subprocess.run([str(a) for a in args], check=True)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def fetch(url, path, sha):
    if not path.is_file():
        temp = path.with_suffix(path.suffix + '.download')
        run(['curl', '--fail', '--location', '--retry', '2', '--max-time', '180', url, '-o', temp])
        if digest(temp) != sha:
            temp.unlink()
            raise RuntimeError(f'Checksum mismatch: {path.name}')
        temp.replace(path)
    if digest(path) != sha:
        raise RuntimeError(f'Checksum mismatch: {path.name}')

system = platform.system()
machine = {'arm64': 'aarch64', 'AMD64': 'x86_64'}.get(platform.machine(), platform.machine())
host_key = machine + '-' + {'Darwin': 'macos', 'Linux': 'linux'}[system]
zig_info = LOCK['zig']['hosts'][host_key]
zig_archive = CACHE / Path(zig_info['tarball']).name
fetch(zig_info['tarball'], zig_archive, zig_info['shasum'])
zig_dir = CACHE / zig_archive.name.removesuffix('.tar.xz')
if not (zig_dir / 'zig').is_file():
    with tarfile.open(zig_archive) as tar:
        tar.extractall(CACHE)  # checksum-pinned official toolchain archive

box = LOCK['box64']
archive = CACHE / 'box64-16k.tar.gz'
fetch(box['url'], archive, box['sha256'])
source = ROOT / 'runtime/vendor/box64-16k'
# Preserve generated wrappers and incremental objects, but always restore pinned
# source files before applying the one deterministic build-metadata adaptation.
source.mkdir(parents=True, exist_ok=True)
with tarfile.open(archive) as tar:
    prefix = tar.getmembers()[0].name.split('/')[0] + '/'
    for member in tar.getmembers():
        if not member.name.startswith(prefix) or member.name == prefix:
            continue
        member.name = member.name[len(prefix):]
        if member.name:
            tar.extract(member, source)
info = source / 'src/build_info.c'
info.write_text(info.read_text().replace('__DATE__', '"pinned-source"').replace('__TIME__', '""'))
wrapper = CACHE / 'nexus-zig-cc'
wrapper.write_text('#!/bin/sh\nexec ' + shlex.quote(str(zig_dir / 'zig')) + ' cc -target aarch64-linux-gnu.2.35 "$@"\n')
wrapper.chmod(0o755)

props_file = ROOT / 'app/production/android/local.properties'
props = dict(line.split('=', 1) for line in props_file.read_text().splitlines() if '=' in line) if props_file.is_file() else {}
sdk = Path(props.get('sdk.dir') or os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or str(Path.home() / ('Library/Android/sdk' if system == 'Darwin' else 'Android/Sdk')))
cmake = sdk / ('cmake/' + LOCK['cmake'] + '/bin/cmake')
ninja = cmake.with_name('ninja')
ndk = sdk / ('ndk/' + LOCK['androidNdk'])
box_build = CACHE / 'box64-16k-source-build'
run([cmake, '-S', source, '-B', box_build, '-G', 'Ninja', '-DCMAKE_MAKE_PROGRAM=' + str(ninja),
     '-DCMAKE_SYSTEM_NAME=Linux', '-DCMAKE_SYSTEM_PROCESSOR=aarch64', '-DCMAKE_C_COMPILER=' + str(wrapper),
     '-DCMAKE_ASM_COMPILER=' + str(wrapper), '-DNOGIT=ON', '-DARM64=ON', '-DARM_DYNAREC=OFF',
     '-DBOX32=OFF', '-DNOLOADADDR=ON', '-DCMAKE_BUILD_TYPE=RelWithDebInfo',
     '-DCMAKE_EXE_LINKER_FLAGS=-Wl,-z,max-page-size=65536 -Wl,-z,common-page-size=65536'])
run([cmake, '--build', box_build, '-j', '4'])

cpp = OUT / 'source/app/src/main/cpp'
# The pinned upstream headers depended on incidental include order with its old
# compiler. Add their actual declarations rather than suppressing diagnostics.
for relative, headers in {
    'winlator/include/time_utils.h': ['time.h'],
    'winlator/include/string_utils.h': ['string.h', 'stdlib.h'],
    'gladiorenderer/include/stb_dxt.h': ['string.h'],
    'winlator/include/dma_utils.h': ['unistd.h'],
}.items():
    path = cpp / relative
    text = path.read_text()
    for header in headers:
        include = '#include <' + header + '>'
        if include not in text:
            text = include + '\n' + text
    if relative.endswith('dma_utils.h'):
        text = text.replace('.align = 4096,', '.align = (unsigned int)sysconf(_SC_PAGESIZE),')
    path.write_text(text)
native_build = CACHE / 'android-16k-build'
run([cmake, '-S', ROOT / 'runtime/production-compat/native', '-B', native_build, '-G', 'Ninja',
     '-DCMAKE_MAKE_PROGRAM=' + str(ninja), '-DCMAKE_TOOLCHAIN_FILE=' + str(ndk / 'build/cmake/android.toolchain.cmake'),
     '-DNEXUS_UPSTREAM_CPP=' + str(cpp), '-DANDROID_ABI=arm64-v8a', '-DANDROID_PLATFORM=android-31',
     '-DANDROID_STL=c++_shared', '-DBUILD_SHARED_LIBS=ON', '-DCMAKE_BUILD_TYPE=Release'])
run([cmake, '--build', native_build, '-j', '4'])
# Do not package unused 4 KB-only MIDI/PulseAudio dependency chains. The current
# foreground GDI profile uses Java AudioTrack/ALSA; unsupported paths fail clearly.
for path in LIB.glob('*.so'):
    if not path.name.startswith('libnexus_'):
        path.unlink()
rebuilt = []
for path in sorted(native_build.rglob('*.so')):
    shutil.copy2(path, LIB / path.name)
    rebuilt.append(path.name)
ndk_host = {'Darwin': 'darwin-x86_64', 'Linux': 'linux-x86_64'}[system]
shutil.copy2(ndk / f'toolchains/llvm/prebuilt/{ndk_host}/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so', LIB / 'libc++_shared.so')
shutil.copy2(box_build / 'box64', LIB / 'libnexus_box64.so')
run(['patchelf', '--set-interpreter', '/data/data/com.nexuspc.app/files/r/usr/lib/ld-linux-aarch64.so.1', LIB / 'libnexus_box64.so'])

midi = OUT / 'source/app/src/main/java/com/winlator/winhandler/MIDIHandler.java'
text = midi.read_text().replace('System.loadLibrary("midihandler");', 'android.util.Log.i("NexusRuntime", "MIDI synthesis is not packaged in this experimental runtime");')
# Preserve the caller's allocation-failure path and make unsupported synthesis
# calls harmless when a controller still sends MIDI events. No success is claimed.
text = re.sub(r'private native (long|void) (\w+)\(([^;]*)\);',
              lambda m: 'private ' + m[1] + ' ' + m[2] + '(' + m[3] + ') { ' + ('return 0;' if m[1] == 'long' else '') + ' }', text)
midi.write_text(text)
pulse = OUT / 'source/app/src/main/java/com/winlator/xenvironment/components/PulseAudioComponent.java'
pulse.write_text(pulse.read_text().replace('pid = execPulseAudio();', 'throw new UnsupportedOperationException("PulseAudio is not packaged; use ALSA in this experimental runtime.");'))

mapping = OUT / 'assets/nexus-native-map.json'
entries = json.loads(mapping.read_text())
for entry in entries:
    if entry['library'] == 'libnexus_box64.so':
        entry['sha256'] = digest(LIB / entry['library'])
mapping.write_text(json.dumps(entries, indent=2))
licenses = OUT / 'assets/nexus-runtime-licenses'
licenses.mkdir(exist_ok=True)
shutil.copy2(source / 'LICENSE', licenses / 'box64-MIT.txt')
metadata = {
    'box64SourceCommit': box['commit'], 'box64SourceSha256': box['sha256'],
    'box64Version': box['version'], 'box64BinarySha256': digest(LIB / 'libnexus_box64.so'),
    'androidNativeSourceCommit': '3981d86efa4f333b2a34a7da8b6521476cd8c8b9',
    'androidNdk': LOCK['androidNdk'], 'zigVersion': LOCK['zig']['version'],
    'zstdJniVersion': LOCK['zstdJni']['version'],
    'rebuiltAndroidLibraries': rebuilt, 'unsupportedFeatures': LOCK['unsupportedFeatures'],
}
(OUT / 'assets/nexus-16k-build.json').write_text(json.dumps(metadata, indent=2))
print('16 KB native profile prepared:', metadata['box64SourceCommit'])
