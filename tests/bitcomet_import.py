"""Exercise the actual import dialog against a read-only BitComet profile."""
import ctypes as c
from ctypes import wintypes as w
import hashlib
import json
import os
from pathlib import Path
from profile_json import rows as task_rows
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(os.environ.get('OT_BITCOMET_PROFILE', Path.home() / 'AppData/Roaming/BitComet'))
MANIFEST = SOURCE / 'Downloads.xml'
PROFILE = ROOT / 'build' / ('bitcomet-import-' + uuid.uuid4().hex)
REPORT = PROFILE / 'import-report.json'


def snapshot():
    files = [MANIFEST, *sorted((SOURCE / 'Torrents').glob('*.torrent')),
             *sorted((SOURCE / 'Torrents').glob('*.xml'))]
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


def run():
    before = snapshot()
    source_tasks = {n.get('InfoHashHex', '').lower(): n.attrib
                    for n in ET.parse(MANIFEST).getroot().iter('Torrent')}
    PROFILE.mkdir(parents=True)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags = subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    user = c.WinDLL('user32', use_last_error=True)
    callback_type = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
    user.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]
    user.GetClassNameW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
    user.GetWindowTextW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
    user.EnumWindows.argtypes = [callback_type, w.LPARAM]
    user.EnumChildWindows.argtypes = [w.HWND, callback_type, w.LPARAM]
    user.GetDlgItem.argtypes = [w.HWND, c.c_int]
    user.GetDlgItem.restype = w.HWND
    user.PostMessageW.argtypes = [w.HWND, w.UINT, w.WPARAM, w.LPARAM]
    dialogs = []
    with (PROFILE / 'process.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen(
            [str(ROOT / 'bin/Win64/OtUiSmoke.exe'), '--bitcomet-import', str(MANIFEST), str(REPORT)],
            cwd=ROOT / 'tests', env=dict(os.environ, OT_PROFILE_DIR=str(PROFILE)),
            startupinfo=startup, stdout=log, stderr=subprocess.STDOUT)

        @callback_type
        def inspect_window(window, unused):
            pid = w.DWORD()
            user.GetWindowThreadProcessId(window, c.byref(pid))
            if pid.value != process.pid:
                return True
            classname = c.create_unicode_buffer(256)
            user.GetClassNameW(window, classname, len(classname))
            if classname.value not in ('#32770', 'TMessageForm') or not user.GetDlgItem(window, 1):
                return True
            messages = []

            @callback_type
            def read_child(child, unused):
                text = c.create_unicode_buffer(4096)
                user.GetWindowTextW(child, text, len(text))
                if text.value:
                    messages.append(text.value)
                return True

            user.EnumChildWindows(window, read_child, 0)
            dialogs.append(messages)
            user.PostMessageW(window, 0x111, 1, 0)  # OK, only our test process
            return True

        deadline = time.monotonic() + 120
        try:
            while process.poll() is None:
                user.EnumWindows(inspect_window, 0)
                if time.monotonic() > deadline:
                    raise TimeoutError('BitComet import test exceeded 120 seconds')
                time.sleep(0.1)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(5)
        if dialogs:
            (PROFILE / 'dialogs.json').write_text(json.dumps(dialogs, ensure_ascii=False, indent=2), encoding='utf-8')
        assert process.returncode == 0, (process.returncode, dialogs, str(PROFILE))
        assert not dialogs, dialogs

    report = json.loads(REPORT.read_text(encoding='utf-8-sig'))
    assert report['rows'] == len(source_tasks), report
    assert report['imported'] > 0 and report['imported'] == report['duplicates'], report
    assert report['progress'] == 1000, report
    rows = task_rows(PROFILE, 'info_hash', 'torrent_file', 'save_path', 'running', 'details', 'resume')
    assert len(rows) == report['imported'], (len(rows), report)
    assert len({r[0] for r in rows}) == len(rows)
    skipped_files = 0
    for info_hash, torrent, folder, running, details, resume in rows:
        assert running == 0 and resume is None, (info_hash, running)
        assert info_hash in source_tasks, info_hash
        source = source_tasks[info_hash]
        content = Path(source['SaveLocation'])
        assert Path(folder) in (content, content.parent), (folder, content)
        torrent = Path(torrent)
        assert PROFILE in torrent.parents and torrent.stem == info_hash
        assert torrent.is_file()
        detail = json.loads(details)
        assert detail['files'] and all(f['priority'] in (0, 4) for f in detail['files'])
        cached_torrent = SOURCE / source['TorrentFile']
        if not cached_torrent.is_file():
            cached_torrent = SOURCE / 'Torrents' / source['Torrent']
        files = ET.parse(cached_torrent.with_suffix('.xml')).getroot().find('FileList')
        single = files.get('StandAlone', '').lower() == 'true'
        assert Path(folder) == (content.parent if single else content), (folder, content)
        entries = list(files.iter('FileEntry'))
        assert len(entries) == len(detail['files'])
        for actual, expected in zip(detail['files'], entries):
            expected_path = expected.get('RelativePathName', '').replace('/', '\\')
            while '\\\\' in expected_path:
                expected_path = expected_path.replace('\\\\', '\\')
            if single:
                expected_path = content.name
            assert actual['path'] == expected_path, (actual['path'], expected_path)
            assert actual['size'] == int(expected.get('Size'))
            assert actual['priority'] == (0 if expected.get('Priority') == '-1' else 4)
        skipped_files += sum(f['priority'] == 0 for f in detail['files'])
        assert all(not Path(f['path']).is_absolute() and '..' not in Path(f['path']).parts for f in detail['files'])
    assert before == snapshot(), 'Source BitComet profile changed during the read-only test'
    summary = dict(profile=str(PROFILE), source_tasks=report['rows'], imported=len(rows),
                   not_imported=report['rows']-len(rows),
                   duplicates=report['duplicates'], skipped_files=skipped_files,
                   source_unchanged=True, json_storage='ok')
    (ROOT / 'build/bitcomet-import-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(summary, ensure_ascii=True, indent=2))


if __name__ == '__main__':
    run()
