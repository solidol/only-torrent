"""Check the actual DLL boundaries, not just source/CMake declarations."""
import ctypes as c,hashlib,json,struct
import os
from pathlib import Path
from engine_common import dll

def pe_tables(path):
    data=path.read_bytes();pe=struct.unpack_from('<I',data,0x3c)[0]
    machine,count,_,_,_,optional_size,_=struct.unpack_from('<HHIIIHH',data,pe+4)
    assert machine==0x8664,(path,'not AMD64')
    optional=pe+24
    assert struct.unpack_from('<H',data,optional)[0]==0x20b
    sections=[]
    for i in range(count):
        s=optional+optional_size+i*40
        virtual_size,rva,raw_size,offset=struct.unpack_from('<IIII',data,s+8)
        sections.append((rva,max(virtual_size,raw_size),offset))
    def offset(rva):
        for base,size,file_offset in sections:
            if base<=rva<base+size:return file_offset+rva-base
        raise AssertionError(('unmapped RVA',rva,path))
    def text(rva):
        start=offset(rva);return data[start:data.index(b'\0',start)].decode('ascii')
    exports=[];export_rva=struct.unpack_from('<I',data,optional+112)[0]
    if export_rva:
        e=offset(export_rva);n=struct.unpack_from('<I',data,e+24)[0];table=offset(struct.unpack_from('<I',data,e+32)[0])
        exports=[text(struct.unpack_from('<I',data,table+i*4)[0]) for i in range(n)]
    imports=[];import_rva=struct.unpack_from('<I',data,optional+120)[0]
    if import_rva:
        p=offset(import_rva)
        while any(data[p:p+20]):
            imports.append(text(struct.unpack_from('<I',data,p+12)[0]).lower());p+=20
    return exports,imports

root=Path(os.environ.get('QS_ENGINE_DIR', 'bin/Win64'))
vendor_exports,vendor_imports=pe_tables(root/'torrent-rasterbar.dll')
bridge_exports,bridge_imports=pe_tables(root/'qsbridge.dll')
assert not any(n.startswith('qs_') for n in vendor_exports)
assert 'torrent-rasterbar.dll' in bridge_imports,bridge_imports
assert 'qs_piece_open' in bridge_exports and 'qs_add_prepared' in bridge_exports
assert 'qs_blocks' not in bridge_exports and 'qs_add_options' not in bridge_exports
assert 'msvcp140.dll' in bridge_imports and 'msvcp140.dll' in vendor_imports
assert dll.qs_version()==2
dll.qs_libtorrent_version.restype=c.c_char_p
version=dll.qs_libtorrent_version().decode()
manifest=json.loads(Path('third_party/bin/Win64/runtime.json').read_text(encoding='utf-8-sig'))
assert hashlib.sha256((root/'torrent-rasterbar.dll').read_bytes()).hexdigest()==manifest['files']['torrent-rasterbar.dll']
assert version.startswith(manifest['versions']['libtorrent'])
print('PASS: original upstream DLL has no qs_* exports; qsbridge dynamically imports it; shared CRT; ABI 2; runtime libtorrent',version)
