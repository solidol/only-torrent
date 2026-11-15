"""Run actual VCL startup/shutdown in isolated profiles, never the user's profile."""
import ctypes as c
import json
import os
from pathlib import Path
import shutil
from profile_json import rows as task_rows, tasks
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
    rows = task_rows(profile, 'running', 'length(resume)', 'updated_utc')
    assert len(rows) == 1
    return rows[0]

first = run(PROFILE, '--restore-test')
second = run(PROFILE, '--restore-test')
assert first[0] == second[0] == 0 and first[1] > 0 and second[1] > 0

for case in ('missing-disk', 'missing-torrent', 'bad-resume'):
    target = ROOT / 'build' / ('restart-' + case + '-' + uuid.uuid4().hex)
    target.mkdir()
    for folder in ('Tasks', 'Resume'):
        shutil.copytree(PROFILE / folder, target / folder)
    path = next((target / 'Tasks').glob('*.json'))
    task = json.loads(path.read_text(encoding='utf-8-sig'))
    if case == 'missing-disk':
        missing = target / 'unavailable-disk' / 'downloads'
        task['savePath'] = str(missing)
    elif case == 'missing-torrent':
        task['torrentFile'] = str(target / 'absent.torrent')
    else:
        (target / 'Resume' / task['resumeFile']).write_bytes(b'corrupt bencode')
    path.write_text(json.dumps(task), encoding='utf-8')
    row = run(target, '--restore-test' if case == 'bad-resume' else '--restore-unavailable')
    assert row[0] == 0
    if case == 'missing-disk':
        assert not missing.exists(), 'Application must not create or substitute an unavailable disk'

# Incomplete temp files are never published; the last committed task remains.
target = ROOT / 'build' / ('restart-crash-' + uuid.uuid4().hex)
target.mkdir()
for folder in ('Tasks', 'Resume'):
    shutil.copytree(PROFILE / folder, target / folder)
path = next((target / 'Tasks').glob('*.json'))
Path(str(path) + '.interrupted.tmp').write_bytes(b'{"schemaVersion":1,')
run(target, '--restore-test')
# Corrupt primary recovers from the complete backup.
path.write_bytes(b'{broken')
run(target, '--restore-test')
print('PASS: two restarts, graceful resume, missing disk/torrent, corrupt resume, interrupted JSON write, backup recovery')
