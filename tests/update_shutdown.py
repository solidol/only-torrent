"""Only synthetic clients in isolated directories receive WM_CLOSE."""
import ctypes as c
from ctypes import wintypes as w
from pathlib import Path
import shutil
import subprocess
import time
import uuid
import os

root = Path(__file__).resolve().parents[1]
run = root / 'build' / ('shutdown-test-' + uuid.uuid4().hex)
core = root / 'bin/Win64/OtCoreTests.exe'
user = c.WinDLL('user32', use_last_error=True)
callback = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
user.EnumWindows.argtypes = [callback, w.LPARAM]
user.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]
user.GetClassNameW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
children = []

def fixture(folder, mode):
    folder.mkdir(parents=True, exist_ok=True)
    exe = folder / 'otorrent.exe'
    if not exe.exists():
        shutil.copy2(core, exe)
    proc = subprocess.Popen([str(exe), '--shutdown-fixture', mode], cwd=folder,
                            creationflags=subprocess.CREATE_NO_WINDOW)
    children.append(proc)
    for _ in range(100):
        found = []
        @callback
        def visit(hwnd, _):
            pid = w.DWORD()
            user.GetWindowThreadProcessId(hwnd, c.byref(pid))
            name = c.create_unicode_buffer(256)
            user.GetClassNameW(hwnd, name, 256)
            if pid.value == proc.pid and name.value == 'TFormMain':
                found.append(hwnd)
            return True
        user.EnumWindows(visit, 0)
        if found:
            return proc
        assert proc.poll() is None, ('Fixture exited', proc.returncode)
        time.sleep(.05)
    raise AssertionError('Fixture window timeout')

def close(folder, timeout):
    return subprocess.run([str(core), '--close-client', str(folder), str(timeout)],
                          cwd=root / 'tests', timeout=15,
                          creationflags=subprocess.CREATE_NO_WINDOW).returncode

try:
    a = fixture(run / 'target', 'accept')
    other = fixture(run / 'other', 'accept')
    assert close(run / 'target', 3000) == 0
    assert a.wait(timeout=5) == 0
    assert other.poll() is None, 'Another installation was closed'
    refusing = fixture(run / 'target', 'refuse')
    assert close(run / 'target', 250) == 2, 'Refused close must report a recoverable failure'
    assert refusing.poll() is None, 'A refusing client must not be terminated'
    assert other.poll() is None
    # Also exercise the real VCL client, using a copied runtime and private profile.
    actual = run / 'actual'
    shutil.copytree(root / 'bin/Win64', actual)
    profile = run / 'actual-profile'
    client = subprocess.Popen([str(actual / 'otorrent.exe')], cwd=run,
                              env=dict(os.environ, OT_PROFILE_DIR=str(profile)),
                              creationflags=subprocess.CREATE_NO_WINDOW)
    children.append(client)
    for _ in range(100):
        assert client.poll() is None, 'Real client exited before the close request'
        if (profile / 'tasks.db').exists():
            break
        time.sleep(.05)
    else:
        raise AssertionError('Real client profile initialization timeout')
    assert close(actual, 10000) == 0
    assert client.wait(timeout=5) == 0
    assert (profile / 'tasks.db').exists(), 'Profile lost while closing for update'
    print('PASS: graceful WM_CLOSE, exact installation matching, refusal timeout, no forced termination')
finally:
    for proc in children:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=5)
