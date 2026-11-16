"""Explicit complete local regression pass; never invoked by a normal build."""
import argparse,json,os,subprocess,sys,time,uuid
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--package',required=True,type=Path)
parser.add_argument('--installer',required=True,type=Path)
args=parser.parse_args()
RUN=ROOT/'build'/('full-validation-'+uuid.uuid4().hex);RUN.mkdir()
env=dict(os.environ,PYTHONIOENCODING='utf-8',OT_ENGINE_DIR=str(ROOT/'bin/Win64'),
 OT_TEST_PACKAGE=str(args.package.resolve()),OT_PROFILE_DIR=str(RUN/'profile'))
cases=[]
def python(name,*extra):
 cases.append((name, [sys.executable,str(ROOT/'tests'/(name+'.py')),*extra],ROOT,None))
for name in ('project_structure','languages','separation','upstream_integrity'):python(name)
cases.append(('Core',[str(ROOT/'bin/Win64/OtCoreTests.exe')],ROOT/'tests','core-tests.txt'))
cases.append(('UI',[str(ROOT/'bin/Win64/OtUiSmoke.exe')],ROOT/'tests','ui-smoke.txt'))
for name in ('interface_audit','interface_native','engine_smoke','network_transfer','add_options','block_map','upload_total',
             'batch_tasks','torrent_sources','persistence_restart','tray_window','bitcomet_import',
             'release_integration','update_shutdown','updater_detach','update_restart'):python(name)
cases.append(('network_transfer_udp',[sys.executable,str(ROOT/'tests/network_transfer.py'),'--udp'],ROOT,None))
cases.append(('MSI',['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',
 str(ROOT/'tests/msi_choices.ps1'),'-Installer',str(args.installer.resolve())],ROOT,None))
results=[]
for name,command,cwd,report in cases:
 start=time.monotonic();print('RUN:',name,flush=True)
 try:
  result=subprocess.run(command,cwd=cwd,env=env,capture_output=True,timeout=180)
  output=result.stdout.decode('utf-8','replace')+result.stderr.decode('utf-8','replace')
  if report:output+='\n'+(ROOT/'build'/report).read_text(encoding='utf-8-sig')
  code=result.returncode
 except subprocess.TimeoutExpired as error:
  code=-1;output='TIMEOUT: '+str(error)
 (RUN/(name+'.txt')).write_text(output,encoding='utf-8')
 row=dict(name=name,status='PASS' if code==0 else 'FAIL',exit_code=code,
          seconds=round(time.monotonic()-start,2),log=str(RUN/(name+'.txt')))
 results.append(row);print(row['status']+': '+name,flush=True)
 if code:print(output[-5000:],flush=True)
 (RUN/'results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
summary=dict(status='PASS' if all(r['status']=='PASS' for r in results) else 'FAIL',
 version=json.loads((ROOT/'version.json').read_text(encoding='utf-8-sig')),
 cases=results,root=str(RUN))
(ROOT/'build/full-validation-summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps(summary,indent=2),flush=True)
raise SystemExit(summary['status']!='PASS')
