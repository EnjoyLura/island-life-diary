// One presentation budget for engine + UI. Native request timestamps are kept;
// resolution, DPR, input coordinates and simulation clocks are never rewritten.
(()=>{
 const params=new URL(location.href).searchParams;
 const requested=Number(params.get('fps'));
 const fps=requested>=30&&requested<=120?Math.floor(requested):60;
 const nativeRAF=window.requestAnimationFrame.bind(window);
 const nativeCancel=window.cancelAnimationFrame.bind(window);
 const queue=new Map();let sequence=0,handle=null,deadline=0;
 const interval=1000/fps;
 function schedule(){if(handle===null&&queue.size&&!document.hidden)handle=nativeRAF(tick);}
 function tick(timestamp){
  handle=null;
  if(document.hidden)return;
  if(timestamp+.2<deadline){schedule();return;}
  if(!deadline||timestamp-deadline>interval*4)deadline=timestamp+interval;
  else deadline+=Math.max(1,Math.floor((timestamp-deadline)/interval)+1)*interval;
  const current=[...queue.keys()];
  for(const id of current){
   const callback=queue.get(id);if(!callback)continue;queue.delete(id);
   try{callback(timestamp);}catch(error){setTimeout(()=>{throw error;},0);}
  }
  schedule();
 }
 window.requestAnimationFrame=callback=>{const id=++sequence;queue.set(id,callback);schedule();return id;};
 window.cancelAnimationFrame=id=>{
  queue.delete(id);
  if(!queue.size&&handle!==null){nativeCancel(handle);handle=null;deadline=0;}
 };
 document.addEventListener('visibilitychange',()=>{
  if(document.hidden){if(handle!==null)nativeCancel(handle);handle=null;}
  else{deadline=0;schedule();}
 });
 window.CrescentFrameBudget={fps};
})();
