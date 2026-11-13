from engine_common import *

class Extra(c.Structure):
    _fields_=[('created',c.c_int64),('pieces',c.c_int32),('piece_length',c.c_int32),('creator',c.c_char*512),('publisher',c.c_char*512),('url',c.c_char*2048),('hash',c.c_char*64),('web_seeds',c.c_char*4096)]
assert c.sizeof(Extra)==7248
dll.qs_meta_open.argtypes=[c.c_char_p];dll.qs_meta_open.restype=c.c_void_p
dll.qs_meta_close.argtypes=[c.c_void_p]
dll.qs_meta_extra.argtypes=[c.c_void_p,c.c_char_p,c.POINTER(Extra)]
dll.qs_blocks.argtypes=[c.c_void_p,c.c_int,c.c_int,c.POINTER(c.c_ubyte),c.POINTER(c.c_ubyte),c.POINTER(c.c_ubyte),c.POINTER(c.c_int64),c.POINTER(c.c_int)]
dll.qs_add_options.argtypes=[c.c_void_p,c.c_char_p,c.c_char_p,c.c_char_p,c.POINTER(c.c_int),c.c_int,c.c_int,c.c_int,c.c_int,c.c_int,c.c_char_p]

def map_blocks(s,tid,columns):
    v=(c.c_ubyte*columns)();r=(c.c_ubyte*columns)();q=(c.c_ubyte*columns)()
    total=c.c_int64();size=c.c_int()
    count=dll.qs_blocks(s,tid,columns,v,r,q,c.byref(total),c.byref(size))
    assert count>=0,dll.qs_error()
    return list(v)[:count],list(r)[:count],list(q)[:count],total.value,size.value

for corrupt in (False,True):
    with tempfile.TemporaryDirectory(prefix='qs-blocks-') as tmp:
        root=Path(tmp)
        blocks=[bytes([65+i])*16384 for i in range(4)]
        info={b'name':b'original',b'piece length':16384,
              b'pieces':b''.join(hashlib.sha1(x).digest() for x in blocks),
              b'files':[{b'length':16384,b'path':[str(i).encode()+b'.bin']} for i in range(4)]}
        file=root/'map.torrent'
        file.write_bytes(bencode({b'info':info,b'creation date':1700000000,b'created by':b'qs fixture',b'publisher':b'Publisher',b'publisher-url':b'https://example.org/',b'url-list':[b'http://127.0.0.1:1/webseed/']}))
        path=str(file).encode()
        handle=dll.qs_meta_open(path);assert handle,dll.qs_error()
        try:
            extra=Extra();assert dll.qs_meta_extra(handle,path,c.byref(extra))==0,dll.qs_error()
            assert extra.pieces==4 and extra.piece_length==16384
            assert extra.created==1700000000 and extra.creator==b'qs fixture'
            assert extra.publisher==b'Publisher' and extra.url==b'https://example.org/'
            assert extra.hash.decode()==hashlib.sha1(bencode(info)).hexdigest()
        finally:dll.qs_meta_close(handle)
        target=root/'custom';target.mkdir()
        (target/'0.bin').write_bytes(b'X'*16384 if corrupt else blocks[0])
        (target/'2.bin').write_bytes(blocks[2])
        priorities=(c.c_int*4)(4,0,4,0)
        s=dll.qs_create();assert s,dll.qs_error()
        try:
            assert dll.qs_add_options(s,path,str(root).encode(),b'../outside',priorities,4,0,0,0,0,b'')==-1
            tid=dll.qs_add_options(s,path,str(root).encode(),b'custom',priorities,4,1,1,128,64,b'')
            assert tid>0,dll.qs_error()
            snap=Snapshot();deadline=time.monotonic()+20
            while time.monotonic()<deadline:
                dll.qs_snapshot(s,tid,c.byref(snap))
                v,r,q,total,size=map_blocks(s,tid,4)
                if v[2]==255 and snap.state in (3,4,5):break
                time.sleep(.1)
            assert (total,size)==(4,16384)
            assert v==([0,0,255,0] if corrupt else [255,0,255,0]),(v,snap.state)
            grouped=map_blocks(s,tid,2)[0]
            assert grouped==([0,127] if corrupt else [127,127]),grouped
            assert map_blocks(s,tid,1)[0]==([63] if corrupt else [127])
            assert map_blocks(s,tid,4096)[0]==v
            assert not (root/'original').exists()
            assert not (target/'1.bin').exists()
        finally:dll.qs_destroy(s)
print('PASS: non-contiguous real block map, contiguous aggregation, hash failure, custom subfolder, selective files, publisher metadata')
