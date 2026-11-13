"""Fetch the pinned, original SQLite x64 DLL; validate the publisher SHA3-256."""
import hashlib
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / 'deps/sqlite-dll-win-x64-3540100.zip'
URL = 'https://www.sqlite.org/2026/sqlite-dll-win-x64-3540100.zip'
SHA3 = 'c2d09c8babb9399277055c057c97a53f1ffd7c5f11d0c1f2118ffdfa39f2daa4'
ARCHIVE.parent.mkdir(exist_ok=True)
if not ARCHIVE.exists():
    with urllib.request.urlopen(URL, timeout=60) as response:
        data = response.read()
    if hashlib.sha3_256(data).hexdigest() != SHA3:
        raise RuntimeError('SQLite publisher SHA3-256 mismatch')
    ARCHIVE.write_bytes(data)
if hashlib.sha3_256(ARCHIVE.read_bytes()).hexdigest() != SHA3:
    raise RuntimeError('SQLite archive SHA3-256 mismatch')
with zipfile.ZipFile(ARCHIVE) as package:
    data = package.read('sqlite3.dll')
# Optional dependency preparation never updates the pinned runtime or client.
for folder in ('deps/sqlite/3.54.1',):
    target = ROOT / folder
    target.mkdir(parents=True, exist_ok=True)
    library = target / 'sqlite3.dll'
    if not library.exists() or library.read_bytes() != data:
        library.write_bytes(data)
print('PASS: original SQLite 3.54.1 x64 DLL; publisher SHA3-256 verified')
