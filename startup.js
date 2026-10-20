// Observe the engine's real Lua startup result. No storage, telemetry or per-frame work.
(()=>{
 let ready=false,waiting=false,elapsed=0,last=0,timer=null,errorTimer=null,lastError='';
 const errors=[];
 const panel=document.getElementById('startup-error');
 const detail=document.getElementById('startup-error-detail');
 const message=document.getElementById('startup-error-message');
 const cancel=()=>{clearTimeout(timer);clearTimeout(errorTimer);timer=errorTimer=null;};
 function show(reason){
  if(ready)return;
  cancel();waiting=false;
  message.textContent=reason;
  detail.textContent=lastError||'资源加载完成后，未收到游戏场景启动成功信号。';
  panel.hidden=false;
 }
 function success(){
  ready=true;waiting=false;cancel();panel.hidden=true;
  document.documentElement.dataset.crescentStartup='ready';
 }
 function fail(text){
  if(ready)return;
  lastError=String(text).slice(-5000);errors.push(lastError);
  if(errors.length>8)errors.shift();
  // A material failure may be recovered by the Lua compatibility attempt.
  clearTimeout(errorTimer);
  errorTimer=setTimeout(()=>show('游戏启动遇到了错误，可以重试或使用兼容模式。'),1000);
 }
 const fatal=/\[CrescentStartup\] failed:|Error executing.*(?:main\.lua|Game\/)|(?:main\.lua|Game\/\w+\.lua):\d+.*(?:attempt to|error|assert)|Failed to (?:compile (?:vertex|pixel) shader|load SurfaceShader)/i;
 for(const method of ['log','error']){
  const original=console[method].bind(console);
  console[method]=(...args)=>{
   original(...args);
   if(ready)return;
   const text=args.filter(arg=>typeof arg==='string').join(' ');
   if(text.includes('[Crescent] playable prototype started'))success();
   else if(!text.includes('[CrescentStartup] ocean-fallback:')&&fatal.test(text))fail(text);
  };
 }
 function tick(){
  if(!waiting||ready)return;
  const now=performance.now();
  if(!document.hidden)elapsed+=now-last;
  last=now;
  if(elapsed>=30000)show('资源已加载，但小岛还没能启动。请重试，或使用兼容模式。');
  else timer=setTimeout(tick,1000);
 }
 window.addEventListener('urhox:loading-hidden',()=>{
  if(ready||waiting)return;
  waiting=true;last=performance.now();timer=setTimeout(tick,1000);
 });
 document.addEventListener('visibilitychange',()=>{last=performance.now();});
 window.addEventListener('error',event=>{
  if(event.error)fail(event.error.stack||event.message);
 });
 window.addEventListener('unhandledrejection',event=>{
  const reason=event.reason;
  if(reason)fail(reason.stack||reason.message||reason);
 });
 document.getElementById('startup-retry').addEventListener('click',()=>location.reload());
 document.getElementById('startup-compat').addEventListener('click',()=>{
  const url=new URL(location.href);url.searchParams.set('ocean','legacy');location.replace(url.href);
 });
 window.CrescentStartup={snapshot:()=>({ready,waiting,elapsedMs:Math.round(elapsed),errors:[...errors]})};
})();
