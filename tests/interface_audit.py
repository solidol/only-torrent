"""All VCL pages, two themes and DPI scales; only an isolated copied task."""
import json,os,shutil,subprocess,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path((ROOT/'build/persistence-profile.path').read_text(encoding='utf-8-sig'))
PROFILE=ROOT/'build'/('interface-audit-'+uuid.uuid4().hex);PROFILE.mkdir()
for folder in ('Tasks','Resume','Torrents'):
 if (SOURCE/folder).is_dir():shutil.copytree(SOURCE/folder,PROFILE/folder)
(PROFILE/'settings.json').write_text(json.dumps({'schemaVersion':1,'interfaceDarkTheme':False,
 'interfaceLanguage':'uk-UA'}),encoding='utf-8')
result=subprocess.run([str(ROOT/'bin/Win64/OtUiSmoke.exe'),'--interface-audit'],
 cwd=ROOT/'tests',env=dict(os.environ,OT_PROFILE_DIR=str(PROFILE)),timeout=120)
report=(ROOT/'build/interface-audit.txt').read_text(encoding='utf-8-sig')
print('\n'.join(line for line in report.splitlines() if line.startswith(('FAIL:','Failures:'))))
print('Checks:',sum(line.startswith('PASS:') for line in report.splitlines()))
raise SystemExit(result.returncode)
