"""Package the approved artwork as a Windows multi-resolution icon. Needs Pillow.

This is optional asset preparation; ordinary Delphi builds use the checked-in ICO.
"""
from pathlib import Path
import io
import struct
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / 'resources/branding/ot-logo-circle-2758a8.png'
target = root / 'resources/otorrent.ico'
sizes = [(n, n) for n in (16, 20, 24, 32, 40, 48, 64, 128, 256)]
with Image.open(source) as image:
    image = image.convert('RGBA')
    frames = []
    for size in sizes:
        buffer = io.BytesIO()
        options = {'bitmap_format': 'bmp'} if size[0] < 256 else {}
        image.save(buffer, format='ICO', sizes=[size], **options)
        data = buffer.getvalue()
        entry = struct.unpack_from('<BBBBHHII', data, 6)
        frames.append((entry[:6], data[entry[7]:entry[7] + entry[6]]))
    offset = 6 + 16 * len(frames)
    directory, payload = [], []
    for header, data in frames:
        directory.append(struct.pack('<BBBBHHII', *header, len(data), offset))
        payload.append(data)
        offset += len(data)
    target.write_bytes(struct.pack('<HHH', 0, 1, len(frames)) + b''.join(directory + payload))
print(f'Created {target}: {len(sizes)} resolutions, alpha transparency')
