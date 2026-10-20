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
 // RAF timestamps can jitter around a refresh boundary. A 0.2 ms deadline
 // rejected normal 60 Hz callbacks and turned small jitter into 33 ms frames.
 // Keep the phase anchored, with bounded slack (still below half a 120 Hz tick).
 const tolerance=Math.min(3,interval*.35);
 let measurements=null,lastNative=null,lastDelivered=null;
 const intervalStats=()=>({samples:0,totalMs:0,maxMs:0,over25Ms:0});
 function measure(stats,delta){
  if(delta<=0)return;
  stats.samples++;stats.totalMs+=delta;stats.maxMs=Math.max(stats.maxMs,delta);
  if(delta>25)stats.over25Ms++;
 }
 function diagnostics(){
  if(!measurements)return null;
  const summarize=stats=>({samples:stats.samples,meanMs:stats.samples?stats.totalMs/stats.samples:0,
   maxMs:stats.maxMs,over25Ms:stats.over25Ms});
  return {source:'host-requestAnimationFrame',targetFps:fps,toleranceMs:tolerance,
   nativeCallbacks:measurements.nativeCallbacks,deliveredFrames:measurements.deliveredFrames,
   throttleSkips:measurements.throttleSkips,nativeIntervals:summarize(measurements.nativeIntervals),
   deliveredIntervals:summarize(measurements.deliveredIntervals),
   note:'Callback cadence, not GPU time or displayed frames. Hidden intervals are excluded.'};
 }
 function schedule(){if(handle===null&&queue.size&&!document.hidden)handle=nativeRAF(tick);}
 function tick(timestamp){
  handle=null;
  if(document.hidden)return;
  if(measurements){
   measurements.nativeCallbacks++;
   if(lastNative!==null)measure(measurements.nativeIntervals,timestamp-lastNative);
   lastNative=timestamp;
  }
  if(timestamp+tolerance<deadline){
   if(measurements)measurements.throttleSkips++;
   schedule();return;
  }
  if(!deadline||timestamp-deadline>interval*4)deadline=timestamp+interval;
  else deadline+=Math.max(1,Math.floor((timestamp-deadline)/interval)+1)*interval;
  if(measurements){
   measurements.deliveredFrames++;
   if(lastDelivered!==null)measure(measurements.deliveredIntervals,timestamp-lastDelivered);
   lastDelivered=timestamp;
  }
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
  lastNative=null;lastDelivered=null;
  if(document.hidden){if(handle!==null)nativeCancel(handle);handle=null;}
  else{deadline=0;schedule();}
 });
 window.CrescentFrameBudget={fps,diagnostics,
  beginDiagnostics(){
   measurements={nativeCallbacks:0,deliveredFrames:0,throttleSkips:0,
    nativeIntervals:intervalStats(),deliveredIntervals:intervalStats()};
   lastNative=null;lastDelivered=null;
  },
  endDiagnostics(){const result=diagnostics();measurements=null;return result;}
 };
})();
