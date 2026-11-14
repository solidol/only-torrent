"""Resolve an explicitly supplied magnet to metadata only, never its payload."""
import argparse
import base64
import ctypes as c
import json
from pathlib import Path
import time
from urllib.parse import parse_qs, urlsplit
from engine_common import dll


class MetaInfo(c.Structure):
    _fields_ = [('total', c.c_int64), ('files', c.c_int32), ('trackers', c.c_int32),
                ('name', c.c_char * 512), ('comment', c.c_char * 1024)]


class MetaExtra(c.Structure):
    _fields_ = [('created', c.c_int64), ('pieces', c.c_int32), ('piece_length', c.c_int32),
                ('creator', c.c_char * 512), ('publisher', c.c_char * 512),
                ('publisher_url', c.c_char * 2048), ('hash', c.c_ubyte * 32), ('web_seeds', c.c_char * 4096)]


def resolve(link, timeout):
    root = Path(__file__).resolve().parents[1] / 'build/magnet-metadata'
    root.mkdir(parents=True, exist_ok=True)
    topic = next(v for v in parse_qs(urlsplit(link).query).get('xt', []) if v.lower().startswith('urn:btih:'))[9:]
    expected = topic.lower() if len(topic) == 40 else base64.b32decode(topic.upper()).hex()
    dll.lt_magnet_open.argtypes = [c.c_char_p, c.c_int]
    dll.lt_magnet_open.restype = c.c_void_p
    dll.lt_magnet_poll.argtypes = [c.c_void_p, c.POINTER(c.c_int), c.POINTER(c.c_int)]
    dll.lt_magnet_poll.restype = c.c_void_p
    dll.lt_magnet_close.argtypes = [c.c_void_p]
    dll.lt_blob_copy.argtypes = [c.c_void_p, c.c_void_p, c.c_int]
    dll.lt_blob_close.argtypes = [c.c_void_p]
    dll.lt_meta_open.argtypes = [c.c_char_p]
    dll.lt_meta_open.restype = c.c_void_p
    dll.lt_meta_close.argtypes = [c.c_void_p]
    dll.lt_meta_info.argtypes = [c.c_void_p, c.POINTER(MetaInfo)]
    dll.lt_meta_extra.argtypes = [c.c_void_p, c.c_void_p, c.c_int, c.POINTER(MetaExtra)]
    job = dll.lt_magnet_open(link.encode('utf-8'), 1)
    assert job, dll.lt_error()
    status, count = c.c_int(), c.c_int()
    started = time.monotonic()
    next_progress = started + 10
    result = {'info_hash': expected, 'payload_downloaded': False}
    try:
        while time.monotonic() - started < timeout:
            blob = dll.lt_magnet_poll(job, c.byref(status), c.byref(count))
            if status.value < 0:
                raise RuntimeError(dll.lt_error().decode('utf-8', 'replace'))
            if blob:
                try:
                    assert 0 < count.value <= 64 * 1024 * 1024
                    buffer = c.create_string_buffer(count.value)
                    assert dll.lt_blob_copy(blob, buffer, count.value) == count.value
                    path = root / (expected + '.torrent')
                    path.write_bytes(buffer.raw)
                finally:
                    dll.lt_blob_close(blob)
                handle = dll.lt_meta_open(str(path).encode('utf-8'))
                assert handle, dll.lt_error()
                try:
                    meta, extra = MetaInfo(), MetaExtra()
                    assert dll.lt_meta_info(handle, c.byref(meta)) == 0
                    assert dll.lt_meta_extra(handle, buffer, count.value, c.byref(extra)) == 0
                    assert bytes(extra.hash[:20]).hex() == expected
                    result.update(status='PASS', torrent_file=str(path), metadata_bytes=count.value,
                                  files=meta.files, total_bytes=meta.total)
                finally:
                    dll.lt_meta_close(handle)
                break
            if time.monotonic() >= next_progress:
                print('Waiting for metadata:', int(time.monotonic() - started), 's', flush=True)
                next_progress += 10
            time.sleep(0.1)
        else:
            result.update(status='TIMEOUT', reason='No metadata received from available tracker/DHT peers within the timeout')
    finally:
        dll.lt_magnet_close(job)
    (root / (expected + '.json')).write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=True, indent=2), flush=True)
    return 0 if result['status'] == 'PASS' else 2


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('link')
    parser.add_argument('--timeout', type=int, default=120)
    args = parser.parse_args()
    raise SystemExit(resolve(args.link, args.timeout))
