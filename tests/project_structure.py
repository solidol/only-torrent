from pathlib import Path
import re
import xml.etree.ElementTree as ET

ET.parse('otorrent.dproj')
ET.parse('resources/otorrent.manifest')
for path in Path('src/ui').glob('*.dfm'):
    pas=path.with_suffix('.pas').read_text(encoding='utf-8-sig')
    dfm=path.read_text(encoding='utf-8-sig')
    components=re.findall(r'object (\w+): (\w+)',dfm)
    root,form_type=components[0]
    assert root.startswith('Form') and len(root) > len('Form'), (path,root,'form prefix')
    assert form_type == 'T'+root, (path,form_type,'form class must match instance')
    for name,typ in components[1:]:
        prefix=typ[1:]
        assert name.startswith(prefix) and len(name) > len(prefix), (path,name,'expected '+prefix+' + purpose')
        assert re.search(r'\b'+name+r':\s*'+typ+r'\s*;',pas),(path,name,typ)
    for event in re.findall(r'^\s+On\w+ = (\w+)',dfm,re.MULTILINE):
        assert 'procedure '+form_type+'.'+event+'(' in pas,(path,event)
    assert path.read_bytes().startswith(b'\xef\xbb\xbf'), (path,'DFM must be UTF-8 with BOM')
print('PASS: project XML, manifest, DFM component declarations and event bindings')
print('This does not replace compiling and opening the VCL form in Delphi.')
