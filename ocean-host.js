// Browser-only Three.js ocean underneath the existing transparent game/UI canvas.
// Lua drives the camera and lifetime; no second animation clock or input surface.
(()=>{
 const PREFIX='[CrescentHomeOcean]';
 const base=new URL(window.CrescentHost.baseURL);
 let ocean=null,canvas=null,active=false,last=null,failed=false;
 const originalLog=console.log.bind(console);
 const nativeGetContext=HTMLCanvasElement.prototype.getContext;
 const wrapped=new WeakSet();
 HTMLCanvasElement.prototype.getContext=function(type,options){
  // The runtime replaces #canvas when it falls back from WebGPU to WebGL2.
  const engine=this.id==='canvas';
  if(engine&&(type==='webgl2'||type==='webgl'))options={...options,alpha:true,premultipliedAlpha:true};
  const context=nativeGetContext.call(this,type,options);
  if(engine&&type==='webgpu'&&context&&!wrapped.has(context)){
   const configure=context.configure;
   context.configure=function(config){return configure.call(this,{...config,alphaMode:'premultiplied'});};
   wrapped.add(context);
  }
  return context;
 };
 function hide(){active=false;if(canvas)canvas.hidden=true;ocean?.setVisible(false);}
 function fail(error){
  if(failed)return;
  failed=true;hide();document.documentElement.dataset.crescentOcean='failed';
  console.error('[CrescentOcean]',error);
  // Preserve gameplay and expose the loss of the external renderer; do not
  // claim the procedural fallback is the Tidewater renderer.
  if(window.Module?.calledRun){
   const status=document.createElement('button');status.id='ocean-recover';
   status.textContent='海水加载中断 · 点此重新加载';
   status.addEventListener('click',()=>location.reload());document.body.append(status);
  }
 }
 function receive(state){
  last=state;
  if(!ocean||failed)return;
  if(state.active!==true||document.hidden){hide();return;}
  if(!['cx','cy','zoom','height','time','left','top','scale'].every(key=>Number.isFinite(state[key]))||state.zoom<=0||state.height<=0||state.scale<=0)return;
  canvas.style.left=state.left+'px';canvas.style.top=state.top+'px';
  canvas.style.width=(450*state.scale)+'px';canvas.style.height=(state.height*state.scale)+'px';
  canvas.hidden=false;active=true;ocean.setVisible(true);
  try{const pending=ocean.render(state);if(pending?.catch)pending.catch(fail);}catch(error){fail(error);}
 }
 console.log=(...args)=>{
  for(const arg of args)if(typeof arg==='string'){
   const start=arg.indexOf(PREFIX);
   if(start>=0){try{receive(JSON.parse(arg.slice(start+PREFIX.length)));}catch{}return;}
  }
  originalLog(...args);
 };
 async function init(){
  // Native/Maker runtimes and browsers without compute keep their compatibility
  // water. The Three ownership flag is passed only after successful initialization.
  if(new URL(location.href).searchParams.get('ocean')==='legacy')return false;
  if(!navigator.gpu){document.documentElement.dataset.crescentOcean='compatibility';return false;}
  try{
   const response=await fetch(new URL('ocean/release.json',base),{cache:'no-store',signal:AbortSignal.timeout(20000)});
   if(!response.ok)throw new Error('ocean manifest HTTP '+response.status);
   const release=await response.json();
   if(!/^ocean-[a-f0-9]{12}\.js$/.test(release.bundle)||!/^island-[a-f0-9]{12}\.json$/.test(release.field))throw new Error('invalid ocean release');
   const {createOcean}=await import(new URL('ocean/'+release.bundle,base));
   canvas=document.createElement('canvas');canvas.id='home-ocean';canvas.hidden=true;
   canvas.setAttribute('aria-hidden','true');document.body.prepend(canvas);
   ocean=await createOcean(canvas,new URL('ocean/'+release.field,base).href);
   window.Module.arguments.push('-homeocean=three');
   document.documentElement.dataset.crescentOcean='three-tidewater';
   if(last)receive(last);
   return true;
  }catch(error){
   ocean?.dispose();ocean=null;canvas?.remove();canvas=null;
   document.documentElement.dataset.crescentOcean='compatibility';
   console.warn('[CrescentOcean] Three initialization unavailable:',error.message);
   return false;
  }
 }
 document.addEventListener('visibilitychange',()=>{if(document.hidden)hide();else if(last)receive(last);});
 window.addEventListener('pagehide',hide);
 window.CrescentOcean={init,snapshot:()=>({active,failed,renderer:document.documentElement.dataset.crescentOcean})};
})();
