"""First-use toolbar input and real screen capture; private profile, own PID only."""
import ctypes as c
from ctypes import wintypes as w
import json,os,subprocess,time,uuid
from pathlib import Path
from PIL import ImageGrab
from release_integration import user,form,wait_for,enumerate_windows
user.SetProcessDPIAware()

ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/'build'/('interface-native-'+uuid.uuid4().hex);RUN.mkdir()
PROFILE=RUN/'profile';PROFILE.mkdir()
settings=PROFILE/'settings.json'
settings.write_text(json.dumps({'schemaVersion':1,'interfaceDarkTheme':False,
 'interfaceLanguage':'en-US'}),encoding='utf-8')
user.GetWindowRect.argtypes=[w.HWND,c.POINTER(w.RECT)]
user.SetWindowPos.argtypes=[w.HWND,w.HWND,c.c_int,c.c_int,c.c_int,c.c_int,w.UINT]
user.WindowFromPoint.argtypes=[w.POINT];user.WindowFromPoint.restype=w.HWND
user.GetAncestor.argtypes=[w.HWND,w.UINT];user.GetAncestor.restype=w.HWND
user.GetDpiForWindow.argtypes=[w.HWND];user.GetDpiForWindow.restype=w.UINT
user.SendMessageW.argtypes=[w.HWND,w.UINT,w.WPARAM,w.LPARAM]
k=c.WinDLL('kernel32',use_last_error=True)
k.OpenProcess.argtypes=[w.DWORD,w.BOOL,w.DWORD];k.OpenProcess.restype=w.HANDLE
k.VirtualAllocEx.argtypes=[w.HANDLE,c.c_void_p,c.c_size_t,w.DWORD,w.DWORD];k.VirtualAllocEx.restype=c.c_void_p
k.ReadProcessMemory.argtypes=[w.HANDLE,c.c_void_p,c.c_void_p,c.c_size_t,c.c_void_p]
k.VirtualFreeEx.argtypes=[w.HANDLE,c.c_void_p,c.c_size_t,w.DWORD]
k.CloseHandle.argtypes=[w.HANDLE]
process=subprocess.Popen([str(ROOT/'bin/Win64/otorrent.exe')],cwd=ROOT,
 env=dict(os.environ,OT_PROFILE_DIR=str(PROFILE)))
report=[]
try:
 window=wait_for(lambda:form(process.pid,'TFormMain'),'Main window missing')
 wait_for(lambda:user.IsWindowVisible(window),'Main window not shown')
 toolbar=next(h for h,_,cls in enumerate_windows(window) if cls=='TToolBar')
 scale=user.GetDpiForWindow(window)/96
 def click_theme():
  handle=k.OpenProcess(0x38,False,process.pid);assert handle
  address=k.VirtualAllocEx(handle,None,c.sizeof(w.RECT),0x3000,4);assert address
  rectangle=w.RECT()
  try:
   assert user.SendMessageW(toolbar,0x41D,7,address),'Theme button rectangle unavailable'
   assert k.ReadProcessMemory(handle,address,c.byref(rectangle),c.sizeof(rectangle),None)
  finally:k.VirtualFreeEx(handle,address,0,0x8000);k.CloseHandle(handle)
  coordinate=((rectangle.left+rectangle.right)//2)|(((rectangle.top+rectangle.bottom)//2)<<16)
  user.PostMessageW(toolbar,0x200,0,coordinate)
  user.PostMessageW(toolbar,0x201,1,coordinate)
  time.sleep(.1)
  user.PostMessageW(toolbar,0x202,0,coordinate)
 def dark():
  return json.loads(settings.read_text(encoding='utf-8-sig'))['interfaceDarkTheme']
 click_theme()
 try:
  wait_for(dark,'First toolbar theme click did not work before any menu opened',seconds=5)
  report.append('PASS: first toolbar click switches to dark before opening any menu')
 except AssertionError as e:report.append('FAIL: '+str(e))
 time.sleep(.3)  # JSON is saved before the queued style broadcasts finish.
 window=wait_for(lambda:form(process.pid,'TFormMain'),'Main window lost after style change')
 user.SetWindowPos(window,w.HWND(-1),12,12,0,0,0x11)
 rectangle=w.RECT();assert user.GetWindowRect(window,c.byref(rectangle))
 assert user.GetAncestor(user.WindowFromPoint(w.POINT(rectangle.left+5,rectangle.top+5)),2)==window, 'Test window is obscured; refusing to capture another app'
 ImageGrab.grab(bbox=(rectangle.left,rectangle.top,rectangle.right,rectangle.bottom)).save(RUN/'first-theme.png')
 user.SetWindowPos(window,w.HWND(-2),0,0,0,0,0x13)
 if dark():
  # Theme switch can recreate native handles; query again before the second click.
  toolbar=next(h for h,_,cls in enumerate_windows(window) if cls=='TToolBar')
  click_theme()
  try:
   wait_for(lambda:not dark(),'Toolbar return to light failed',seconds=5)
   report.append('PASS: second toolbar click returns to light')
  except AssertionError as e:report.append('FAIL: '+str(e))
 time.sleep(.3)
 window=wait_for(lambda:form(process.pid,'TFormMain'),'Main window lost on return to light')
 user.PostMessageW(window,0x10,0,0)
 assert process.wait(25)==0
finally:
 if process.poll() is None:process.kill();process.wait(5)
(RUN/'report.txt').write_text('\n'.join(report),encoding='utf-8')
(ROOT/'build/interface-native.path').write_text(str(RUN),encoding='utf-8')
print('\n'.join(report));print('Screenshots:',RUN)
raise SystemExit(any(line.startswith('FAIL:') for line in report))
