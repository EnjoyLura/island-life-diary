-- Bounded 1 ms histograms; intervals use wall time, never simulation dt.
local S={}
function S.New()
 return {frames=0,elapsedMs=0,maxMs=0,hist={},over33Ms=0,over50Ms=0,over100Ms=0,jank=0,
  updateCount=0,updateMs=0,maxUpdateMs=0,renderSamples=0,batches=0,maxBatches=0,
  primitives=0,maxPrimitives=0,maxLuaKiB=0,maxResourceBytes=0}
end
function S.Frame(s,ms,target)
 if ms<0 or ms~=ms or ms==math.huge then return end
 s.frames=s.frames+1;s.elapsedMs=s.elapsedMs+ms;s.maxMs=math.max(s.maxMs,ms)
 local bin=math.min(2001,math.ceil(ms));s.hist[bin]=(s.hist[bin] or 0)+1
 if ms>33.4 then s.over33Ms=s.over33Ms+1 end
 if ms>50 then s.over50Ms=s.over50Ms+1 end
 if ms>100 then s.over100Ms=s.over100Ms+1 end
 if ms>math.max(33.4,2000/target) then s.jank=s.jank+1 end
end
function S.Update(s,ms)
 s.updateCount=s.updateCount+1;s.updateMs=s.updateMs+ms;s.maxUpdateMs=math.max(s.maxUpdateMs,ms)
end
function S.Render(s,r)
 s.renderSamples=s.renderSamples+1;s.batches=s.batches+r.batches;s.primitives=s.primitives+r.primitives
 s.maxBatches=math.max(s.maxBatches,r.batches);s.maxPrimitives=math.max(s.maxPrimitives,r.primitives)
 s.maxLuaKiB=math.max(s.maxLuaKiB,r.luaKiB);s.maxResourceBytes=math.max(s.maxResourceBytes,r.resourceBytes)
end
local function percentile(s,fraction)
 local target=math.ceil(s.frames*fraction);local count=0
 if target==0 then return 0 end
 for bin=0,2001 do
  count=count+(s.hist[bin] or 0)
  if count>=target then return bin==2001 and s.maxMs or bin end
 end
 return s.maxMs
end
local function round(n)return math.floor(n*100+.5)/100 end
function S.Snapshot(s)
 local n=math.max(1,s.frames);local r=math.max(1,s.renderSamples)
 return {frames=s.frames,activeSeconds=round(s.elapsedMs/1000),
  fps=s.elapsedMs>0 and round(s.frames*1000/s.elapsedMs) or 0,meanMs=round(s.elapsedMs/n),
  p50Ms=percentile(s,.5),p95Ms=percentile(s,.95),p99Ms=percentile(s,.99),maxMs=s.maxMs,
  over33Ms=s.over33Ms,over50Ms=s.over50Ms,over100Ms=s.over100Ms,jank=s.jank,
  luaUpdateMeanMs=round(s.updateMs/math.max(1,s.updateCount)),luaUpdateMaxMs=s.maxUpdateMs,
  renderSamples=s.renderSamples,meanBatches=round(s.batches/r),maxBatches=s.maxBatches,
  meanPrimitives=round(s.primitives/r),maxPrimitives=s.maxPrimitives,
  peakLuaKiB=round(s.maxLuaKiB),peakResourceBytes=s.maxResourceBytes}
end
return S
