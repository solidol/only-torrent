"""Run batch UI workflows using private synthetic torrents in isolated profiles."""
import hashlib
import json
import os
from pathlib import Path
from profile_json import rows as task_rows
import subprocess
import sys
import uuid
import xml.etree.ElementTree as ET
from engine_common import bencode

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / 'build' / ('batch-tests-' + uuid.uuid4().hex)


def fixture(root):
    (root / 'Torrents').mkdir(parents=True)
    data = root / 'data'
    data.mkdir()
    (data / 'unrelated.txt').write_text('Keep this file', encoding='utf-8')
    xml = ET.Element('BitComet')
    tasks = ET.SubElement(xml, 'Torrents')
    for index, name in enumerate(['one.bin', 'two.bin']):
        good = bytes([65 + index]) * 16384
        second = bytes([75 + index]) * 16384
        info = {b'name': name.encode(), b'length': 32768, b'piece length': 16384,
                b'pieces': hashlib.sha1(good).digest() + hashlib.sha1(second).digest(), b'private': 1}
        (data / name).write_bytes(good + b'X' * 16384)  # one valid and one corrupt piece
        torrent = root / 'Torrents' / (name + '.torrent')
        torrent.write_bytes(bencode({b'info': info}))
        ET.SubElement(tasks, 'Torrent', InfoHashHex=hashlib.sha1(bencode(info)).hexdigest(),
                      Torrent=torrent.name, TorrentFile='Torrents\\' + torrent.name,
                      SaveDirectory=str(data), SaveName=name, SaveLocation=str(data / name), ShowName=name)
        details = ET.Element('BitComet')
        files = ET.SubElement(details, 'FileList', StandAlone='true', BaseName=name)
        ET.SubElement(files, 'FileEntry', RelativePathName=name, Size='32768', StartAt='0',
                      Priority='0', WithBCExt='false')
        ET.ElementTree(details).write(torrent.with_suffix('.xml'), encoding='utf-8', xml_declaration=True)
    manifest = root / 'Downloads.xml'
    ET.ElementTree(xml).write(manifest, encoding='utf-8', xml_declaration=True)
    return manifest


def run():
    results = []
    for scenario in (sys.argv[1:] or ['paused', 'verify', 'auto', 'verify-auto', 'start', 'batch']):
        root = RUN / scenario
        source = fixture(root)
        profile = root / 'profile'
        report = root / 'report.json'
        startup = subprocess.STARTUPINFO()
        startup.dwFlags = subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = 0
        try:
            process = subprocess.run([str(ROOT / 'bin/Win64/OtUiSmoke.exe'), '--batch-test',
                                      str(source), str(report), scenario], cwd=ROOT / 'tests',
                                     env=dict(os.environ, OT_PROFILE_DIR=str(profile)), startupinfo=startup,
                                     timeout=60, capture_output=True)
        except subprocess.TimeoutExpired:
            raise AssertionError(f'{scenario}: UI timeout; see {root}')
        assert process.returncode == 0, (scenario, process.returncode,
            (ROOT / 'build/ui-smoke.txt').read_text(encoding='utf-8-sig') if (ROOT / 'build/ui-smoke.txt').exists() else '')
        assert report.with_suffix('.json.result').read_text(encoding='utf-8-sig').strip() == 'PASS: ' + scenario
        rows = task_rows(profile, 'running', 'details')
        if scenario == 'batch':
            assert len(rows) == 0
        else:
            assert len(rows) == 2
            for running, details in rows:
                assert running == int(scenario in ('auto', 'verify-auto', 'start'))
                assert json.loads(details)['needsVerification'] == (scenario == 'paused')
        assert (root / 'data/unrelated.txt').read_text(encoding='utf-8') == 'Keep this file'
        results.append(scenario)
        print('PASS:', scenario, flush=True)
    summary = {'scenarios': results, 'root': str(RUN), 'status': 'PASS'}
    (ROOT / 'build/batch-tests-summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')


if __name__ == '__main__':
    run()
