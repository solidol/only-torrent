"""Isolated updater/association regression tests; never updates the installed client."""
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
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / 'build' / ('release-tests-' + uuid.uuid4().hex)
RUN.mkdir(parents=True)
user = c.WinDLL('user32', use_last_error=True)
callback = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
user.EnumWindows.argtypes = [callback, w.LPARAM]
user.EnumChildWindows.argtypes = [w.HWND, callback, w.LPARAM]
user.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]
user.GetClassNameW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
user.GetWindowTextW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
user.PostMessageW.argtypes = [w.HWND, w.UINT, w.WPARAM, w.LPARAM]
user.IsWindowVisible.argtypes = [w.HWND]
user.IsWindowEnabled.argtypes = [w.HWND]
user.GetMenu.argtypes = [w.HWND]
user.GetMenu.restype = w.HMENU
user.GetSubMenu.argtypes = [w.HMENU, c.c_int]
user.GetSubMenu.restype = w.HMENU
user.GetMenuItemID.argtypes = [w.HMENU, c.c_int]
user.GetMenuItemID.restype = w.UINT
user.SendMessageTimeoutW.argtypes = [w.HWND, w.UINT, w.WPARAM, w.LPARAM, w.UINT, w.UINT, c.POINTER(c.c_size_t)]
user.SendMessageTimeoutW.restype = w.LPARAM


def text(window):
    value = c.create_unicode_buffer(32769)
    user.GetWindowTextW(window, value, len(value))
    return value.value


def edit_text(window):
    # GetWindowText cannot retrieve another process's edit control contents.
    value = c.create_unicode_buffer(32769)
    result = c.c_size_t()
    assert user.SendMessageTimeoutW(window, 0xD, len(value), c.cast(value, c.c_void_p).value,
                                    2, 2000, c.byref(result))
    return value.value


def enumerate_windows(parent=None):
    result = []

    @callback
    def collect(window, unused):
        pid = w.DWORD()
        user.GetWindowThreadProcessId(window, c.byref(pid))
        name = c.create_unicode_buffer(128)
        user.GetClassNameW(window, name, len(name))
        result.append((window, pid.value, name.value))
        return True

    if parent is None:
        user.EnumWindows(collect, 0)
    else:
        user.EnumChildWindows(parent, collect, 0)
    return result


def wait_for(predicate, message, seconds=20):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(.05)
    raise AssertionError(message)


def form(pid, name):
    return next((h for h, owner, cls in enumerate_windows() if owner == pid and cls == name), None)


def button(window, caption):
    return next((h for h, _, cls in enumerate_windows(window) if cls == 'TButton' and text(h) == caption), None)


def click(window, caption):
    control = wait_for(lambda: button(window, caption), 'Missing button: ' + caption)
    user.PostMessageW(control, 0xF5, 0, 0)


def bencode(value):
    if isinstance(value, int):
        return b'i' + str(value).encode() + b'e'
    if isinstance(value, bytes):
        return str(len(value)).encode() + b':' + value
    return b'd' + b''.join(bencode(k) + bencode(v) for k, v in sorted(value.items())) + b'e'


def main():
    old_exe = ROOT / 'build/update-old-fixture/otorrent.exe'
    assert old_exe.is_file(), 'Need an older executable in build/update-old-fixture/otorrent.exe'
    completed = subprocess.run([str(ROOT / 'bin/Win64/OtCoreTests.exe'), '--updates', str(old_exe)],
                               cwd=ROOT / 'tests', timeout=120)
    assert completed.returncode == 0, (ROOT / 'build/core-tests.txt').read_text(encoding='utf-8-sig')
    print((ROOT / 'build/update-tests.txt').read_text(encoding='utf-8-sig').strip())
    profile = RUN / 'profile'
    profile.mkdir()
    (profile / 'settings.json').write_text(json.dumps({'schemaVersion':1, 'interfaceLanguage':'en-US', 'addingStartImmediately':False, 'addingShowDialog':True, 'addingFolder':str(RUN / 'downloads')}), encoding='utf-8')
    torrent = RUN / 'Тест із пробілами.torrent'
    torrent.write_bytes(bencode({b'info': {b'name': b'fixture.bin', b'length': 4,
        b'piece length': 16384, b'pieces': hashlib.sha1(b'test').digest(), b'private': 1}}))
    env = dict(os.environ, OT_PROFILE_DIR=str(profile))
    executable = str(ROOT / 'bin/Win64/otorrent.exe')
    client = subprocess.Popen([executable, '--open', str(torrent)], env=env, cwd=ROOT)
    updater_pid = None
    try:
        window = wait_for(lambda: form(client.pid, 'TFormMain'), 'Main window missing')
        dialog = wait_for(lambda: form(client.pid, 'TFormAddTorrent'), 'Startup file activation failed')
        second = subprocess.run([executable, '--open', str(torrent)], env=env, cwd=ROOT, timeout=12)
        assert second.returncode == 0, 'Second instance failed to forward the file'
        assert form(client.pid, 'TFormAddTorrent') == dialog, 'IPC interrupted the modal dialog'
        click(dialog, 'Cancel')
        time.sleep(.25)
        dialog = wait_for(lambda: form(client.pid, 'TFormAddTorrent'), 'Queued activation was lost')
        click(dialog, 'Cancel')
        wait_for(lambda: form(client.pid, 'TFormAddTorrent') is None, 'Cancel did not close add dialog')
        user.PostMessageW(window, 0x112, 0xF020, 0)
        wait_for(lambda: not user.IsWindowVisible(window), 'Minimize did not hide client')
        assert subprocess.run([executable], env=env, cwd=ROOT, timeout=12).returncode == 0
        wait_for(lambda: user.IsWindowVisible(window), 'Repeat launch did not restore client')
        magnet = 'magnet:?xt=invalid&dn=%D0%A2%D0%B5%D1%81%D1%82%20%26%20name'
        assert subprocess.run([executable, '--open', magnet], env=env, cwd=ROOT, timeout=12).returncode == 0
        link = wait_for(lambda: form(client.pid, 'TFormAddLink'), 'Magnet activation did not open metadata dialog')
        edit = next(h for h, _, cls in enumerate_windows(link) if cls == 'TEdit')
        assert edit_text(edit) == magnet, 'Magnet was decoded or truncated during activation'
        click(link, 'Cancel')
        wait_for(lambda: form(client.pid, 'TFormAddLink') is None, 'Magnet cancellation failed')
        print('PASS: startup torrent, Unicode path, second-instance forwarding, modal queue, tray activation, intact magnet URI and cancellation')
        previous = {h for h, _, cls in enumerate_windows() if cls == 'TFormUpdater'}
        options = user.GetSubMenu(user.GetMenu(window), 1)
        command = user.GetMenuItemID(options, 1)
        assert command != 0xFFFFFFFF
        user.PostMessageW(window, 0x111, command, 0)
        updater, updater_pid = wait_for(lambda: next(((h, p) for h, p, cls in enumerate_windows()
            if cls == 'TFormUpdater' and h not in previous), None), 'Menu did not launch updater')
        time.sleep(1)
        assert button(updater, 'Update'), 'Single Update button is missing'
        assert len([h for h, _, cls in enumerate_windows(updater) if cls == 'TButton']) == 1
        progress = next(h for h, _, cls in enumerate_windows(updater) if cls == 'TProgressBar')
        user.GetWindowLongW.argtypes = [w.HWND, c.c_int]
        wait_for(lambda: not user.GetWindowLongW(progress, -16) & 8,
                 'Updater check did not finish', seconds=45)
        # Do not install the real public package in an integration test.
        user.PostMessageW(updater, 0x10, 0, 0)
        wait_for(lambda: form(updater_pid, 'TFormUpdater') is None, 'Updater did not close')
        print('PASS: Settings menu launches standalone updater; one Update button; initial check completes; close without installation')
        user.PostMessageW(window, 0x10, 0, 0)
        assert client.wait(25) == 0
        assert len(task_rows(profile, "id")) == 0
        (ROOT / 'build/release-integration-summary.json').write_text(json.dumps({'status': 'PASS', 'root': str(RUN)}, indent=2), encoding='utf-8')
    finally:
        if updater_pid and form(updater_pid, 'TFormUpdater'):
            user.PostMessageW(form(updater_pid, 'TFormUpdater'), 0x10, 0, 0)
        if client.poll() is None:
            client.kill()
            client.wait(5)


if __name__ == '__main__':
    main()
