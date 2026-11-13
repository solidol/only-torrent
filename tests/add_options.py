from engine_common import *

class MetaInfo(c.Structure):
    _fields_=[('total',c.c_int64),('files',c.c_int32),('trackers',c.c_int32),('name',c.c_char*512),('comment',c.c_char*1024)]
class MetaFile(c.Structure):
    _fields_=[('size',c.c_int64),('path',c.c_char*4096)]
assert c.sizeof(MetaInfo)==1552 and c.sizeof(MetaFile)==4104

dll.qs_meta_open.argtypes=[c.c_char_p]; dll.qs_meta_open.restype=c.c_void_p
dll.qs_meta_close.argtypes=[c.c_void_p]
dll.qs_meta_info.argtypes=[c.c_void_p,c.POINTER(MetaInfo)]
dll.qs_meta_file.argtypes=[c.c_void_p,c.c_int,c.POINTER(MetaFile)]
dll.qs_meta_tracker.argtypes=[c.c_void_p,c.c_int,c.c_char_p,c.c_int]
dll.qs_add_selected.argtypes=[c.c_void_p,c.c_char_p,c.c_char_p,c.POINTER(c.c_int),c.c_int,c.c_int]
dll.qs_configure.argtypes=[c.c_void_p,c.c_int,c.c_int,c.c_int,c.c_int]

with tempfile.TemporaryDirectory(prefix='qs-selection-') as tmp:
    root=Path(tmp)
    part_a=b'A'*16384; part_b=b'B'*16384
    info={b'name':'Тестові файли'.encode(),b'piece length':16384,
          b'pieces':hashlib.sha1(part_a).digest()+hashlib.sha1(part_b).digest(),
          b'files':[{b'length':16384,b'path':[b'chosen.bin']},{b'length':16384,b'path':[b'skip.bin']}]}
    torrent=root/'selection.torrent'
    tracker=b'http://127.0.0.1:1/announce'
    torrent.write_bytes(bencode({b'info':info,b'comment':b'preview test',b'announce':tracker}))
    encoded=str(torrent).encode('utf-8')
    handle=dll.qs_meta_open(encoded); assert handle,dll.qs_error()
    try:
        meta=MetaInfo(); assert dll.qs_meta_info(handle,c.byref(meta))==0
        assert (meta.total,meta.files,meta.trackers)==(32768,2,1)
        assert meta.name.decode()=='Тестові файли' and meta.comment==b'preview test'
        file=MetaFile(); assert dll.qs_meta_file(handle,0,c.byref(file))==0
        assert file.size==16384 and file.path.decode().endswith('chosen.bin')
        assert dll.qs_meta_file(handle,2,c.byref(file))==-1
        buf=c.create_string_buffer(4096)
        assert dll.qs_meta_tracker(handle,0,buf,len(buf))==0 and buf.value==tracker
    finally: dll.qs_meta_close(handle)
    folder=root/'data'; folder.mkdir()
    contents=folder/'Тестові файли'; contents.mkdir()
    (contents/'chosen.bin').write_bytes(part_a)
    s=dll.qs_create(); assert s,dll.qs_error()
    try:
        assert dll.qs_configure(s,0,0,0,200)==-1
        assert dll.qs_configure(s,6882,-1,0,200)==-1
        assert dll.qs_configure(s,6882,128,64,150)==0
        priorities=(c.c_int*2)(0,0)
        assert dll.qs_add_selected(s,encoded,str(folder).encode(),priorities,2,0)==-1
        priorities[0]=4
        assert dll.qs_add_selected(s,encoded,str(folder).encode(),priorities,1,0)==-1
        tid=dll.qs_add_selected(s,encoded,str(folder).encode(),priorities,2,0)
        assert tid>0,dll.qs_error()
        snap=Snapshot()
        assert dll.qs_snapshot(s,tid,c.byref(snap))==0
        assert snap.state==8 and snap.down==0
        assert dll.qs_command(s,tid,1)==0
        deadline=time.monotonic()+20
        while time.monotonic()<deadline:
            assert dll.qs_snapshot(s,tid,c.byref(snap))==0
            if snap.state in (4,5): break
            time.sleep(0.1)
        assert snap.state in (4,5),(snap.state,snap.error)
        assert snap.total==16384 and snap.done==16384,(snap.total,snap.done)
        assert not (contents/'skip.bin').exists()
    finally: dll.qs_destroy(s)
print('PASS: offline metadata, UTF-8 paths, file selection, paused add, selective verification, live settings validation')
