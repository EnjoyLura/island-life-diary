// This shell serves public static files; no Maker credentials are shipped.
(()=>{
 const base=new URL('.',document.currentScript.src);
 window.CrescentHost={baseURL:base.href};
 const url=new URL(location.href);
 for(const [key,value] of Object.entries({game_url:new URL('game/',base).href,skip_login:'1',screen_orientation:'portrait',disableOPFS:'1',embed:'1'}))if(!url.searchParams.has(key))url.searchParams.set(key,value);
 history.replaceState(null,'',url.pathname+url.search+url.hash);
 window.WASM_PLAYER_CONFIG={verbose:false};
 const requestedFps=Number(url.searchParams.get('fps'));
 const reportFps=requestedFps>=30&&requestedFps<=120?Math.floor(requestedFps):60;
 const scale=Number(url.searchParams.get('worldscale'));
 const worldScale=[.5,.75,1].includes(scale)?scale:1;
 const args=['-skip_login','-hostpacing','-reporthost=public-web','-fps='+reportFps,'-worldscale='+worldScale];
 if(url.searchParams.get('ocean')==='off')args.push('-ocean=off');
 window.Module={arguments:args};
 const originalFetch=window.fetch.bind(window);
 // Built-in source URLs use the vendor's public CDN; keep those requests on
 // this site's mirrored dependencies so a game load has one hosting origin.
 window.fetch=async(input,init)=>{
  const original=typeof input==='string'?input:input instanceof URL?input.href:input.url;
  const parsed=new URL(original,location.href);
  if(parsed.hostname==='tapcode-sce.spark.xd.com'&&parsed.pathname.startsWith('/src/')){
   const local=new URL('vendor/'+parsed.pathname.slice(5)+parsed.search,base).href;
   input=input instanceof Request?new Request(local,input):local;
  }
  const response=await originalFetch(input,init);
  // Serve compressed engine bytes as ordinary static binary assets. Some
  // CDNs compress again when Content-Encoding is set via a header override.
  // Decode explicitly so hosting compression cannot corrupt the WASM bytes.
  if(response.ok&&/\.(wasm|data)\.gz$/.test(parsed.pathname)){
   if(typeof DecompressionStream==='undefined')throw new Error('浏览器版本过旧，请更新 Chrome 或 Safari 后重试');
   const headers=new Headers(response.headers);headers.delete('content-encoding');headers.delete('content-length');
   headers.set('content-type',parsed.pathname.endsWith('.wasm.gz')?'application/wasm':'application/octet-stream');
   return new Response(response.body.pipeThrough(new DecompressionStream('gzip')),{status:response.status,headers});
  }
  return response;
 };
})();
