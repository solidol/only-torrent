# Real HTTP tracker + minimal BitTorrent seed, entirely on loopback.
from engine_common import *
import socket
import struct
import threading
import socketserver
import sys
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

class UdpTracker(socketserver.BaseRequestHandler):
    def handle(self):
        packet, transport=self.request
        try:
            assert len(packet)>=16
            connection,action,transaction=struct.unpack('!QII',packet[:16])
            if action==0:
                assert connection==0x41727101980
                reply=struct.pack('!IIQ',0,transaction,0x12345678)
            elif action==1:
                assert connection==0x12345678 and len(packet)>=98
                assert packet[16:36]==info_hash
                reply=struct.pack('!IIIII',1,transaction,10,0,1)+socket.inet_aton('127.0.0.1')+struct.pack('!H',seed_port)
            else:
                return
            transport.sendto(reply,self.client_address)
        except Exception as exc:errors.append(repr(exc))

protocol='udp' if '--udp' in sys.argv else 'http'
tracker=(socketserver.ThreadingUDPServer(('127.0.0.1',0),UdpTracker) if protocol=='udp'
         else ThreadingHTTPServer(('127.0.0.1',0),Tracker))
threading.Thread(target=tracker.serve_forever,daemon=True).start()
threading.Thread(target=serve_seed,daemon=True).start()
s=create_session()
assert s,dll.lt_error()
try:
    with tempfile.TemporaryDirectory(prefix='qs-network-') as tmp:
        root=Path(tmp)
        file=root/'network.torrent'
        file.write_bytes(bencode({b'announce':b'http://127.0.0.1:1/original',b'info':info}))
        edited_tracker=f'{protocol}://127.0.0.1:{tracker.server_address[1]}/announce'.encode()
        tid=add_prepared(s,str(file).encode(),str(root).encode(),[4],trackers=[edited_tracker])
        assert tid>0,dll.lt_error()
        snap=Snapshot(); deadline=time.monotonic()+45
        while time.monotonic()<deadline:
            assert dll.lt_snapshot(s,tid,c.byref(snap))==0,dll.lt_error()
            if snap.state==5: break
            time.sleep(0.1)
        assert snap.state==5,(snap.state,snap.done,snap.error,errors)
        assert (root/'network.bin').read_bytes()==payload
        assert not errors,errors
        dll.lt_command(s,tid,2)
finally:
    dll.lt_destroy(s)
    tracker.shutdown(); tracker.server_close(); seed.close()
print(f'PASS: {protocol.upper()} announce, peer discovery, TCP handshake, piece requests, download, hash verification, seeding')
