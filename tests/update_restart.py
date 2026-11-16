"""Real updater UI pipeline in an isolated install, with loopback-free fixture downloads."""
import ctypes as c
from ctypes import wintypes as w
import hashlib,json,os,shutil,subprocess,time,uuid,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PACKAGE=Path(os.environ['OT_TEST_PACKAGE']).resolve()
RUN=ROOT/'build'/('update-restart-'+uuid.uuid4().hex)
TARGET=RUN/'Only Torrent application';STAGE=RUN/'package';TARGET.mkdir(parents=True);STAGE.mkdir()
kernel=c.WinDLL('kernel32',use_last_error=True);user=c.WinDLL('user32',use_last_error=True)
kernel.LoadLibraryExW.argtypes=[w.LPCWSTR,w.HANDLE,w.DWORD];kernel.LoadLibraryExW.restype=w.HMODULE
kernel.FindResourceW.argtypes=[w.HMODULE,c.c_void_p,c.c_void_p];kernel.FindResourceW.restype=w.HANDLE
kernel.SizeofResource.argtypes=[w.HMODULE,w.HANDLE];kernel.SizeofResource.restype=w.DWORD
kernel.LoadResource.argtypes=[w.HMODULE,w.HANDLE];kernel.LoadResource.restype=w.HANDLE
kernel.LockResource.argtypes=[w.HANDLE];kernel.LockResource.restype=c.c_void_p
kernel.FreeLibrary.argtypes=[w.HMODULE]
kernel.BeginUpdateResourceW.argtypes=[w.LPCWSTR,w.BOOL];kernel.BeginUpdateResourceW.restype=w.HANDLE
kernel.UpdateResourceW.argtypes=[w.HANDLE,c.c_void_p,c.c_void_p,w.WORD,c.c_void_p,w.DWORD]
kernel.EndUpdateResourceW.argtypes=[w.HANDLE,w.BOOL]

def attach_version(destination,source):
    module=kernel.LoadLibraryExW(str(source),None,2);assert module,c.get_last_error()
    try:
        resource=kernel.FindResourceW(module,c.c_void_p(1),c.c_void_p(16));assert resource
        data=c.string_at(kernel.LockResource(kernel.LoadResource(module,resource)),kernel.SizeofResource(module,resource))
    finally:kernel.FreeLibrary(module)
    update=kernel.BeginUpdateResourceW(str(destination),False);assert update,c.get_last_error()
    buffer=c.create_string_buffer(data)
    ok=kernel.UpdateResourceW(update,c.c_void_p(16),c.c_void_p(1),0x409,buffer,len(data))
    assert kernel.EndUpdateResourceW(update,not ok),c.get_last_error()
    assert ok,c.get_last_error()

# Reuse real package contents and versions, but replace the application with a harmless test PE.
shutil.copytree(PACKAGE,STAGE,dirs_exist_ok=True)
fixture=ROOT/'build/update-client-fixture/fixture.exe'
shutil.copyfile(fixture,STAGE/'otorrent.exe');attach_version(STAGE/'otorrent.exe',PACKAGE/'otorrent.exe')
manifest=json.loads((STAGE/'release.json').read_text(encoding='utf-8-sig'))
manifest['packageFiles']['otorrent.exe']=hashlib.sha256((STAGE/'otorrent.exe').read_bytes()).hexdigest()
(STAGE/'release.json').write_text(json.dumps(manifest),encoding='utf-8')
version=manifest['version'];archive=RUN/f'Only-Torrent-{version}-Win64.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as package:
    for file in STAGE.rglob('*'):
        if file.is_file():package.write(file,file.relative_to(STAGE).as_posix())
Path(str(archive)+'.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'  '+archive.name+'\n',encoding='ascii')
shutil.copytree(PACKAGE,TARGET,dirs_exist_ok=True)
shutil.copyfile(fixture,TARGET/'otorrent.exe')
attach_version(TARGET/'otorrent.exe',Path(os.environ.get('OT_TEST_OLD_CLIENT',ROOT/'build/update-old-fixture/otorrent.exe')))
old_updater=Path(os.environ.get('OT_TEST_OLD_UPDATER',ROOT/'build/update-old-fixture/otorrent.exe'))
shutil.copyfile(old_updater,TARGET/'otupdater.exe')
old_hash=hashlib.sha256((TARGET/'otupdater.exe').read_bytes()).hexdigest()
(TARGET/'user-data.txt').write_text('keep',encoding='utf-8')

# Only close error confirmations owned by our test process; never interact with user windows.
callback=c.WINFUNCTYPE(w.BOOL,w.HWND,w.LPARAM)
user.EnumWindows.argtypes=[callback,w.LPARAM];user.GetWindowThreadProcessId.argtypes=[w.HWND,c.POINTER(w.DWORD)]
user.GetClassNameW.argtypes=[w.HWND,w.LPWSTR,c.c_int];user.GetDlgItem.argtypes=[w.HWND,c.c_int];user.GetDlgItem.restype=w.HWND
user.PostMessageW.argtypes=[w.HWND,w.UINT,w.WPARAM,w.LPARAM]
user.EnumChildWindows.argtypes=[w.HWND,callback,w.LPARAM]
user.GetWindowTextW.argtypes=[w.HWND,w.LPWSTR,c.c_int]
errors=[]
def acknowledge(pid):
    @callback
    def visit(window,_):
        owner=w.DWORD();user.GetWindowThreadProcessId(window,c.byref(owner))
        if owner.value!=pid:return True
        cls=c.create_unicode_buffer(256);user.GetClassNameW(window,cls,256)
        if cls.value in ('TMessageForm','#32770'):
            @callback
            def confirm(button,_):
                text=c.create_unicode_buffer(256);user.GetWindowTextW(button,text,256)
                if text.value.replace('&','').strip().lower()=='ok':
                    errors.append(cls.value);user.PostMessageW(button,0xF5,0,0)
                return True
            user.EnumChildWindows(window,confirm,0)
        return True
    user.EnumWindows(visit,0)

old=subprocess.Popen([str(TARGET/'otorrent.exe'),'--hold'],cwd=TARGET)
report=RUN/'ui-report.json'
profile=RUN/'profile';env=dict(os.environ,OT_PROFILE_DIR=str(profile))
process=subprocess.Popen([str(ROOT/'bin/Win64/OtUiSmoke.exe'),'--update-fixture',str(TARGET),str(archive),str(report)],cwd=ROOT/'tests',env=env)
try:
    deadline=time.monotonic()+55
    while process.poll() is None and time.monotonic()<deadline:
        acknowledge(process.pid);time.sleep(.1)
    assert process.poll()==0, (process.poll(),errors,str(RUN),(ROOT/'build/ui-smoke.txt').read_text(encoding='utf-8-sig'))
    assert not errors,errors
    assert json.loads(report.read_text(encoding='utf-8-sig'))['closed']
    assert old.wait(timeout=5)==0,'Old client was not closed normally'
    marker=TARGET/'restart-result.json';deadline=time.monotonic()+15
    while not marker.exists() and time.monotonic()<deadline:time.sleep(.1)
    result=json.loads(marker.read_text(encoding='utf-8'))
    assert result['pid'] not in (old.pid,process.pid)
    assert hashlib.sha256((TARGET/'otupdater.exe').read_bytes()).hexdigest()!=old_hash
    assert (TARGET/'otupdater.exe').read_bytes()==(STAGE/'otupdater.exe').read_bytes()
    for name,digest in manifest['packageFiles'].items():
        assert hashlib.sha256((TARGET/name).read_bytes()).hexdigest()==digest,name
    assert (TARGET/'user-data.txt').read_text()=='keep'
    assert not (TARGET/'.ot-update.pending').exists()
    assert not list(TARGET.glob('.ot-update-backup-*'))
    summary={'status':'PASS','version':version,'updater_replaced':True,'old_client_closed':True,'updater_window_closed':True,'restarted_process':result,'root':str(RUN)}
    (ROOT/'build/update-restart-summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps(summary,indent=2))
finally:
    for child in (process,old):
        if child.poll() is None:child.kill();child.wait(timeout=5)
