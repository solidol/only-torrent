"""Explicit preparation of selected MIT Fluent SVG sources; never run by Delphi builds."""
from pathlib import Path
import hashlib,json,urllib.request,urllib.parse

ROOT=Path(__file__).resolve().parents[1]
TARGET=ROOT/'resources/icons/fluent'
ASSETS={
 'document_add':'Document Add','dismiss':'Dismiss','play':'Play','pause':'Pause',
 'settings':'Settings','folder_open':'Folder Open','delete':'Delete','dark_theme':'Dark Theme',
 'clock':'Clock','document_search':'Document Search','document_arrow_down':'Document Arrow Down',
 'arrow_download':'Arrow Download','checkmark':'Checkmark','arrow_upload':'Arrow Upload',
 'hard_drive':'Hard Drive','arrow_up':'Arrow Up','arrow_down':'Arrow Down'}

def download(url):
 return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'OnlyTorrent-icon-preparation'}),timeout=45).read()

if __name__=='__main__':
 import argparse
 parser=argparse.ArgumentParser();parser.add_argument('--fetch',action='store_true',required=True);parser.add_argument('--commit',default='main');args=parser.parse_args()
 revision=json.loads(download('https://api.github.com/repos/microsoft/fluentui-system-icons/commits/'+args.commit))['sha']
 base='https://raw.githubusercontent.com/microsoft/fluentui-system-icons/'+revision+'/'
 (TARGET/'svg').mkdir(parents=True,exist_ok=True)
 manifest={'repository':'https://github.com/microsoft/fluentui-system-icons','commit':revision,'license':'MIT','renderer':'@resvg/resvg-js@2.6.2','sources':{}}
 license_data=download(base+'LICENSE');(TARGET/'LICENSE').write_bytes(license_data)
 for name,folder in ASSETS.items():
  for size in (20,24,16,32):
   path=f'assets/{folder}/SVG/ic_fluent_{name}_{size}_filled.svg'
   try:data=download(base+urllib.parse.quote(path));break
   except urllib.error.HTTPError as error:
    if error.code!=404:raise
  else:raise RuntimeError('Missing Fluent asset '+name)
  (TARGET/'svg'/f'{name}.svg').write_bytes(data)
  manifest['sources'][name]={'path':path,'sha256':hashlib.sha256(data).hexdigest()}
  print(name,flush=True)
 (TARGET/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 print('Pinned Fluent revision:',revision)
