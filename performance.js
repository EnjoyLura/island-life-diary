// Opt-in Lua diagnostics bridge. No RAF loop, polling, network upload or IDs.
// Maker handles its own runtime logs. Public browsers export a local report.
(()=>{
 const KEY='crescent-island:performance:v1',MAX=1500000;
 let session=null,report=null,parts=null,panel=null,opener=null,summary=null,output=null,message=null;
 const samples=[];
 function browserInfo(){
  return {host:'public-web',userAgent:navigator.userAgent||'',language:navigator.language||'',
   viewport:{width:window.innerWidth,height:window.innerHeight,dpr:window.devicePixelRatio},
   hardwareConcurrency:navigator.hardwareConcurrency||null,deviceMemoryGiB:navigator.deviceMemory||null,
   frameBudget:window.CrescentFrameBudget?.fps||60};
 }
 function persist(){
  try{const text=JSON.stringify({session,report,samples});if(text.length<=MAX)localStorage.setItem(KEY,text);}catch{}
 }
 function snapshot(){
  return report||{schema:'crescent-performance/1',id:session?.id||'partial',state:'partial',
   build:session?.build,device:session?.device,targetFps:session?.targetFps,
   windows:samples.map(s=>({...s})),browser:session?.browser||browserInfo(),
   note:'Unfinished session recovered from 10-second windows; no complete aggregate.'};
 }
 function text(){return JSON.stringify(snapshot(),null,2);}
 function showMessage(value){if(message)message.textContent=value;}
 function download(){
  const blob=new Blob([text()],{type:'application/json'}),url=URL.createObjectURL(blob);
  const a=document.createElement('a');a.href=url;a.download='island-performance-'+snapshot().id+'.json';
  document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
  showMessage('报告已下载，把 JSON 文件发回聊天即可。');
 }
 async function copy(){
  try{
   if(!navigator.clipboard?.writeText)throw new Error('clipboard unavailable');
   await navigator.clipboard.writeText(text());showMessage('报告已复制，可以粘贴发回聊天。');
  }catch{
   output.focus();output.select();
   showMessage('浏览器未允许自动复制，报告已选中，请长按复制；也可下载文件。');
  }
 }
 async function share(){
  try{
   const file=new File([text()],'island-performance-'+snapshot().id+'.json',{type:'application/json'});
   if(!navigator.canShare?.({files:[file]})||!navigator.share){download();return;}
   await navigator.share({files:[file],title:'海岛生活日记 · 性能报告'});
  }catch(error){if(error.name!=='AbortError')showMessage('分享不可用，请复制或下载报告。');}
 }
 function makeUI(){
  if(panel)return;
  const element=(tag,parent,content)=>{const e=document.createElement(tag);if(content)e.textContent=content;if(parent)parent.append(e);return e;};
  opener=element('button',document.body,'查看性能报告');opener.id='performance-open';opener.hidden=true;
  panel=element('section',document.body);panel.id='performance-report';panel.hidden=true;
  panel.setAttribute('role','dialog');panel.setAttribute('aria-modal','true');panel.setAttribute('aria-label','真机性能报告');
  const card=element('div',panel);card.className='performance-card';
  element('h2',card,'真机性能报告');summary=element('p',card);
  element('p',card,'复制、下载或分享报告，再发回聊天。这里只保存在本机，不会自动传到服务器。');
  const actions=element('div',card);actions.className='performance-actions';
  for(const [title,fn]of [['复制报告',copy],['下载 JSON',download],['分享',share],['回到游戏',()=>{panel.hidden=true;}]]){
   const button=element('button',actions,title);button.addEventListener('click',fn);
  }
  message=element('p',card);message.setAttribute('role','status');
  output=element('textarea',card);output.readOnly=true;output.setAttribute('aria-label','性能报告 JSON');
  opener.addEventListener('click',open);
 }
 function open(){
  makeUI();opener.hidden=false;panel.hidden=false;output.value=text();
  const data=snapshot(),stats=data.total;
  summary.textContent=stats?`${data.id} · ${stats.activeSeconds} 秒 · ${stats.fps} FPS · P95 ${stats.p95Ms} ms`:
   `${data.id} · 已保留 ${samples.length} 段采样（测试尚未完整结束）`;
  showMessage('');
 }
 function receive(line){
  const match=line.match(/\[CrescentPerf(Session|Export)?\]\s*(\{.*\})/);
  if(!match)return;
  let data;try{data=JSON.parse(match[2]);}catch{return;}
  const kind=match[1]||'window';
  if(kind==='Session'&&data.event==='start'){
   session={...data,browser:browserInfo()};report=null;parts=null;samples.length=0;
   if(opener)opener.hidden=true;persist();return;
  }
  if(kind==='window'){
   if(session?.id&&data.id&&data.id!==session.id)return;
   samples.push(data);if(samples.length>720)samples.shift();persist();return;
  }
  if(kind!=='Export')return;
  if(typeof data.id!=='string'||!Number.isInteger(data.part)||!Number.isInteger(data.total)||
    data.part<1||data.part>data.total||data.total>1200||typeof data.text!=='string'||data.text.length>6000)return;
  if(session?.id&&data.id!==session.id)return;
  if(!parts||parts.id!==data.id||parts.total!==data.total)parts={id:data.id,total:data.total,values:new Map(),bytes:0};
  if(!parts.values.has(data.part)){parts.values.set(data.part,data.text);parts.bytes+=data.text.length;}
  if(parts.bytes>MAX){parts=null;return;}
  if(parts.values.size!==parts.total)return;
  try{
   const joined=Array.from({length:parts.total},(_,i)=>parts.values.get(i+1)).join('');
   const complete=JSON.parse(joined);
   if(complete.schema!=='crescent-performance/1'||complete.id!==parts.id)throw new Error('Invalid report');
   complete.browser=session?.browser||browserInfo();report=complete;parts=null;persist();open();
  }catch{parts=null;}
 }
 const original=console.log.bind(console);
 console.log=(...args)=>{original(...args);for(const arg of args)if(typeof arg==='string'&&arg.includes('[CrescentPerf'))receive(arg);};
 // Restore only this diagnostic key. Nothing is written until explicit opt-in.
 try{
  const raw=localStorage.getItem(KEY);
  if(raw&&raw.length<=MAX){
   const saved=JSON.parse(raw);session=saved.session||null;
   report=saved.report?.schema==='crescent-performance/1'?saved.report:null;
   if(Array.isArray(saved.samples))samples.push(...saved.samples.slice(-720));
   if(report||samples.length){makeUI();opener.hidden=false;}
  }
 }catch{}
 window.CrescentPerformance={snapshot:()=>({...snapshot(),samples:samples.map(s=>({...s}))}),open};
})();
