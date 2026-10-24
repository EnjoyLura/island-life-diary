-- Explicit opt-in diagnostics. Never reads saves, accounts or tokens.
-- Update intervals describe engine cadence, not GPU time or display scanout.
local Settings=require("Game.RenderSettings")
local Stats=require("Game.PerformanceStats")
---@class CrescentPerformanceProbe
---@field enabled boolean
---@field manual table<string,string>
local P={enabled=false,manual={model="",conditions="",heat="未填写"},serial=0}
local FILE="crescent-performance-v1.json"
local BUILD="v41.0-nautical-ui"
-- GetSystemTime/GetTimeSinceEpoch are inconsistently bound as static methods
-- in this runtime. Use the same monotonic elapsed timer as UI gesture input.
local function clock()return math.floor(time:GetElapsedTime()*1000+.5)end
local function emit(kind,data)print("[CrescentPerf"..kind.."] "..cjson.encode(data))end
local function mode(app)return app.modal and ("menu:"..app.modal) or app.mode end
local function info(app)
 local scene=app and app.scene3d
 local render=scene and scene.GetRenderInfo and scene:GetRenderInfo()or nil
 return {width=graphics:GetWidth(),height=graphics:GetHeight(),dpr=graphics:GetDPR(),
  api=graphics:GetApiName(),platform=GetPlatform(),nativePlatform=GetNativePlatform(),scene=render}
end
function P.Init(app)if Settings.profile then P.Start(app)end end
function P.Start(app)
 if P.enabled then return end
 local now=clock();P.serial=P.serial+1
 P.id=string.format("%d-%d-%d",os.time(),now,P.serial)
 P.started=now;P.startedAt=os.time();P.finishedAt=nil;P.finished=nil;P.reason=nil
 P.total=Stats.New();P.scenes={};P.windows={};P.markers={};P.window=nil
 P.last=nil;P.updateStart=nil;P.nextRender=now;P.focused=true;P.pausedScene=nil
 P.worldFrames={};P.renderUpdate=0;P.renderLast=nil;P.renderLastUpdate=nil
 P.device=info(app);P.latest=nil;P.enabled=true;P.lastReport=nil
 emit("Session",{event="start",id=P.id,build=BUILD,targetFps=Settings.fps,
  device=P.device,source="engine-update-wall-clock",host=Settings.reportHost})
end
local function flush(reason)
 local window=P.window;P.window=nil
 if not window or window.stats.frames==0 then return end
 local report=Stats.Snapshot(window.stats)
 report.mode=window.mode;report.fromMs=window.from-P.started;report.toMs=P.last-P.started
 report.reason=reason;report.render=window.render;report.id=P.id
 P.windows[#P.windows+1]=report;P.latest=report
 emit("",report)
end
local function marker(event,now,extra)
 if #P.markers<240 then P.markers[#P.markers+1]={event=event,atMs=now-P.started,detail=extra}end
end
function P.Focus(focused)
 if not P.enabled or P.focused==focused then return end
 local now=clock();flush("focus-change");P.last=nil;P.updateStart=nil
 P.renderLast=nil;P.renderLastUpdate=nil
 P.focused=focused;marker(focused and "foreground" or "background",now)
end
function P.Boundary(app)
 if not P.enabled then return end
 flush("scene-change");P.last=nil;P.updateStart=nil;P.pausedScene=nil
 P.renderLast=nil;P.renderLastUpdate=nil
 marker("scene",clock(),mode(app))
end
function P.Record(app)
 if not P.enabled then return end
 P.renderUpdate=P.renderUpdate+1
 local now=clock();P.updateStart=nil
 if now-P.started>=3600000 or #P.windows>=720 then P.Finish("limit");return end
 -- InputFocus also fires while there are no Update events. Polling covers
 -- hosts exposing focus/minimized without dispatching that event.
 if input and (input.minimized or input.focus==false)then P.Focus(false);return end
 if not P.focused then P.Focus(true)end
 local scene=mode(app)
 if scene=="menu:performance" then
  if P.pausedScene~=scene then flush("report-page");marker("report-page",now);P.pausedScene=scene end
  P.last=nil;return
 end
 P.pausedScene=nil
 if P.window and P.window.mode~=scene then flush("scene-change");P.last=nil end
 if not P.window then P.window={mode=scene,from=P.last or now,stats=Stats.New()}end
 if not P.scenes[scene]then P.scenes[scene]=Stats.New()end
 if P.last then
  local dt=now-P.last
  if dt>=0 then
   -- Zero-ms intervals count too; discarding them biases high FPS down.
   Stats.Frame(P.window.stats,dt,Settings.fps);Stats.Frame(P.scenes[scene],dt,Settings.fps)
   Stats.Frame(P.total,dt,Settings.fps)
  else marker("clock-discontinuity",now)end
 end
 P.last=now;P.updateScene=scene
 if now>=P.nextRender then
  local render={batches=renderer:GetNumBatches(),primitives=renderer:GetNumPrimitives(),
   luaKiB=collectgarbage("count"),resourceBytes=cache:GetTotalMemoryUse()}
  local device=info(app);render.width=device.width;render.height=device.height;render.dpr=device.dpr
  render.scene=device.scene
  P.window.render=render
  Stats.Render(P.window.stats,render);Stats.Render(P.scenes[scene],render);Stats.Render(P.total,render)
  P.nextRender=now+1000
 end
 P.updateStart=clock()
end
-- Count completed game views separately from Update callbacks. Multiple views
-- for the same scene/camera in one update are exposed but count as one frame.
function P.ViewRendered(app,data)
 if not P.enabled or not P.focused or app.modal then return end
 local scene=app.scene3d
 if not scene or data:GetPtr("Scene")~=scene.scene or data:GetPtr("Camera")~=scene.camera then return end
 local name=app.mode;local s=P.worldFrames[name]
 if not s then s={frames=0,viewPasses=0,intervals=0,elapsedMs=0};P.worldFrames[name]=s end
 s.viewPasses=s.viewPasses+1
 if P.renderLastUpdate==P.renderUpdate then return end
 P.renderLastUpdate=P.renderUpdate;s.frames=s.frames+1
 local now=clock();local previous=P.renderLast
 if previous and previous.mode==name and now>=previous.at then
  s.intervals=s.intervals+1;s.elapsedMs=s.elapsedMs+now-previous.at
 end
 P.renderLast={mode=name,at=now}
end
function P.Complete(app)
 if not P.enabled or not P.updateStart then return end
 local now=clock();local ms=math.max(0,now-P.updateStart);P.updateStart=nil
 if P.window and P.updateScene==mode(app)then
  Stats.Update(P.window.stats,ms);Stats.Update(P.scenes[P.updateScene],ms);Stats.Update(P.total,ms)
  if now-P.window.from>=10000 then flush("interval")end
 end
end
function P.Snapshot()
 if not P.id then return nil end
 local rendered={}
 for name,s in pairs(P.worldFrames)do
  rendered[name]={frames=s.frames,viewPasses=s.viewPasses,activeSeconds=s.elapsedMs/1000,
   fps=s.elapsedMs>0 and math.floor(s.intervals*100000/s.elapsedMs+.5)/100 or 0}
 end
 local scenes={};for name,s in pairs(P.scenes)do scenes[name]=Stats.Snapshot(s)end
 local windows={};for i,w in ipairs(P.windows)do windows[i]=w end
 if P.window and P.window.stats.frames>0 then
  local w=Stats.Snapshot(P.window.stats);w.mode=P.window.mode;w.fromMs=P.window.from-P.started
  w.toMs=P.last-P.started;w.reason="partial";w.render=P.window.render;windows[#windows+1]=w
 end
 return {schema="crescent-performance/1",id=P.id,build=BUILD,startedAtUnix=P.startedAt,
  finishedAtUnix=P.finishedAt,state=P.enabled and "recording" or "stopped",stopReason=P.reason,
  targetFps=Settings.fps,ocean=Settings.legacy and "legacy" or "v24",host=Settings.reportHost,
  wallSeconds=math.max(0,((P.finished or clock())-P.started)/1000),device=P.device,
  selfReported={model=P.manual.model,conditions=P.manual.conditions,heat=P.manual.heat,source="manual"},
  total=Stats.Snapshot(P.total),scenes=scenes,windows=windows,markers=P.markers,
  sceneRendering={source="EndViewRender for game Scene/Camera; deduplicated per Update; CPU view submission, not GPU completion or displayed FPS",scenes=rendered},
  measurement={frame="engine Update-to-Update wall interval",resolutionMs=1,
   luaUpdate="App.Update wall time only; excludes UI draw, renderer and GPU",
   counters="previous rendered frame sampled at 1 Hz; resource bytes are not process RSS",
   percentile="1 ms bins; intervals over 2000 ms use maximum in overflow bin",
   background="excluded when InputFocus/minimized identifies it; foreground stalls retained",
   reportPage="excluded",transition="boundary intervals excluded and marked",
   jankThresholdMs=math.max(33.4,2000/Settings.fps)},
  unavailable={"gpuTimeMs","totalCpuTimeMs","temperatureC","powerWatts","thermalThrottling","displayPresentedFps"}}
end
function P.Finish(reason)
 if not P.enabled then return end
 flush("stop");P.finished=clock();P.finishedAt=os.time();P.reason=reason or "user"
 P.enabled=false;P.last=nil;P.updateStart=nil
 emit("Session",{event="stop",id=P.id,reason=P.reason,total=Stats.Snapshot(P.total)})
end
function P.Generate()
 if not P.id then return false,"请先开启采集，返回游戏游玩后再生成报告" end
 P.Finish("user")
 local report=P.Snapshot();local text=cjson.encode(report);P.lastReport=text
 local saved=pcall(function()
  local file=File(FILE,FILE_WRITE);assert(file:IsOpen(),"report file unavailable")
  file:WriteString(text);file:Close()
 end)
 -- Bounded UTF-8 chunks survive Maker line limits, exported only on demand.
 local chunks={};local first=1
 while first<=#text do
  local last=math.min(#text,first+1199)
  while last<#text and text:byte(last+1)>=128 and text:byte(last+1)<192 do last=last-1 end
  chunks[#chunks+1]=text:sub(first,last);first=last+1
 end
 for i,chunk in ipairs(chunks)do emit("Export",{id=P.id,part=i,total=#chunks,text=chunk})end
 return true,saved and "报告已生成并写入运行日志，可复制发回；网页也可下载或分享" or "报告已写入运行日志；本机文件不可用，请复制报告"
end
function P.Copy()
 local generated,message=P.Generate();if not generated then return false,message end
 local ok,copied=pcall(function()
  ui.useSystemClipboard=true;ui:SetClipboardText(P.lastReport)
  return ui:GetClipboardText()==P.lastReport
 end)
 return ok and copied,ok and copied and "性能报告已复制，可以粘贴发给我" or "系统剪贴板不可用；网页请在报告面板复制或下载，制造版可读取运行日志"
end
function P.Status()
 if not P.id then return "尚未开始采集" end
 local total=Stats.Snapshot(P.total)
 local text=string.format("%s · %.0f 秒 · %.1f FPS · P95 %d ms\n超过 100 ms：%d 帧 · 报告 %s",
  P.enabled and "采集中" or "已结束",total.activeSeconds,total.fps,total.p95Ms,total.over100Ms,P.id)
 for _,name in ipairs({"home","sailing","map","fishing","shore"})do
  local s=P.scenes[name]
  if s and s.frames>0 then local snap=Stats.Snapshot(s)
   text=text..string.format("\n%s：%.0f 秒 / %.1f FPS / P95 %d ms",name,snap.activeSeconds,snap.fps,snap.p95Ms)
  end
 end
 return text
end
return P
