"""Duplicate confirmation, live tracker merge, persistence and About in both languages."""
import ctypes as c
from ctypes import wintypes as w
import hashlib,json,os,re,subprocess,threading,time,uuid
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit
from release_integration import user,form,wait_for,enumerate_windows,click,edit_text,text
from profile_json import tasks
user.SetProcessDPIAware()

ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/'build'/('duplicate-menus-'+uuid.uuid4().hex);RUN.mkdir()
observed=[]
def bencode(value):
    if isinstance(value,int):return b'i'+str(value).encode()+b'e'
    if isinstance(value,bytes):return str(len(value)).encode()+b':'+value
    if isinstance(value,list):return b'l'+b''.join(bencode(item) for item in value)+b'e'
    return b'd'+b''.join(bencode(key)+bencode(value[key]) for key in sorted(value))+b'e'

class Tracker(BaseHTTPRequestHandler):
    def do_GET(self):
        observed.append(self.path)
        if parse_qs(urlsplit(self.path).query).get('kind')==['old']:
            self.send_error(503);return
        body=bencode({b'interval':60,b'peers':b'',b'complete':0,b'incomplete':0})
        self.send_response(200);self.send_header('Content-Length',str(len(body)))
        self.end_headers();self.wfile.write(body)
    def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),Tracker)
threading.Thread(target=server.serve_forever,daemon=True).start()
user.GetDlgItem.argtypes=[w.HWND,c.c_int];user.GetDlgItem.restype=w.HWND
user.GetMenuState.argtypes=[w.HMENU,w.UINT,w.UINT];user.GetMenuState.restype=w.UINT
user.GetMenuStringW.argtypes=[w.HMENU,w.UINT,w.LPWSTR,c.c_int,w.UINT]
user.SendMessageW.argtypes=[w.HWND,w.UINT,w.WPARAM,w.LPARAM]
kernel=c.WinDLL('kernel32',use_last_error=True)
kernel.OpenProcess.argtypes=[w.DWORD,w.BOOL,w.DWORD];kernel.OpenProcess.restype=w.HANDLE
kernel.VirtualAllocEx.argtypes=[w.HANDLE,c.c_void_p,c.c_size_t,w.DWORD,w.DWORD];kernel.VirtualAllocEx.restype=c.c_void_p
kernel.ReadProcessMemory.argtypes=[w.HANDLE,c.c_void_p,c.c_void_p,c.c_size_t,c.c_void_p]
kernel.VirtualFreeEx.argtypes=[w.HANDLE,c.c_void_p,c.c_size_t,w.DWORD]
kernel.CloseHandle.argtypes=[w.HANDLE]

def popup(pid):
    return next((h for h,owner,cls in enumerate_windows() if owner==pid and
                 cls in ('#32770','TMessageForm') and user.IsWindowVisible(h)),None)

def answer(pid,value):
    dialog=wait_for(lambda:popup(pid),'Duplicate notification missing')
    control=user.GetDlgItem(dialog,value)
    if not control:
        names={1:('ok','гаразд'),6:('yes','так'),7:('no','ні')}[value]
        control=next((h for h,_,cls in enumerate_windows(dialog) if cls in ('Button','TButton')
                      and text(h).replace('&','').lower() in names),None)
    assert control,('Missing message button',value)
    user.PostMessageW(control,0xF5,0,0)
    wait_for(lambda:not popup(pid),'Duplicate notification did not close')

def toolbar_click(pid,window,index):
    toolbar=next(h for h,_,cls in enumerate_windows(window) if cls=='TToolBar')
    handle=kernel.OpenProcess(0x38,False,pid);assert handle
    memory=kernel.VirtualAllocEx(handle,None,c.sizeof(w.RECT),0x3000,4);assert memory
    rectangle=w.RECT()
    try:
        assert user.SendMessageW(toolbar,0x41D,index,memory)
        assert kernel.ReadProcessMemory(handle,memory,c.byref(rectangle),c.sizeof(rectangle),None)
    finally:kernel.VirtualFreeEx(handle,memory,0,0x8000);kernel.CloseHandle(handle)
    point=((rectangle.left+rectangle.right)//2)|(((rectangle.top+rectangle.bottom)//2)<<16)
    user.PostMessageW(toolbar,0x200,0,point);user.PostMessageW(toolbar,0x201,1,point)
    time.sleep(.1);user.PostMessageW(toolbar,0x202,0,point)

results=[]
try:
    for language in ('uk-UA','en-US'):
        profile=RUN/language;profile.mkdir();download=profile/'downloads'
        (profile/'settings.json').write_text(json.dumps({'schemaVersion':1,
            'interfaceLanguage':language,'addingFolder':str(download),
            'addingStartImmediately':False,'addingShowDialog':True}),encoding='utf-8')
        env=dict(os.environ,OT_PROFILE_DIR=str(profile));exe=str(ROOT/'bin/Win64/otorrent.exe')
        payload=b'only-torrent-duplicate-test'
        info={b'name':b'duplicate.bin',b'length':len(payload),b'piece length':16384,
              b'pieces':hashlib.sha1(payload).digest(),b'private':1}
        # Upstream SSRF protection only permits /announce on loopback.
        base=f'http://127.0.0.1:{server.server_port}/announce?language={language}'
        old,new=base+'&kind=old',base+'&kind=new&passkey=AbC%2B123'
        first=profile/'first.torrent';second=profile/'different-name.torrent'
        first.write_bytes(bencode({b'announce':old.encode(),b'info':info}))
        second.write_bytes(bencode({b'announce':old.encode(),b'announce-list':[[old.encode(),new.encode(),new.encode()]],b'info':info}))
        process=subprocess.Popen([exe,'--open',str(first)],cwd=ROOT,env=env)
        try:
            window=wait_for(lambda:form(process.pid,'TFormMain'),'Main form missing')
            dialog=wait_for(lambda:form(process.pid,'TFormAddTorrent'),'Initial add dialog missing')
            click(dialog,'Завантажити пізніше' if language=='uk-UA' else 'Download later')
            wait_for(lambda:len(tasks(profile))==1,'Initial task not saved')
            initial=tasks(profile)[0];stable_id=initial['id']
            def reopen():
                assert subprocess.run([exe,'--open',str(second)],cwd=ROOT,env=env,timeout=12).returncode==0
            reopen();answer(process.pid,7)
            assert tasks(profile)[0]['details']['trackers']==[old],'Declining changed the trackers'
            reopen();answer(process.pid,6)
            wait_for(lambda:tasks(profile)[0]['details']['trackers']==[old,new],
                     'Confirmed trackers were not saved')
            saved=tasks(profile)[0]
            assert len(tasks(profile))==1 and saved['id']==stable_id
            assert saved['details']['trackers']==[old,new],saved['details']['trackers']
            assert not saved['running'] and saved['details']['files']==initial['details']['files']
            time.sleep(.3);assert not any(language in path for path in observed),'Merging started a paused task'
            reopen();answer(process.pid,1)
            assert tasks(profile)[0]['details']['trackers']==[old,new],'Repeated merge duplicated a URL'
            menu=user.GetMenu(window)
            for index,key in enumerate('FSVH'):
                caption=c.create_unicode_buffer(256)
                user.GetMenuStringW(menu,index,caption,len(caption),0x400)
                assert re.search('&'+key,caption.value,re.I),(language,caption.value,key)
            help_menu=user.GetSubMenu(menu,3)
            assert user.GetMenuState(help_menu,1,0x400)&3,'Help must be disabled'
            user.PostMessageW(window,0x111,user.GetMenuItemID(help_menu,0),0)
            about=wait_for(lambda:form(process.pid,'TFormAbout'),'About dialog missing')
            memo=next(h for h,_,cls in enumerate_windows(about) if cls=='TMemo')
            description=edit_text(memo)
            version=json.loads((ROOT/'version.json').read_text(encoding='utf-8-sig'))
            number='.'.join(str(version[key]) for key in ('major','minor','release','build'))
            assert number in description and ('Версія:' if language=='uk-UA' else 'Version:') in description
            assert ('Version:' if language=='uk-UA' else 'Версія:') not in description,'About mixed both languages'
            click(about,'Закрити' if language=='uk-UA' else 'Close')
            wait_for(lambda:not form(process.pid,'TFormAbout'),'About dialog stayed open')
            torrent_list=next(h for h,_,cls in enumerate_windows(window) if cls=='TListView')
            assert user.SendMessageW(torrent_list,0x1032,0,0)==1,'Task selection was lost before Start'
            toolbar_click(process.pid,window,4)
            wait_for(lambda:tasks(profile)[0]['running'],'Start button did not start the selected task')
            try:
                wait_for(lambda:any(path.startswith('/announce?language='+language+'&kind=new&') for path in observed),
                         'The newly merged tracker was not applied to the running engine',seconds=25)
            except AssertionError:
                print('Tracker requests:',observed,flush=True)
                print('Task:',tasks(profile),flush=True)
                for control,_,cls in enumerate_windows(window):
                    if cls=='TMemo':print('Log:',edit_text(control),flush=True)
                raise
            toolbar_click(process.pid,window,5)
            wait_for(lambda:not tasks(profile)[0]['running'],'Task did not pause')
            user.PostMessageW(window,0x10,0,0);assert process.wait(45)==0
            process=subprocess.Popen([exe],cwd=ROOT,env=env)
            window=wait_for(lambda:form(process.pid,'TFormMain'),'Restarted main form missing')
            wait_for(lambda:user.IsWindowVisible(window),'Restarted window not visible')
            assert tasks(profile)[0]['details']['trackers']==[old,new]
            assert not tasks(profile)[0]['running']
            user.PostMessageW(window,0x10,0,0);assert process.wait(45)==0
            results.append({'language':language,'status':'PASS','stable_id':stable_id,
                            'live_tracker':True,'restart':True,'about':True})
            print('PASS:',language,'duplicate decline/merge/no-new, live tracker, restart, menus, About',flush=True)
        finally:
            if process.poll() is None:process.kill();process.wait(5)
finally:server.shutdown();server.server_close()
(ROOT/'build/duplicate-menus-summary.json').write_text(json.dumps({'status':'PASS','root':str(RUN),'cases':results},indent=2),encoding='utf-8')
