"""Check the actual installed updater relocates itself even with explicit --target."""
import ctypes as c
from ctypes import wintypes as w
import hashlib,os,shutil,subprocess,time,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/'build'/('updater-detach-'+uuid.uuid4().hex);RUN.mkdir()
shutil.copyfile(ROOT/'bin/Win64/otupdater.exe',RUN/'otupdater.exe')
shutil.copyfile(ROOT/'build/update-old-fixture/otorrent.exe',RUN/'otorrent.exe')
shutil.copytree(ROOT/'Languages',RUN/'Languages')
expected=hashlib.sha256((RUN/'otupdater.exe').read_bytes()).hexdigest()
k=c.WinDLL('kernel32',use_last_error=True);u=c.WinDLL('user32',use_last_error=True)
class Entry(c.Structure):
 _fields_=[('size',w.DWORD),('usage',w.DWORD),('pid',w.DWORD),('heap',c.c_size_t),('module',w.DWORD),('threads',w.DWORD),('parent',w.DWORD),('priority',w.LONG),('flags',w.DWORD),('name',w.WCHAR*260)]
k.CreateToolhelp32Snapshot.argtypes=[w.DWORD,w.DWORD];k.CreateToolhelp32Snapshot.restype=w.HANDLE
k.Process32FirstW.argtypes=[w.HANDLE,c.POINTER(Entry)];k.Process32NextW.argtypes=[w.HANDLE,c.POINTER(Entry)]
k.CloseHandle.argtypes=[w.HANDLE];k.OpenProcess.argtypes=[w.DWORD,w.BOOL,w.DWORD];k.OpenProcess.restype=w.HANDLE
k.QueryFullProcessImageNameW.argtypes=[w.HANDLE,w.DWORD,w.LPWSTR,c.POINTER(w.DWORD)]
k.WaitForSingleObject.argtypes=[w.HANDLE,w.DWORD];k.TerminateProcess.argtypes=[w.HANDLE,w.UINT]
callback=c.WINFUNCTYPE(w.BOOL,w.HWND,w.LPARAM);u.EnumWindows.argtypes=[callback,w.LPARAM]
u.GetWindowThreadProcessId.argtypes=[w.HWND,c.POINTER(w.DWORD)];u.GetClassNameW.argtypes=[w.HWND,w.LPWSTR,c.c_int]
u.PostMessageW.argtypes=[w.HWND,w.UINT,w.WPARAM,w.LPARAM]
def children(parent):
 snapshot=k.CreateToolhelp32Snapshot(2,0);entry=Entry();entry.size=c.sizeof(entry);result=[]
 try:
  ok=k.Process32FirstW(snapshot,c.byref(entry))
  while ok:
   if entry.parent==parent and entry.name.lower()=='otupdater.exe':result.append(entry.pid)
   ok=k.Process32NextW(snapshot,c.byref(entry))
 finally:k.CloseHandle(snapshot)
 return result
parent=subprocess.Popen([str(RUN/'otupdater.exe'),'--target',str(RUN),'--language','en-US'],cwd=RUN)
child=None;handle=None
try:
 deadline=time.monotonic()+20
 while time.monotonic()<deadline:
  found=children(parent.pid)
  if found:child=found[0];break
  time.sleep(.1)
 assert child,'No detached child updater'
 assert parent.wait(timeout=30)==0,'Installed updater did not exit'
 handle=k.OpenProcess(0x1000|0x100000|1,False,child);assert handle
 name=c.create_unicode_buffer(32768);size=w.DWORD(32768)
 assert k.QueryFullProcessImageNameW(handle,0,name,c.byref(size))
 executable=Path(name.value)
 assert executable!=RUN/'otupdater.exe' and executable.parent.name.startswith('OnlyTorrent-Updater-'),executable
 assert hashlib.sha256(executable.read_bytes()).hexdigest()==expected
 window=None;deadline=time.monotonic()+15
 while time.monotonic()<deadline and window is None:
  @callback
  def visit(h,_):
   global window
   pid=w.DWORD();u.GetWindowThreadProcessId(h,c.byref(pid));cls=c.create_unicode_buffer(256);u.GetClassNameW(h,cls,256)
   if pid.value==child and cls.value=='TFormUpdater':window=h
   return True
  u.EnumWindows(visit,0);time.sleep(.1)
 assert window,'Detached updater window missing'
 # The destination updater can be opened exclusively while its temporary copy runs.
 k.CreateFileW.argtypes=[w.LPCWSTR,w.DWORD,w.DWORD,c.c_void_p,w.DWORD,w.DWORD,w.HANDLE];k.CreateFileW.restype=w.HANDLE
 probe=k.CreateFileW(str(RUN/'otupdater.exe'),0x80000000|0x40000000,0,None,3,0,None)
 assert probe not in (None,c.c_void_p(-1).value),c.get_last_error()
 k.CloseHandle(probe)
 u.PostMessageW(window,0x10,0,0)
 assert k.WaitForSingleObject(handle,30000)==0,'Updater did not close after cancelling its check'
 assert not (RUN/'.ot-update.pending').exists()
 print('PASS: explicit --target detaches, original exits, temporary copy is byte-exact, installed EXE is unlocked, only the owned window closes')
finally:
 if parent.poll() is None:
  parent.kill()
  try:parent.wait(timeout=10)
  except subprocess.TimeoutExpired:pass
 if handle:
  if k.WaitForSingleObject(handle,0)!=0:k.TerminateProcess(handle,1)
  k.CloseHandle(handle)
