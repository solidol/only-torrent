// Explicit asset preparation only. Normal Delphi builds consume the checked-in DFM/PNG.
const fs=require('fs'), path=require('path'), crypto=require('crypto');
const root=path.resolve(__dirname,'..');
const {Resvg}=require(path.join(root,'build/icon-tools/node_modules/@resvg/resvg-js'));
const folder=path.join(root,'resources/icons/fluent');
const manifest=JSON.parse(fs.readFileSync(path.join(folder,'manifest.json'),'utf8'));
for(const [name,entry] of Object.entries(manifest.sources)){
 const data=fs.readFileSync(path.join(folder,'svg',name+'.svg'));
 if(crypto.createHash('sha256').update(data).digest('hex')!==entry.sha256)throw Error('Source checksum: '+name);
}
const sizes=[20,24,32,40,48,64];
const icons=[['document_add','green'],['dismiss','red'],['play','green'],['pause','blue'],
 ['settings','neutral'],['folder_open','neutral'],['delete','red'],['dark_theme','foreground'],
 ['clock','neutral'],['document_search','blue'],['document_arrow_down','blue'],
 ['arrow_download','blue'],['checkmark','green'],['arrow_upload','green'],['hard_drive','blue'],
 ['transfer','blue'],['arrow_download','red'],['transfer','red'],['arrow_up','foreground'],['arrow_down','foreground']];
const palettes={light:{green:'#008000',blue:'#0066cc',red:'#800000',neutral:'#6d6d6d',foreground:'#202020'},
 dark:{green:'#008000',blue:'#4e94ce',red:'#800000',neutral:'#858585',foreground:'#d4d4d4'}};
function svg(name,color){return fs.readFileSync(path.join(folder,'svg',name+'.svg'),'utf8').replace(/fill="(?!none)[^"]*"/g,'fill="'+color+'"');}
function transfer(palette,color){
 const inner=(name,col)=>svg(name,col).replace(/^[\s\S]*?<svg[^>]*>/,'').replace(/<\/svg>[\s\S]*$/,'');
 return '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20">'+
 '<g transform="translate(-1 0) scale(.6 1)">'+inner('arrow_upload',palette.green)+'</g>'+
 '<g transform="translate(9 0) scale(.6 1)">'+inner('arrow_download',color)+'</g></svg>';
}
const entries=[];
for(const [theme,palette] of Object.entries(palettes)){
 for(let index=0;index<icons.length;index++){
  const [name,role]=icons[index], sources=[];
  for(const size of sizes){
   const input=name==='transfer'?transfer(palette,palette[role]):svg(name,palette[role]);
   const png=new Resvg(input,{fitTo:{mode:'width',value:size},font:{loadSystemFonts:false}}).render().asPng();
   const relative=`png/${theme}/${index.toString().padStart(2,'0')}-${name}-${size}.png`;
   fs.mkdirSync(path.dirname(path.join(folder,relative)),{recursive:true});fs.writeFileSync(path.join(folder,relative),png);
   sources.push(png);
  }
  entries.push({name:theme+'-'+index,sources});
 }
}
const hexLines=data=>data.toString('hex').toUpperCase().match(/.{1,64}/g).map(line=>'              '+line).join('\n');
let collection='  object ImageCollectionMain: TImageCollection\n    InterpolationMode = icIMFant\n    Images = <\n';
collection+=entries.map(entry=>'      item\n        Name = \''+entry.name+'\'\n        SourceImages = <\n'+
 entry.sources.map(data=>'          item\n            Image.Data = {\n'+hexLines(data)+'}').join('\n          end\n')+'\n          end>\n      end').join('\n');
collection+='>\n    Left = 528\n    Top = 128\n  end\n';
collection+='  object VirtualImageListMain: TVirtualImageList\n    Images = <\n'+
 icons.map((_,index)=>`      item\n        CollectionIndex = ${index}\n        CollectionName = 'light-${index}'\n        Name = 'Icon${index}'\n      end`).join('\n')+'>\n'+
 '    ImageCollection = ImageCollectionMain\n    Width = 20\n    Height = 20\n    Left = 528\n    Top = 80\n  end';
const dfmPath=path.join(root,'src/ui/Ot.MainForm.dfm');let dfm=fs.readFileSync(dfmPath,'utf8').replace(/^\uFEFF/,'');
const block=/  object (?:ImageListMain: TImageList|ImageCollectionMain: TImageCollection)[\s\S]*?(?=\n  object PopupMenuTorrent:)/;
if(!block.test(dfm))throw Error('Cannot locate image component DFM block');
dfm=dfm.replace(block,collection);dfm=dfm.replace(/\bImageListMain\b/g,'VirtualImageListMain');
fs.writeFileSync(dfmPath,'\uFEFF'+dfm,'utf8');
const generated={sizes,palettes,icons:icons.map(([asset,color],index)=>({index,asset,color})),files:{}};
for(const theme of Object.keys(palettes))for(const file of fs.readdirSync(path.join(folder,'png',theme))){
 const relative='png/'+theme+'/'+file;
 generated.files[relative]=crypto.createHash('sha256').update(fs.readFileSync(path.join(folder,relative))).digest('hex');
}
fs.writeFileSync(path.join(folder,'generated.json'),JSON.stringify(generated,null,2)+'\n');
console.log(`Prepared ${entries.length} themed icons in ${sizes.length} sizes; embedded PNG in text DFM.`);
