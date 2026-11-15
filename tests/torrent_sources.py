"""Local HTTP, magnet metadata-only and watch-folder tests; no user downloads."""
import configparser
import ctypes as c
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import socket
from profile_json import rows as task_rows
import ssl
import subprocess
import threading
import time
import uuid
from engine_common import dll, bencode, create_session, add_prepared, Snapshot

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / 'build' / ('torrent-sources-' + uuid.uuid4().hex)
RUN.mkdir(parents=True)
PAYLOAD = b'A' * 16384 + b'B' * 16384
INFO = {b'name': b'source.bin', b'length': len(PAYLOAD), b'piece length': 16384,
        b'pieces': hashlib.sha1(PAYLOAD[:16384]).digest() + hashlib.sha1(PAYLOAD[16384:]).digest()}
TORRENT = bencode({b'info': INFO})
HASH = hashlib.sha1(bencode(INFO)).hexdigest()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        try:
            if self.path in ('/redirect', '/loop'):
                self.send_response(302)
                self.send_header('Location', '/ok' if self.path == '/redirect' else '/loop')
                self.send_header('Content-Length', '0')
                self.end_headers()
                return
            body = TORRENT
            status = 200
            if self.path == '/missing':
                status, body = 404, b'not found'
            elif self.path == '/html':
                body = b'<html>not a torrent</html>'
            self.send_response(status)
            self.send_header('Content-Type', 'application/x-bittorrent')
            self.send_header('Content-Length', str(64 * 1024 * 1024 + 1 if self.path == '/large' else len(body)))
            self.end_headers()
            if self.path == '/slow':
                for byte in body:
                    self.wfile.write(bytes([byte]))
                    self.wfile.flush()
                    time.sleep(0.04)
            else:
                self.wfile.write(body)
        except (ConnectionError, ssl.SSLError):
            pass


def settings(root, watch=None):
    profile = root / 'profile'
    profile.mkdir(parents=True, exist_ok=True)
    folder = root / 'data'
    folder.mkdir(exist_ok=True)
    (profile / 'settings.json').write_text(json.dumps({
        'schemaVersion': 1, 'addingFolder': str(folder), 'addingStartImmediately': False,
        'addingShowDialog': True, 'storageTorrentFolder': str(profile / 'Torrents'),
        'watchEnabled': bool(watch), 'watchFolder': str(watch or '')}), encoding='utf-8')
    return profile


def launch(arguments, profile):
    startup = subprocess.STARTUPINFO()
    startup.dwFlags = subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    result = subprocess.run([str(ROOT / 'bin/Win64/OtUiSmoke.exe'), *map(str, arguments)],
                            cwd=ROOT / 'tests', startupinfo=startup, env=dict(os.environ, OT_PROFILE_DIR=str(profile)),
                            timeout=45, capture_output=True)
    assert result.returncode == 0, (arguments, result.returncode,
        (ROOT / 'build/ui-smoke.txt').read_text(encoding='utf-8-sig') if (ROOT / 'build/ui-smoke.txt').exists() else '')


def source_case(name, link, mode):
    root = RUN / name
    root.mkdir()
    profile = settings(root)
    report = root / 'report.txt'
    launch(['--source-test', link, report, mode], profile)
    assert report.read_text(encoding='utf-8-sig').startswith('PASS: ' + mode)
    rows = task_rows(profile, 'info_hash', 'running', 'torrent_file', 'details')
    assert len(rows) == int(mode in ('success', 'download')), (name, rows)
    if rows:
        assert rows[0][0] == HASH and rows[0][1] == int(mode == 'download')
        assert Path(rows[0][2]).is_file()
        details = json.loads(rows[0][3])
        assert details['needsVerification'] == (mode != 'download')
        if link.startswith('magnet:'):
            assert details['magnet'] == link
            cfg = json.loads((profile / 'settings.json').read_text(encoding='utf-8-sig'))
            assert cfg['networkDHT']
    if mode == 'download':
        assert (root / 'data/source.bin').read_bytes() == PAYLOAD
    else:
        assert not (root / 'data/source.bin').exists(), 'Metadata acquisition must not download payload'
    assert not list((profile / 'Incoming').glob('*.torrent')), 'Temporary metadata cleaned up'
    print('PASS:', name, flush=True)


def watch_case():
    root = RUN / 'watch'
    watch = root / 'watch'
    watch.mkdir(parents=True)
    (watch / 'one.torrent').write_bytes(TORRENT)
    (watch / 'duplicate.torrent').write_bytes(TORRENT)
    other = dict(INFO, **{})
    other[b'name'] = b'other.bin'
    (watch / 'two.torrent').write_bytes(bencode({b'info': other}))
    (watch / 'invalid.torrent').write_bytes(b'<html>not a torrent</html>')
    (watch / 'ignore.torrent.part').write_bytes(TORRENT)
    before = {p.name: p.read_bytes() for p in watch.iterdir()}
    profile = settings(root, watch)
    ids = None
    for iteration in range(2):
        report = root / f'watch-{iteration}.txt'
        launch(['--watch-test', report], profile)
        assert report.read_text(encoding='utf-8-sig').strip() == 'PASS: watcher'
        rows = task_rows(profile, 'id', 'info_hash', 'running')
        assert len(rows) == 2 and all(row[2] == 0 for row in rows)
        if ids is None:
            ids = rows
        else:
            assert rows == ids, 'Watch restart must not recreate duplicate tasks'
    assert before == {p.name: p.read_bytes() for p in watch.iterdir()}
    assert not list((root / 'data').iterdir()), 'Paused watch imports do not download payload'
    print('PASS: watcher, duplicates, malformed/partial files, original preservation and restart', flush=True)


def magnet_cases():
    sock = socket.socket()
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]
    sock.close()
    seed = RUN / 'seed'
    seed.mkdir()
    torrent = seed / 'seed.torrent'
    torrent.write_bytes(TORRENT)
    (seed / 'source.bin').write_bytes(PAYLOAD)
    session = create_session(port)
    assert session
    try:
        tid = add_prepared(session, str(torrent).encode(), str(seed).encode(), [4], paths=[b'source.bin'])
        assert tid > 0, dll.lt_error()
        snapshot = Snapshot()
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            assert dll.lt_snapshot(session, tid, c.byref(snapshot)) == 0
            if snapshot.done == len(PAYLOAD):
                break
            time.sleep(0.05)
        assert snapshot.done == len(PAYLOAD), 'Local metadata seed did not become ready'
        source_case('magnet-local-peer', f'magnet:?xt=urn:btih:{HASH}&x.pe=127.0.0.1:{port}', 'success')
        source_case('magnet-download', f'magnet:?xt=urn:btih:{HASH}&x.pe=127.0.0.1:{port}', 'download')
        assert (seed / 'source.bin').read_bytes() == PAYLOAD
    finally:
        dll.lt_destroy(session)
    source_case('magnet-invalid', 'magnet:?xt=urn:btih:invalid', 'error')
    source_case('magnet-cancel', 'magnet:?xt=urn:btih:' + '1' * 40, 'cancel')


def main():
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f'http://127.0.0.1:{server.server_port}'
    try:
        for name, route, mode in [('http', '/ok', 'success'), ('redirect', '/redirect', 'success'),
                                  ('not-found', '/missing', 'error'), ('html', '/html', 'error'),
                                  ('oversized', '/large', 'error'), ('redirect-loop', '/loop', 'error'),
                                  ('http-cancel', '/slow', 'cancel')]:
            source_case(name, base + route, mode)
        source_case('unsupported-scheme', 'file:///C:/private.torrent', 'error')
        openssl = shutil.which('openssl') or r'C:\Program Files\Git\usr\bin\openssl.exe'
        cert, key = RUN / 'cert.pem', RUN / 'key.pem'
        subprocess.run([openssl, 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
                        '-subj', '/CN=localhost', '-keyout', str(key), '-out', str(cert)],
                       check=True, capture_output=True)
        tls = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        tls.daemon_threads = True
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert, key)
        tls.socket = context.wrap_socket(tls.socket, server_side=True)
        threading.Thread(target=tls.serve_forever, daemon=True).start()
        try:
            source_case('https-reject-untrusted-cert', f'https://127.0.0.1:{tls.server_port}/ok', 'error')
        finally:
            tls.shutdown()
            tls.server_close()
        magnet_cases()
        watch_case()
    finally:
        server.shutdown()
        server.server_close()
    (ROOT / 'build/torrent-sources-summary.json').write_text(
        json.dumps({'status': 'PASS', 'root': str(RUN)}, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
