import ctypes as c
import hashlib
from pathlib import Path
import tempfile
import time
import os

class Snapshot(c.Structure):
    _fields_ = [('total',c.c_int64),('done',c.c_int64)] + [(n,c.c_int32) for n in ('down','up','peers','seeds','state','progress')] + [('name',c.c_char*512),('error',c.c_char*512)]
assert c.sizeof(Snapshot) == 1064

def bencode(v):
    if isinstance(v, int): return b'i'+str(v).encode()+b'e'
    if isinstance(v, bytes): return str(len(v)).encode()+b':'+v
    if isinstance(v, list): return b'l'+b''.join(bencode(item) for item in v)+b'e'
    if isinstance(v, dict): return b'd'+b''.join(bencode(k)+bencode(v[k]) for k in sorted(v))+b'e'
    raise TypeError(v)

dll=c.CDLL(str((Path(os.environ.get('OT_ENGINE_DIR', 'bin/Win64')) / 'qsbridge.dll').resolve()), winmode=0x8)
class SessionOptions(c.Structure):
    _fields_=[('size',c.c_uint32)]+[(n,c.c_int32) for n in ('port','down','up','connections','flags','stop_timeout','reserved')]
assert c.sizeof(SessionOptions)==32

dll.qs_create.argtypes=[c.POINTER(SessionOptions),c.c_char_p]
dll.qs_create.restype=c.c_void_p

def create_session(port=6881):
    config=SessionOptions(c.sizeof(SessionOptions),port,0,0,200,0,2,0)
    return dll.qs_create(c.byref(config),b'OnlyTorrent-test/0.1')

dll.qs_add_prepared.argtypes=[c.c_void_p,c.c_char_p,c.c_char_p,c.POINTER(c.c_int),
    c.c_int,c.c_int,c.c_int,c.c_int,c.c_int,c.POINTER(c.c_char_p),c.POINTER(c.c_char_p),c.c_int]

def add_prepared(session,file,path,priorities,start=1,sequential=0,down=0,up=0,paths=None,trackers=()):
    priority_array=(c.c_int*len(priorities))(*priorities)
    file_paths=None if paths is None else (c.c_char_p*len(paths))(*paths)
    urls=(c.c_char_p*len(trackers))(*trackers) if trackers else None
    return dll.qs_add_prepared(session,file,path,priority_array,len(priorities),start,sequential,down,up,file_paths,urls,len(trackers))

dll.qs_destroy.argtypes=[c.c_void_p]
dll.qs_add.argtypes=[c.c_void_p,c.c_char_p,c.c_char_p]
dll.qs_snapshot.argtypes=[c.c_void_p,c.c_int,c.POINTER(Snapshot)]
dll.qs_command.argtypes=[c.c_void_p,c.c_int,c.c_int]
dll.qs_error.restype=c.c_char_p
