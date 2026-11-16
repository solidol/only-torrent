"""Exercise real window buttons and tray callbacks of otorrent.exe."""
import ctypes as c
from ctypes import wintypes as w
import json
import os
from pathlib import Path
import subprocess
import shutil
from profile_json import rows as task_rows
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / 'build' / ('tray-profile-' + uuid.uuid4().hex)
PROFILE.mkdir(parents=True)
user = c.WinDLL('user32', use_last_error=True)
shell = c.WinDLL('shell32', use_last_error=True)
callback = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
user.EnumWindows.argtypes = [callback, w.LPARAM]
user.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]
user.GetClassNameW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
user.IsWindowVisible.argtypes = [w.HWND]
user.IsZoomed.argtypes = [w.HWND]
user.PostMessageW.argtypes = [w.HWND, w.UINT, w.WPARAM, w.LPARAM]


class IconIdentifier(c.Structure):
    _fields_ = [('size', w.DWORD), ('window', w.HWND), ('identifier', w.UINT), ('guid', c.c_byte * 16)]


shell.Shell_NotifyIconGetRect.argtypes = [c.POINTER(IconIdentifier), c.POINTER(w.RECT)]
shell.Shell_NotifyIconGetRect.restype = c.c_long


def windows(pid):
    result = []

    @callback
    def collect(window, unused):
        owner = w.DWORD()
        user.GetWindowThreadProcessId(window, c.byref(owner))
        if owner.value == pid:
            name = c.create_unicode_buffer(256)
            user.GetClassNameW(window, name, len(name))
            result.append((window, name.value))
        return True

    user.EnumWindows(collect, 0)
    return result


def tray_handle(pid):
    for window, classname in windows(pid):
        if classname != 'TPUtilWindow':
            continue
        identifier = IconIdentifier(c.sizeof(IconIdentifier), window, window & 0xffffffff)
        rectangle = w.RECT()
        # Explorer may return S_FALSE for an icon in its overflow area.
        # Both S_OK and S_FALSE are successful HRESULTs; E_FAIL means absent.
        if shell.Shell_NotifyIconGetRect(c.byref(identifier), c.byref(rectangle)) >= 0:
            return window
    return None


def wait_for(predicate, message):
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(0.05)
    raise AssertionError(message)


def main():
    process = subprocess.Popen([str(ROOT / 'bin/Win64/otorrent.exe')], cwd=ROOT,
                               env=dict(os.environ, OT_PROFILE_DIR=str(PROFILE)))
    try:
        window = wait_for(lambda: next((h for h, name in windows(process.pid) if name == 'TFormMain'), None),
                          'Main window was not created')
        wait_for(lambda: user.IsWindowVisible(window), 'Main window not visible')
        assert tray_handle(process.pid) is None, 'No tray icon while normal window is shown'
        for maximized in (False, True):
            if maximized:
                user.PostMessageW(window, 0x112, 0xF030, 0)  # SC_MAXIMIZE
                wait_for(lambda: user.IsZoomed(window), 'Window did not maximize')
            user.PostMessageW(window, 0x112, 0xF020, 0)  # title-bar SC_MINIMIZE
            wait_for(lambda: not user.IsWindowVisible(window), 'Minimize did not hide the main window')
            try:
                tray = wait_for(lambda: tray_handle(process.pid), 'Tray icon was not registered with Explorer')
            except AssertionError:
                diagnostics = []
                for handle, classname in windows(process.pid):
                    identifier = IconIdentifier(c.sizeof(IconIdentifier), handle, handle & 0xffffffff)
                    rectangle = w.RECT()
                    result = shell.Shell_NotifyIconGetRect(c.byref(identifier), c.byref(rectangle))
                    diagnostics.append((handle, classname, result))
                raise AssertionError(('Tray icon lookup failed', maximized, process.poll(), diagnostics))
            assert process.poll() is None
            user.PostMessageW(tray, 0x401, tray, 0x201)  # tray mouse down
            user.PostMessageW(tray, 0x401, tray, 0x202)  # single mouse up
            wait_for(lambda: user.IsWindowVisible(window), 'Single tray click did not restore the main window')
            wait_for(lambda: tray_handle(process.pid) is None, 'Tray icon not removed after restoration')
            if maximized:
                assert user.IsZoomed(window), 'Maximized state was lost during tray restoration'
        user.PostMessageW(window, 0x112, 0xF060, 0)  # title-bar SC_CLOSE
        assert process.wait(timeout=15) == 0, 'Close must terminate the process completely'
        assert tray_handle(process.pid) is None
        report = {'status': 'PASS', 'minimize_to_tray': True, 'single_click_restore': True,
                  'maximized_state_preserved': True, 'close_terminates_process': True, 'profile': str(PROFILE)}
        (ROOT / 'build/tray-window-summary.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        print('PASS: minimize -> real tray icon -> single click restore; maximized state; close terminates process')
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(5)
    source = Path((ROOT / 'build/persistence-profile.path').read_text(encoding='utf-8-sig'))
    stored_profile = PROFILE / 'with-task'
    stored_profile.mkdir()
    for folder in ('Tasks', 'Resume'):
        shutil.copytree(source / folder, stored_profile / folder)
    process = subprocess.Popen([str(ROOT / 'bin/Win64/otorrent.exe')], cwd=ROOT,
                               env=dict(os.environ, OT_PROFILE_DIR=str(stored_profile)))
    try:
        window = wait_for(lambda: next((h for h, name in windows(process.pid) if name == 'TFormMain'), None),
                          'Restored-task main window not created')
        wait_for(lambda: user.IsWindowVisible(window), 'Restored-task window not visible')
        user.PostMessageW(window, 0x112, 0xF020, 0)
        wait_for(lambda: tray_handle(process.pid), 'Restored-task tray icon missing')
        user.PostMessageW(window, 0x112, 0xF060, 0)
        # ContinueClosing has two separate 15-second resume deadlines. Wait for
        # that documented budget plus disk/thread cleanup, not less than it.
        closing_started = time.monotonic()
        assert process.wait(timeout=45) == 0, 'Close from tray must finish resume saving and terminate'
        row = task_rows(stored_profile, 'running', 'length(resume)')[0]
        assert row[0] == 0 and row[1] > 0, row
        report['close_with_task_saves_resume'] = True
        report['shutdown_with_task_seconds'] = round(time.monotonic()-closing_started, 2)
        (ROOT / 'build/tray-window-summary.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        print('PASS: close while in tray with a restored task saves resume and terminates completely')
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(5)


if __name__ == '__main__':
    main()
