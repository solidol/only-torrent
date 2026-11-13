# Real HTTP tracker + minimal BitTorrent seed, entirely on loopback.
from engine_common import *
import socket
import struct
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

payload=bytes(range(256))*512
piece_size=16384
info={b'name':b'network.bin',b'length':len(payload),b'piece length':piece_size,
      b'pieces':b''.join(hashlib.sha1(payload[i:i+piece_size]).digest() for i in range(0,len(payload),piece_size))}
info_hash=hashlib.sha1(bencode(info)).digest()
seed=socket.socket()
seed.bind(('127.0.0.1',0)); seed.listen(4); seed.settimeout(30)
seed_port=seed.getsockname()[1]
errors=[]

def exact(conn,n):
    data=b''
    while len(data)<n:
        part=conn.recv(n-len(data))
        if not part: raise EOFError()
        data+=part
    return data

def serve_seed():
    try:
        conn,_=seed.accept()
        with conn:
            conn.settimeout(20)
            handshake=exact(conn,68)
            assert handshake[28:48]==info_hash
            conn.sendall(b'\x13BitTorrent protocol'+b'\0'*8+info_hash+b'-QS0001-123456789012')
            conn.sendall(struct.pack('!I',2)+b'\x05\xff') # bitfield, eight pieces
            conn.sendall(struct.pack('!I',1)+b'\x01') # unchoke
            while True:
                length=struct.unpack('!I',exact(conn,4))[0]
                if length==0: continue
                if length>65536: raise ValueError('oversized message')
                msg=exact(conn,length)
                if msg[0]==6:
                    index,offset,size=struct.unpack('!III',msg[1:])
                    assert index<8 and offset+size<=piece_size
                    block=payload[index*piece_size+offset:index*piece_size+offset+size]
                    reply=b'\x07'+struct.pack('!II',index,offset)+block
                    conn.sendall(struct.pack('!I',len(reply))+reply)
    except (EOFError,ConnectionResetError,ConnectionAbortedError): pass
    except Exception as exc: errors.append(repr(exc))

class Tracker(BaseHTTPRequestHandler):
    def do_GET(self):
        peers=socket.inet_aton('127.0.0.1')+struct.pack('!H',seed_port)
        body=bencode({b'interval':60,b'peers':peers,b'complete':1,b'incomplete':0})
        self.send_response(200); self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body)
    def log_message(self,*args): pass

tracker=ThreadingHTTPServer(('127.0.0.1',0),Tracker)
threading.Thread(target=tracker.serve_forever,daemon=True).start()
threading.Thread(target=serve_seed,daemon=True).start()
s=dll.qs_create()
assert s,dll.qs_error()
try:
    with tempfile.TemporaryDirectory(prefix='qs-network-') as tmp:
        root=Path(tmp)
        file=root/'network.torrent'
        file.write_bytes(bencode({b'announce':b'http://127.0.0.1:1/original',b'info':info}))
        dll.qs_add_options.argtypes=[c.c_void_p,c.c_char_p,c.c_char_p,c.c_char_p,
            c.POINTER(c.c_int),c.c_int,c.c_int,c.c_int,c.c_int,c.c_int,c.c_char_p]
        priorities=(c.c_int*1)(4)
        edited_tracker=f'http://127.0.0.1:{tracker.server_port}/announce'.encode()
        tid=dll.qs_add_options(s,str(file).encode(),str(root).encode(),b'',
            priorities,1,1,0,0,0,edited_tracker)
        assert tid>0,dll.qs_error()
        snap=Snapshot(); deadline=time.monotonic()+45
        while time.monotonic()<deadline:
            assert dll.qs_snapshot(s,tid,c.byref(snap))==0,dll.qs_error()
            if snap.state==5: break
            time.sleep(0.1)
        assert snap.state==5,(snap.state,snap.done,snap.error,errors)
        assert (root/'network.bin').read_bytes()==payload
        assert not errors,errors
        dll.qs_command(s,tid,2)
finally:
    dll.qs_destroy(s)
    tracker.shutdown(); tracker.server_close(); seed.close()
print('PASS: HTTP announce, peer discovery, TCP handshake, piece requests, download, hash verification, seeding')
