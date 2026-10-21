#!/usr/bin/env python3
"""Prepare a real MIT Windows game for the emulator's ordinary ZIP picker.

No device commands or runtime bundling. Upstream's rolling download must match
this reviewed executable; a new upstream version requires an explicit pin update.
"""
import hashlib
from pathlib import Path
import subprocess
import zipfile

BASE = 'https://www.chiark.greenend.org.uk/~sgtatham/puzzles/'
EXPECTED = '4e576db74c72107ec3e4eea6d1d4f6ddc34c1ebe6e14281da88d9557d71a59c5'
OUT = Path(__file__).resolve().parent.parent / 'runtime/cache/compatibility/fifteen'
OUT.mkdir(parents=True, exist_ok=True)
def download(path):
    return subprocess.check_output(['curl', '--fail', '--silent', '--show-error',
                                    '--location', '--max-time', '60', BASE + path], timeout=65)
cached_exe = OUT / 'fifteen.exe'
exe = cached_exe.read_bytes() if cached_exe.is_file() else download('fifteen.exe')
if hashlib.sha256(exe).hexdigest() != EXPECTED:
    raise SystemExit('Upstream executable changed. Review its version/licence before updating the SHA-256 pin.')
cached_licence = OUT / 'licence.html'
licence = cached_licence.read_bytes() if cached_licence.is_file() else download('doc/licence.html')
(OUT / 'fifteen.exe').write_bytes(exe)
(OUT / 'licence.html').write_bytes(licence)
with zipfile.ZipFile(OUT / 'Fifteen.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    archive.writestr('fifteen.exe', exe)
    archive.writestr('licence.html', licence)
print(f'Windows x86-64 Fifteen: {EXPECTED}\nZIP for system picker: {OUT / "Fifteen.zip"}')
