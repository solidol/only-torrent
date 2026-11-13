"""Verify the entire upstream source tree against its pinned release archive."""
import hashlib,json,tarfile,sys
from pathlib import Path,PurePosixPath
config=json.loads(Path('native/dependencies.json').read_text(encoding='utf-8-sig'))['libtorrent']
archive=Path(config['archive'])
assert hashlib.sha256(archive.read_bytes()).hexdigest()==config['sha256'].lower(),'Archive SHA-256 mismatch'
source=Path(sys.argv[1]) if len(sys.argv)>1 else Path(config['source'])
expected=set()
with tarfile.open(archive,'r:gz') as tar:
    for item in tar:
        if not item.isfile():continue
        relative=PurePosixPath(*PurePosixPath(item.name).parts[1:])
        assert relative.parts and '..' not in relative.parts
        path=source.joinpath(*relative.parts)
        assert path.is_file(),f'Missing upstream file: {relative}'
        assert path.read_bytes()==tar.extractfile(item).read(),f'Modified upstream file: {relative}'
        expected.add(relative.as_posix())
for path in source.rglob('*'):
    if path.is_file() and (path.suffix.lower() in ('.cpp','.c','.h','.hpp','.cmake') or path.name=='CMakeLists.txt'):
        assert path.relative_to(source).as_posix() in expected,f'Injected upstream source: {path}'
print(f'PASS: {len(expected)} original libtorrent files match the SHA-256-pinned upstream archive')
