from engine_common import *

class Extra(c.Structure):
    _fields_=[('created',c.c_int64),('pieces',c.c_int32),('piece_length',c.c_int32),('creator',c.c_char*512),('publisher',c.c_char*512),('url',c.c_char*2048),('hash',c.c_ubyte*32),('web_seeds',c.c_char*4096)]
assert c.sizeof(Extra)==7216
dll.lt_meta_open.argtypes=[c.c_char_p];dll.lt_meta_open.restype=c.c_void_p
dll.lt_meta_close.argtypes=[c.c_void_p]
dll.lt_meta_extra.argtypes=[c.c_void_p,c.c_void_p,c.c_int,c.POINTER(Extra)]
class Header(c.Structure):
    _fields_=[('total',c.c_int64)]+[(n,c.c_int32) for n in ('piece_length','pieces','block_size','partial_count','seed','have_bytes')]
class PartialBlock(c.Structure):
    _fields_=[(n,c.c_int32) for n in ('piece','block','state','reserved')]
assert c.sizeof(Header)==32 and c.sizeof(PartialBlock)==16
dll.lt_piece_open.argtypes=[c.c_void_p,c.c_int,c.POINTER(Header)];dll.lt_piece_open.restype=c.c_void_p
dll.lt_piece_bits.argtypes=[c.c_void_p,c.c_void_p,c.c_int]
dll.lt_piece_blocks.argtypes=[c.c_void_p,c.c_void_p,c.c_int]
dll.lt_piece_close.argtypes=[c.c_void_p]

def piece_state(s,tid):
    header=Header();handle=dll.lt_piece_open(s,tid,c.byref(header))
    assert handle,dll.lt_error()
    try:
        bits=(c.c_ubyte*header.have_bytes)()
        blocks=(PartialBlock*header.partial_count)()
        assert dll.lt_piece_bits(handle,bits,len(bits))==len(bits)
        assert dll.lt_piece_blocks(handle,blocks,len(blocks))==len(blocks)
        return header,bytes(bits)
    finally:dll.lt_piece_close(handle)


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
        handle=dll.lt_meta_open(path);assert handle,dll.lt_error()
        try:
            extra=Extra();data=file.read_bytes();buffer=c.create_string_buffer(data)
            assert dll.lt_meta_extra(handle,buffer,len(data),c.byref(extra))==0,dll.lt_error()
            assert extra.pieces==4 and extra.piece_length==16384
            assert extra.created==1700000000 and extra.creator==b'qs fixture'
            assert extra.publisher==b'Publisher' and extra.url==b'https://example.org/'
            assert bytes(extra.hash[:20]).hex()==hashlib.sha1(bencode(info)).hexdigest()
        finally:dll.lt_meta_close(handle)
        target=root/'custom';target.mkdir()
        (target/'0.bin').write_bytes(b'X'*16384 if corrupt else blocks[0])
        (target/'2.bin').write_bytes(blocks[2])
        priorities=(c.c_int*4)(4,0,4,0)
        s=create_session();assert s,dll.lt_error()
        try:
            paths=[f'custom/{i}.bin'.encode() for i in range(4)]
            tid=add_prepared(s,path,str(root).encode(),[4,0,4,0],sequential=1,down=131072,up=65536,paths=paths)
            assert tid>0,dll.lt_error()
            snap=Snapshot();deadline=time.monotonic()+20
            while time.monotonic()<deadline:
                dll.lt_snapshot(s,tid,c.byref(snap))
                header,bits=piece_state(s,tid)
                v=[255 if bits and (bits[0] & (0x80 >> i)) else 0 for i in range(4)]
                if v[2]==255 and snap.state in (3,4,5):break
                time.sleep(.1)
            assert (header.pieces,header.block_size)==(4,16384)
            assert v==([0,0,255,0] if corrupt else [255,0,255,0]),(v,snap.state)
            assert not (root/'original').exists()
            assert not (target/'1.bin').exists()
        finally:dll.lt_destroy(s)
print('PASS: raw non-contiguous piece snapshot, hash failure, prepared paths, selective files, raw publisher metadata')
