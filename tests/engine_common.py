import ctypes as c
import hashlib
from pathlib import Path
import tempfile
import time

class Snapshot(c.Structure):
    _fields_ = [('total',c.c_int64),('done',c.c_int64)] + [(n,c.c_int32) for n in ('down','up','peers','seeds','state','progress')] + [('name',c.c_char*512),('error',c.c_char*512)]
assert c.sizeof(Snapshot) == 1064

def bencode(v):
    if isinstance(v, int): return b'i'+str(v).encode()+b'e'
    if isinstance(v, bytes): return str(len(v)).encode()+b':'+v
    if isinstance(v, list): return b'l'+b''.join(bencode(item) for item in v)+b'e'
    if isinstance(v, dict): return b'd'+b''.join(bencode(k)+bencode(v[k]) for k in sorted(v))+b'e'
    raise TypeError(v)

dll=c.CDLL(str(Path('bin/Win64/qsengine.dll').resolve()))
dll.qs_create.restype=c.c_void_p
dll.qs_destroy.argtypes=[c.c_void_p]
dll.qs_add.argtypes=[c.c_void_p,c.c_char_p,c.c_char_p]
dll.qs_snapshot.argtypes=[c.c_void_p,c.c_int,c.POINTER(Snapshot)]
dll.qs_command.argtypes=[c.c_void_p,c.c_int,c.c_int]
dll.qs_error.restype=c.c_char_p
