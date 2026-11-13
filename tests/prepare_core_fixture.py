"""Generate only synthetic files under build/core-fixture for Delphi tests."""
import hashlib
from pathlib import Path

def bencode(value):
    if isinstance(value, int): return b'i' + str(value).encode() + b'e'
    if isinstance(value, bytes): return str(len(value)).encode() + b':' + value
    if isinstance(value, list): return b'l' + b''.join(map(bencode, value)) + b'e'
    if isinstance(value, dict):
        return b'd' + b''.join(bencode(k) + bencode(value[k]) for k in sorted(value)) + b'e'
    raise TypeError(value)

root = Path(__file__).resolve().parents[1] / 'build/core-fixture'
(root / 'data/custom').mkdir(parents=True, exist_ok=True)
blocks = [bytes([65 + i]) * 16384 for i in range(4)]
info = {b'name': b'original', b'piece length': 16384,
        b'pieces': b''.join(hashlib.sha1(block).digest() for block in blocks),
        b'files': [{b'length': 16384, b'path': [f'{i}.bin'.encode()]} for i in range(4)]}
(root / 'state.torrent').write_bytes(bencode({b'info': info}))
for i in (0, 2):
    (root / 'data/custom' / f'{i}.bin').write_bytes(blocks[i])
print('Synthetic Delphi test fixture is ready')
