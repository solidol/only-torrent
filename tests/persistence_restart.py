"""Run actual VCL startup/shutdown in isolated profiles, never the user's profile."""
import ctypes as c
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = Path(os.environ.get('OT_ENGINE_DIR', ROOT / 'bin/Win64')).resolve()
PROFILE = Path((ROOT / 'build/persistence-profile.path').read_text(encoding='utf-8-sig'))

def run(profile, mode):
    env = dict(os.environ, OT_PROFILE_DIR=str(profile))
    flags = subprocess.STARTUPINFO()
    flags.dwFlags = subprocess.STARTF_USESHOWWINDOW
    flags.wShowWindow = 0
    result = subprocess.run([str(PACKAGE / 'OtUiSmoke.exe'), mode], cwd=ROOT / 'tests',
                            env=env, startupinfo=flags, timeout=45)
    assert result.returncode == 0, (mode, (ROOT / 'build/ui-smoke.txt').read_text(encoding='utf-8-sig'))
    with sqlite3.connect(profile / 'tasks.db') as db:
        assert db.execute('PRAGMA quick_check').fetchone()[0] == 'ok'
        assert db.execute('SELECT count(*) FROM tasks').fetchone()[0] == 1
        return db.execute('SELECT running,length(resume),updated_utc FROM tasks').fetchone()

first = run(PROFILE, '--restore-test')
second = run(PROFILE, '--restore-test')
assert first[0] == second[0] == 0 and first[1] > 0 and second[1] > 0

for case in ('missing-disk', 'missing-torrent', 'bad-resume'):
    target = ROOT / 'build' / ('restart-' + case + '-' + uuid.uuid4().hex)
    target.mkdir()
    with sqlite3.connect(PROFILE / 'tasks.db') as src, sqlite3.connect(target / 'tasks.db') as dst:
        src.backup(dst)
        if case == 'missing-disk':
            missing = target / 'unavailable-disk' / 'downloads'
            dst.execute('UPDATE tasks SET save_path=?', (str(missing),))
        elif case == 'missing-torrent':
            dst.execute('UPDATE tasks SET torrent_file=?', (str(target / 'absent.torrent'),))
        else:
            dst.execute('UPDATE tasks SET resume=?', (b'corrupt bencode',))
    row = run(target, '--restore-test' if case == 'bad-resume' else '--restore-unavailable')
    assert row[0] == 0
    if case == 'missing-disk':
        assert not missing.exists(), 'Application must not create or substitute an unavailable disk'

# Kill an uncommitted SQLite writer, then verify the last committed task survives.
target = ROOT / 'build' / ('restart-crash-' + uuid.uuid4().hex)
target.mkdir()
with sqlite3.connect(PROFILE / 'tasks.db') as src, sqlite3.connect(target / 'tasks.db') as dst:
    src.backup(dst)
child = subprocess.Popen([sys.executable, '-u', '-c',
    "import sqlite3,sys,time; d=sqlite3.connect(sys.argv[1]); d.execute('BEGIN IMMEDIATE'); "
    "d.execute('DELETE FROM tasks'); print('ready',flush=True); time.sleep(30)",
    str(target / 'tasks.db')], stdout=subprocess.PIPE, text=True)
try:
    assert child.stdout.readline().strip() == 'ready'
finally:
    child.kill()
    child.wait(timeout=5)
run(target, '--restore-test')
print('PASS: two application restarts, graceful resume save, missing disk, missing metadata, corrupt resume, interrupted SQLite transaction')
