// Persist two explicitly allowed files. Keep the original gameplay key/bytes.
(()=>{
 const records=[
  {key:'crescent-island:local-save:v1',filename:'crescent-island-v1.json',status:'crescentSave',limit:1500000},
  {key:'crescent-island:audio-settings:v1',filename:'crescent-audio-v1.json',status:'crescentAudioSave',limit:4096}
 ];
 const encode=bytes=>btoa(Array.from(bytes,b=>String.fromCharCode(b)).join(''));
 const decode=text=>Uint8Array.from(atob(text),c=>c.charCodeAt(0));
 function restoreOne(record){
  const {key,filename,limit}=record,status=value=>document.documentElement.dataset[record.status]=value;
  try{
   const value=JSON.parse(localStorage.getItem(key)||'null');
   if(!value){status('new');return;}
   if(typeof value.path!=='string'||!value.path.startsWith('/home/web_user/update/')||!value.path.includes('/savedata/')||!value.path.endsWith('/'+filename)||value.path.split('/').some(p=>p==='..'||p==='.')||typeof value.bytes!=='string'||value.bytes.length>limit){status('invalid');return;}
   const FS=window.Module.FS;
   // Called after WasmFS initialization and before the C++ game entry.
   let current='';for(const part of value.path.split('/').slice(1,-1)){current+='/'+part;try{FS.mkdir(current);}catch{}}
   FS.writeFile(value.path,decode(value.bytes));
   record.savedPath=value.path;record.lastBytes=value.bytes;status('restored');
  }catch{status('unavailable');}
 }
 function find(FS,directory,filename,depth=0){
  if(depth>5)return null;
  let names;try{names=FS.readdir(directory);}catch{return null;}
  for(const name of names){
   if(name==='.'||name==='..')continue;
   const p=directory+'/'+name;
   if(name===filename&&p.includes('/savedata/'))return p;
   try{if((FS.stat(p).mode&0xf000)===0x4000){const found=find(FS,p,filename,depth+1);if(found)return found;}}catch{}
  }
  return null;
 }
 function persist(){
  const FS=window.Module?.FS;if(!window.Module?.calledRun||!FS?.readFile)return;
  for(const record of records)try{
   record.savedPath=record.savedPath||find(FS,'/home/web_user/update',record.filename);if(!record.savedPath)continue;
   const bytes=encode(FS.readFile(record.savedPath));if(!bytes||bytes===record.lastBytes||bytes.length>record.limit)continue;
   localStorage.setItem(record.key,JSON.stringify({path:record.savedPath,bytes}));record.lastBytes=bytes;
   document.documentElement.dataset[record.status]='saved';
  }catch{document.documentElement.dataset[record.status]='unavailable';}
 }
 window.Module.preRun=[()=>{
  const module=window.Module,previous=module.onRuntimeInitialized;
  module.onRuntimeInitialized=()=>{if(previous)previous();for(const record of records)restoreOne(record);};
 }];
 setInterval(persist,1500);
 addEventListener('pagehide',persist);
 document.addEventListener('visibilitychange',()=>{if(document.hidden)persist();});
})();
