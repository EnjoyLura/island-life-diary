const SCOPE=new URL(self.registration.scope).pathname;
const CACHE='crescent-static-v4:'+SCOPE;
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('fetch',event=>{
 const request=event.request,url=new URL(request.url);
 if(request.method!=='GET'||url.origin!==self.location.origin||!url.pathname.startsWith(SCOPE))return;
 if(request.cache==='only-if-cached'&&request.mode!=='same-origin')return;
 const relative=url.pathname.slice(SCOPE.length);
 const isolated=response=>{
  if(response.status===0)return response;
  const headers=new Headers(response.headers);
  headers.set('Cross-Origin-Opener-Policy','same-origin');
  headers.set('Cross-Origin-Embedder-Policy','require-corp');
  headers.set('Cross-Origin-Resource-Policy','same-origin');
  return new Response(response.body,{status:response.status,statusText:response.statusText,headers});
 };
 // Cache only content-addressed assets. Version pointers and manifests must
 // reach the server so the next visit can discover an updated game build.
 const immutable=/^(?:vendor\/[^/]+|game)\/assets\//.test(relative);
 const key=new Request(url.origin+url.pathname);
 event.respondWith((async()=>{
  let cache;
  if(immutable){
   try{cache=await caches.open(CACHE);const hit=await cache.match(key);if(hit)return isolated(hit);}catch{}
  }
  const response=await fetch(request);
  if(cache&&response.ok)event.waitUntil(cache.put(key,response.clone()).catch(()=>{}));
  return isolated(response);
 })());
});
