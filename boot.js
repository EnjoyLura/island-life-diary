// Some static hosts cannot set COOP/COEP. The scoped worker supplies them on
// navigation; the engine must wait until the new document really is isolated.
(()=>{
 const base=new URL(window.CrescentHost.baseURL);
 const query=new URL(location.href);
 const checking=query.searchParams.get('hosting_check')==='1';
 const status=document.getElementById('loading-status');
 function fail(error){
  console.error('[CrescentHost]',error);
  document.getElementById('startup-error-message').textContent=error.message||String(error);
  document.getElementById('startup-error-detail').textContent='请使用支持 WebGL2、SharedArrayBuffer 和 Service Worker 的新版浏览器，并允许此站点保存数据。';
  document.getElementById('startup-error').hidden=false;
  document.documentElement.dataset.crescentHosting='failed';
 }
 function bounded(promise,ms,label){
  let timer;
  return Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error(label)),ms);})]).finally(()=>clearTimeout(timer));
 }
 async function register(){
  return bounded(navigator.serviceWorker.register(new URL('sw.js',base).href,{scope:base.href,updateViaCache:'none'}),20000,'启动初始化超时，请检查网络后重新加载。');
 }
 async function control(registration){
  const worker=registration.installing||registration.waiting||registration.active;
  if(!worker)throw new Error('浏览器未能安装启动组件，请重新加载。');
  await bounded(new Promise((resolve,reject)=>{
   const changed=()=>{
    if(worker.state==='activated'){worker.removeEventListener('statechange',changed);resolve();}
    else if(worker.state==='redundant'){worker.removeEventListener('statechange',changed);reject(new Error('启动组件安装失败，请重新加载。'));}
   };
   worker.addEventListener('statechange',changed);changed();
  }),20000,'启动组件安装超时，请重新加载。');
  await bounded(new Promise(resolve=>{
   const changed=()=>{
    if(navigator.serviceWorker.controller){navigator.serviceWorker.removeEventListener('controllerchange',changed);resolve();}
   };
   navigator.serviceWorker.addEventListener('controllerchange',changed);changed();
  }),10000,'浏览器未能启用启动组件，请重新加载。');
 }
 async function run(){
  if(!window.crossOriginIsolated){
   if(!window.isSecureContext||!navigator.serviceWorker)throw new Error('当前浏览器无法启用游戏所需的启动环境，请用最新版 Chrome 或系统浏览器打开。');
   if(query.searchParams.has('_coi'))throw new Error('当前浏览器未能启用多线程游戏环境，请允许站点数据，或更换新版浏览器。');
   status.textContent='首次访问，正在准备启动环境…';
   await control(await register());
   query.searchParams.set('_coi','1');
   location.replace(query.href);
   return;
  }
  if(query.searchParams.has('_coi')){
   query.searchParams.delete('_coi');history.replaceState(null,'',query.pathname+query.search+query.hash);
  }
  // On hosts that set isolation headers directly, caching is optional and never
  // blocks the game if Service Worker or Cache Storage is disabled.
  if(navigator.serviceWorker)register().catch(error=>console.warn('[CrescentHost] Cache unavailable:',error.message));
  if(checking){
   const result={crossOriginIsolated:window.crossOriginIsolated,sharedArrayBuffer:typeof SharedArrayBuffer==='function',baseURL:base.href,serviceWorker:!!navigator.serviceWorker?.controller,engineStarted:false};
   document.documentElement.dataset.crescentHosting='ready';
   status.textContent=JSON.stringify(result);
   return;
  }
  status.textContent='正在准备出海…';
  if(window.CrescentOcean){
   status.textContent='正在准备海浪与小岛…';
   await window.CrescentOcean.init();
   status.textContent='正在准备出海…';
  }
  const script=document.createElement('script');
  script.src=new URL('player.js',base).href;
  script.onerror=()=>fail(new Error('游戏启动脚本下载失败，请检查网络后重新加载。'));
  document.body.appendChild(script);
 }
 window.CrescentHost.ready=run().catch(fail);
})();
