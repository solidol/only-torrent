from engine_common import *
assert dll.qs_version()==2
with tempfile.TemporaryDirectory(prefix='qs-') as tmp:
    s=create_session()
    assert s, dll.qs_error()
    try:
        root=Path(tmp)
        assert dll.qs_add(s,str(root/'missing.torrent').encode(),str(root).encode())==-1
        assert dll.qs_error()
        data=b'qsTorrent test payload\n'*1024
        info={b'name':b'payload.bin',b'length':len(data),b'piece length':16384,
              b'pieces':b''.join(hashlib.sha1(data[i:i+16384]).digest() for i in range(0,len(data),16384))}
        file=root/'test.torrent'; file.write_bytes(bencode({b'info':info}))
        # Existing payload verifies hashing and real seeding state without public traffic.
        (root/'payload.bin').write_bytes(data)
        tid=dll.qs_add(s,str(file).encode(),str(root).encode())
        assert tid>0,dll.qs_error()
        assert dll.qs_add(s,str(file).encode(),str(root).encode())==-1
        snap=Snapshot()
        deadline=time.monotonic()+20
        while time.monotonic()<deadline:
            assert dll.qs_snapshot(s,tid,c.byref(snap))==0,dll.qs_error()
            if snap.state==5: break
            time.sleep(0.1)
        assert snap.state==5,(snap.state,snap.error)
        assert snap.total==len(data) and snap.done==len(data)
        assert snap.name==b'payload.bin'
        assert snap.progress==1000000
        assert dll.qs_command(s,tid,0)==0
        assert dll.qs_command(s,tid,1)==0
        assert dll.qs_command(s,tid,2)==0
        assert (root/'payload.bin').read_bytes()==data
        assert dll.qs_snapshot(s,tid,c.byref(snap))==-1
    finally:
        dll.qs_destroy(s)
print('PASS: ABI, invalid torrent, duplicate rejection, real SHA-1 verification, seeding, pause/resume, remove keeps data')
