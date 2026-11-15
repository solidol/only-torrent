"""Actual loopback upload and lifetime-counter restoration; no public peers."""
from engine_common import *
import socket
import struct

ptr = c.c_void_p
dll.lt_snapshot_uploaded.argtypes = [ptr, c.c_int, c.POINTER(Snapshot), c.POINTER(c.c_int64)]
dll.lt_resume_request.argtypes = [ptr, c.c_int, c.c_int]
dll.lt_resume_poll.argtypes = [ptr, c.POINTER(c.c_int), c.POINTER(c.c_int), c.POINTER(c.c_int)]
dll.lt_resume_poll.restype = ptr
dll.lt_blob_copy.argtypes = [ptr, c.POINTER(c.c_ubyte), c.c_int]
dll.lt_blob_close.argtypes = [ptr]
dll.lt_add_prepared_resume.argtypes = [ptr,c.c_char_p,c.c_char_p,c.POINTER(c.c_int),c.c_int,c.c_int,c.c_int,c.c_int,c.c_int,c.POINTER(c.c_char_p),c.POINTER(c.c_char_p),c.c_int,c.POINTER(c.c_ubyte),c.c_int,c.POINTER(c.c_int)]

def exact(peer, count):
    data = b''
    while len(data) < count:
        part = peer.recv(count-len(data))
        if not part: raise EOFError('peer closed')
        data += part
    return data

def uploaded(session, task):
    value = c.c_int64(-1)
    assert dll.lt_snapshot_uploaded(session,task,c.byref(Snapshot()),c.byref(value)) == 0, dll.lt_error()
    return value.value

probe = socket.socket(); probe.bind(('127.0.0.1',0)); port=probe.getsockname()[1]; probe.close()
with tempfile.TemporaryDirectory(prefix='ot-upload-') as tmp:
    root=Path(tmp); payload=bytes(range(256))*64
    info={b'name':b'upload.bin',b'length':len(payload),b'piece length':16384,b'pieces':hashlib.sha1(payload).digest()}
    torrent=root/'upload.torrent'; torrent.write_bytes(bencode({b'info':info}))
    (root/'upload.bin').write_bytes(payload)
    session=create_session(port); assert session, dll.lt_error()
    try:
        task=dll.lt_add(session,str(torrent).encode(),str(root).encode()); assert task>0
        assert dll.lt_snapshot_uploaded(session,task,c.byref(Snapshot()),None)==-1
        assert uploaded(session,task)==0
        snapshot=Snapshot(); deadline=time.monotonic()+20
        while time.monotonic()<deadline:
            assert dll.lt_snapshot(session,task,c.byref(snapshot))==0
            if snapshot.state==5: break
            time.sleep(.05)
        assert snapshot.state==5
        with socket.create_connection(('127.0.0.1',port),timeout=20) as peer:
            peer.settimeout(30)
            peer.sendall(b'\x13BitTorrent protocol'+b'\0'*8+hashlib.sha1(bencode(info)).digest()+b'-OT0001-123456789012')
            handshake=exact(peer,68); assert handshake[28:48]==hashlib.sha1(bencode(info)).digest()
            peer.sendall(struct.pack('!I',1)+b'\x02') # interested
            deadline=time.monotonic()+35
            while time.monotonic()<deadline:
                length=struct.unpack('!I',exact(peer,4))[0]
                if not length: continue
                message=exact(peer,length)
                if message[0]==1: break # unchoked
            else: raise AssertionError('not unchoked')
            peer.sendall(struct.pack('!IBIII',13,6,0,0,len(payload)))
            while True:
                length=struct.unpack('!I',exact(peer,4))[0]
                if not length: continue
                message=exact(peer,length)
                if message[0]==7:
                    assert message[9:]==payload
                    break
        deadline=time.monotonic()+10
        while uploaded(session,task)<len(payload) and time.monotonic()<deadline: time.sleep(.1)
        assert uploaded(session,task)==len(payload), uploaded(session,task)
        assert dll.lt_command(session,task,0)==0
        assert dll.lt_resume_request(session,task,1)>=0
        deadline=time.monotonic()+10; resume=None
        while time.monotonic()<deadline:
            reply_id=c.c_int(); status=c.c_int(); length=c.c_int()
            blob=dll.lt_resume_poll(session,c.byref(reply_id),c.byref(status),c.byref(length))
            if blob:
                try:
                    assert status.value==0
                    resume=(c.c_ubyte*length.value)()
                    assert dll.lt_blob_copy(blob,resume,length.value)==length.value
                finally: dll.lt_blob_close(blob)
                break
            time.sleep(.05)
        assert resume is not None
    finally: dll.lt_destroy(session)
    session=create_session(port)
    try:
        priorities=(c.c_int*1)(4); used=c.c_int()
        task=dll.lt_add_prepared_resume(session,str(torrent).encode(),str(root).encode(),priorities,1,0,0,0,0,None,None,0,resume,len(resume),c.byref(used))
        assert task>0 and used.value==1, dll.lt_error()
        deadline=time.monotonic()+10
        while uploaded(session,task)!=len(payload) and time.monotonic()<deadline: time.sleep(.05)
        assert uploaded(session,task)==len(payload), 'Lifetime upload lost after resume'
        assert dll.lt_snapshot_uploaded(session,-123,c.byref(Snapshot()),c.byref(c.c_int64()))==-1
    finally: dll.lt_destroy(session)
print('PASS: real 16 KiB upload, byte-exact payload, lifetime upload counter, binary resume and session restart')
