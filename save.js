// Persist this game's one save file only. No account, network or cloud storage.
(()=>{
 const key='crescent-island:local-save:v1';
 const filename='crescent-island-v1.json';
 let savedPath=null,lastBytes='';
 const status=(value)=>document.documentElement.dataset.crescentSave=value;
 const encode=bytes=>btoa(Array.from(bytes,b=>String.fromCharCode(b)).join(''));
 const decode=text=>Uint8Array.from(atob(text),c=>c.charCodeAt(0));
 function restore(){
  try{
   const value=JSON.parse(localStorage.getItem(key)||'null');
   if(!value){status('new');return;}
   if(typeof value.path!=='string'||!value.path.startsWith('/home/web_user/update/')||!value.path.includes('/savedata/')||!value.path.endsWith('/'+filename)||typeof value.bytes!=='string'||value.bytes.length>1500000){status('invalid');return;}
   const FS=window.Module.FS;
   // Called after WasmFS initialization and before the C++ game entry.
   let current='';for(const part of value.path.split('/').slice(1,-1)){current+='/'+part;try{FS.mkdir(current);}catch{}}
   FS.writeFile(value.path,decode(value.bytes));
   savedPath=value.path;lastBytes=value.bytes;status('restored');
  }catch{status('unavailable');}
 }
 function find(FS,directory,depth=0){
  if(depth>5)return null;
  let names;try{names=FS.readdir(directory);}catch{return null;}
  for(const name of names){
   if(name==='.'||name==='..')continue;
   const p=directory+'/'+name;
   if(name===filename&&p.includes('/savedata/'))return p;
   try{if((FS.stat(p).mode&0xf000)===0x4000){const found=find(FS,p,depth+1);if(found)return found;}}catch{}
  }
  return null;
 }
 function persist(){
  const FS=window.Module?.FS;if(!window.Module?.calledRun||!FS?.readFile)return;
  try{
   savedPath=savedPath||find(FS,'/home/web_user/update');if(!savedPath)return;
   const bytes=encode(FS.readFile(savedPath));if(!bytes||bytes===lastBytes)return;
   localStorage.setItem(key,JSON.stringify({path:savedPath,bytes}));lastBytes=bytes;status('saved');
  }catch{status('unavailable');}
 }
 window.Module.preRun=[()=>{
  const module=window.Module,previous=module.onRuntimeInitialized;
  module.onRuntimeInitialized=()=>{if(previous)previous();restore();};
 }];
 setInterval(persist,1500);
 addEventListener('pagehide',persist);
 document.addEventListener('visibilitychange',()=>{if(document.hidden)persist();});
})();
