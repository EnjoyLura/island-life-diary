-- Game controller, based on scaffold-2d.lua. UI owns the only NVG frame.
local UI = require("urhox-libs/UI")
local Widgets = require("Game.Widgets")
local World = require("Game.World")
local State = require("Game.State")
local Catalog = require("Game.Catalog")
local A = require("Game.Art")
---@type IslandHUD
local HUD = require("Game.HUD")
---@type IslandMenus
local Menus = require("Game.Menus")
local SeaChart = require("Game.SeaChart")
local Bay = require("Game.Bay")
local FishingView = require("Game.FishingView")
local FishTraffic = require("Game.FishTraffic")
local FishingCast = require("Game.FishingCast")
local SharkPatrol = require("Game.SharkPatrol")
local ShoreWorld = require("Game.ShoreWorld")
local ForestWorld = require("Game.ForestWorld")
local PerformanceUI = require("Game.PerformanceUI")
local RenderProbe = require("Game.RenderProbe")
---@class IslandApp
---@field menu table
---@field particles table[]
---@field pointers table
---@field buttons table
---@field listeners table[]
---@field landmarks table[]?
---@field menuScrollTop number?
---@field menuScrollBottom number?
---@field modal string?
---@field host Widget
---@field pendingCatch IslandCatch?
---@field nearTarget table?
---@field newDiscovery boolean?
---@field lastTotals IslandTotals?
---@field rescueNotice boolean?
---@field aimPointer number?
---@field reelPointer number?
---@field castStart number?
---@field castOrigin table?
---@field castHeld boolean?
---@field reelHeld boolean?
---@field scene3d table?
---@field islandYaw number?
---@field landmarkLabels table[]?
---@field hudTop number
---@field lookJoy table
---@field forest table
local App = {}; App.__index = App
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function distance(x,y,a,b) return math.sqrt((x-a)^2+(y-b)^2) end
local function angleDelta(a,b) return (b-a+math.pi)%(math.pi*2)-math.pi end
local SAVE = "crescent-island-v1.json"

---@return IslandApp
function App.new()
 ---@type IslandApp
 local self=setmetatable({},App)
 self.profile=State.new();self.mode="home";self.menu={quality=1,category="fish",scroll=0}
 self.time=0;self.playtime=0;self.h=800;self.scale=1;self.x=0;self.y=0;self.hudTop=56
 self.camera={x=500,y=1000,zoom=.38};self.boat={x=1000,y=1350,heading=0,speed=0}
 self.shore={x=900,y=1050,targets={}};self.fish={stage="idle",power=.5,progress=0,viewX=0,viewY=0}
 self.fishSchools={};self.fishingTaken={};self.reefs={};self.particles={};self.buttons={};self.pointers={}
 self.joy={active=false,x=82,y=650,dx=0,dy=0};self.listeners={};self.dirty=true
 self.lookJoy={active=false,x=367,y=650,dx=0,dy=0}
 self.toastText="";self.toastUntil=0;self.transition=1;self.saveClock=0
 self:Load();self:CreateSea();self:CreateShore();self:CreateForest()
 if self.profile.trip then
  self.mode=self.profile.trip.kind=="forest" and "forest" or self.profile.trip.kind=="shore" and "shore" or "sailing"
  self:ResetCamera()
 end
 return self
end

function App:Load()
 if fileSystem and not fileSystem:FileExists(SAVE) then return end
 local ok,data=pcall(function()
  local f=File(SAVE,FILE_READ);if not f:IsOpen() then return nil end
  local raw=f:ReadString();f:Close();return cjson.decode(raw)
 end)
 if ok and type(data)=="table" then
  self.profile=State.restore(data)
  if self.profile.trip and type(data.fishingTaken)=="table"then
   for i=0,12 do local key=i==0 and "coast"or"school:"..i;local value=data.fishingTaken[key]
    if type(value)=="number"and value==value and math.abs(value)<math.huge then
     self.fishingTaken[key]=clamp(math.floor(value),0,i==0 and FishTraffic.coastCount or FishTraffic.schoolCount)
    end
   end
  end
 end
end
function App:Save()
 if self.profile.trip and self.profile.trip.kind=="forest" and self.forest then
  self.profile.trip.forestPose=ForestWorld.Snapshot(self.forest)
 end
 local ok,err=pcall(function()
  local f=File(SAVE,FILE_WRITE);if not f:IsOpen() then error("save file unavailable") end
  local saved=State.export(self.profile)
  saved.fishingTaken=self.profile.trip and self.fishingTaken or nil
  f:WriteString(cjson.encode(saved));f:Close()
 end)
 if not ok then print("[Crescent] save unavailable: "..tostring(err)) end
 return ok
end
function App:Start()
 local function listen(name,fn) self.listeners[#self.listeners+1]={name,UI.Input.On(name,fn,50)} end
 -- InputAdapter dispatches global listeners BEFORE UI converts physical pixels
 -- to base pixels. Widget PointerDown already uses base pixels. Copy instead
 -- of mutating the shared event, so UI and Gesture each normalize it once.
 listen("PointerMove",function(e)
  local scale=UI.GetScale()
  self:PointerMove({pointerId=e.pointerId,x=e.x/scale,y=e.y/scale})
 end)
 listen("PointerUp",function(e)if e:IsPrimaryAction() then self:PointerUp(e,false) end end)
 listen("PointerCancel",function(e)self:PointerUp(e,true)end)
 self:BuildUI();self:Toast("欢迎来到月牙岛 · 点码头出海，点沙滩赶海",5)
end
function App:Stop()
 if self.scene3d then self.scene3d:Stop() end
 for _,v in ipairs(self.listeners) do UI.Input.Off(v[1],v[2]) end
 self.listeners={}
end
function App:MarkUI() self.dirty=true end
function App:Toast(message,seconds) self.toastText=tostring(message);self.toastUntil=self.time+(seconds or 2.8) end
function App:CancelGestures()
 self.pointers={};self.joy.active=false;self.joy.dx=0;self.joy.dy=0
 if self.lookJoy then self.lookJoy.active=false;self.lookJoy.dx=0;self.lookJoy.dy=0 end
 if self.shore then self.shore.vx=0;self.shore.vz=0 end
 if self.forest then self.forest.vx=0;self.forest.vz=0 end
 self.aimPointer=nil;self.reelPointer=nil;self.reelHeld=false;self.castHeld=false
 if self.fish.stage=="aim" then self.fish.stage="idle";self.fish.charge=0 end
end
function App:SetMode(mode)
 self:CancelGestures();self.mode=mode;self.modal=nil;self.menu.scroll=0
 RenderProbe.Boundary(self)
 self.transition=0;self:ResetCamera();self:MarkUI();self:Save()
end
function App:ResetCamera()
 if self.mode=="home" then self.camera={x=500,y=1000,zoom=math.min(.43,self.h/2050)}
 elseif self.mode=="map" then self.camera=SeaChart.Fit(self)
 elseif self.mode=="shore" then self.camera={x=self.shore.x,y=self.shore.y,zoom=.68}
 elseif self.mode=="forest" then self.camera={x=self.forest.x,y=self.forest.y,zoom=.68}
 else self.camera={x=self.boat.x,y=self.boat.y,zoom=.64} end
end
function App:OpenModal(name,opts)
 self:CancelGestures();self.modal=name;self.menu.scroll=0;self.toastUntil=0
 RenderProbe.Boundary(self)
 if opts then for k,v in pairs(opts) do self.menu[k]=v end end
 if name=="encyclopedia" then
  self.menu.category=self.mode=="forest" and "forest" or (self.mode=="shore") and "shore" or (self.menu.category or "fish")
  local list=Catalog.list(self.menu.category)
  self.menu.selected=self.menu.selected or list[1].id
 end
 self:MarkUI()
end
function App:CloseModal() self:CancelGestures();self.modal=nil;self.menu.scroll=0;RenderProbe.Boundary(self);self:MarkUI() end
function App:Depart(kind)
 local ok,msg=State.startTrip(self.profile,kind)
 if not ok then self:Toast(msg);return end
 self.boat={x=1000,y=1350,heading=0,speed=0};self.rescueNotice=false;self.fishingTaken={}
 if kind=="shore" then self:CreateShore();self:SetMode("shore");self:Toast("左摇杆走路 · 右摇杆观察 · 点击前方生物收获",5)
 elseif kind=="forest" then
  self:CreateForest();self:SetMode("forest");self:Toast("沿林径探索密林与溪流 · 走近后直接点击采集",5)
 else self:SetMode("sailing");self:Toast("拖动海面开船 · 靠近鱼影后开始钓鱼") end
end
function App:ReturnHome()
 if self.shore.action then self:Toast("先收好这份收获");return end
 self.lastTotals=State.endTrip(self.profile);self.pendingCatch=nil;self.pendingFishActor=nil;self.fishingTaken={};self:SetMode("home")
 self:Toast("平安归来！收获已带回，可到收购摊售卖",4)
 if self.lastTotals.count>0 then self:OpenModal("cargo") end
end
function App:SellAll()
 local t=State.sellAll(self.profile);self.lastTotals=t
 if t.count==0 then self:Toast("还没有可以售卖的收获")
 else self:Toast("售出 "..t.count.." 份收获  +"..t.value.." 金币",4);self:Spark(225,150,22,true) end
 self:Save();self:MarkUI()
end
function App:KeepCatch()
 if not self.pendingCatch then return end
 local ok,msg=State.keep(self.profile,self.pendingCatch)
 if not ok then self:Toast(msg);return end
 self.pendingCatch=nil;self.pendingFishActor=nil;self.fish.stage="idle";self:CloseModal();self:Save()
 self:Spark(76,45,12,true);self:Toast("已收入鱼护 · 返航前不可移除")
end
function App:ReleaseCatch()
 if not self.pendingCatch then return end
 if self.pendingFishActor then
  FishTraffic.Return(self.fish,self.pendingFishActor,self.playtime)
  local key=self.fish.spotKey
  if not self.pendingFishActor.guest then self.fishingTaken[key]=math.max(0,(self.fishingTaken[key]or 0)-1)end
 end
 self.pendingCatch=nil;self.pendingFishActor=nil;self.fish.stage="idle";self:CloseModal();self:Save();self:Toast("鱼儿回到海里了")
end
function App:StartFishing()
 if not self.profile.trip then return end
 self.fish={stage="idle",power=.5,progress=0,viewX=0,viewY=0,aimX=225,aimY=self.h*.44}
 local nearest,best,spotKey=nil,math.huge,"coast"
 for index,school in ipairs(self.fishSchools) do
  local d=distance(self.boat.x,self.boat.y,school.x,school.y)
  if d<best then nearest,best,spotKey=school,d,"school:"..index end
 end
 self.fish.population={}
 local count=best<150 and FishTraffic.schoolCount or best<280 and 8 or best<420 and 4 or 0
 if self.profile.trip.kind=="coast" then count=FishTraffic.coastCount;nearest=self.fishSchools[1];spotKey="coast" end
 self.fish.spotKey=spotKey
 count=math.max(0,count-(self.fishingTaken[spotKey]or 0))
 for i=1,count do
  self.fish.population[i]=(i%3~=0 and nearest and nearest.species) or Catalog.fish[(i-1)%5+1]
 end
 self.fish.actors=FishTraffic.New(self.fish.population,self.playtime,math.random(1,2147483646))
 self:SetMode("fishing")
 self:Toast(count==0 and "这里鱼影较少，耐心等候游鱼经过" or "点按近抛 · 长按蓄力投远，拖动瞄准",4)
end
function App:ResetFishingView()
 if self.modal or self.mode~="fishing" or self.castHeld then return end
 self.fish.viewX=0;self.fish.viewY=0
end
function App:ExitFishing()
 if self.fish.stage=="hooked" then self:Toast("先收起这一竿，或松手让鱼儿游走");return end
 self.fish.stage="idle";FishTraffic.Cancel(self.fish,self.playtime);self:SetMode("sailing")
end
function App:CreateSea()
 self.reefs={{x=650,y=1080,radius=78},{x=3000,y=-600,radius=65},{x=3400,y=2700,radius=90},
 {x=2400,y=700,radius=80},{x=1400,y=3600,radius=72},{x=2900,y=-1200,radius=95}}
 self.fishSchools={}
 -- Nearshore, central and offshore encounters fill the developed eastern sea.
 -- The other two regions reserve space without multiplying active actors.
 for i,p in ipairs({{1700,-2700},{4800,-2800},{7900,-2500},{2000,200},{4800,-400},{1080,1220},
  {8200,700},{1900,3500},{1600,4900},{7800,4300},{4700,5000},{5600,2500}}) do
  local k=(i-1)%8+1;self.fishSchools[#self.fishSchools+1]={x=p[1],y=p[2],id=Catalog.fish[k].id,count=4+(i%3==0 and 1 or 0),phase=i*1.7,species=Catalog.fish[k]}
 end
 self.sharks={SharkPatrol.New(6200,1100,900,1400,0,.18),SharkPatrol.New(5200,3800,850,1000,1.7,-.14)}
end
function App:CreateShore()
 self.shore=ShoreWorld.New(Catalog.shore);self.nearTarget=nil
end
function App:Interact(target,method)
 if self.mode~="shore" or self.modal or not target or target.collected then return end
 if not ShoreWorld.InReach(self.shore,target)then self:Toast("走到前方收获附近即可点击");return end
 local kind=target.kind;method=method or (kind=="hole" and "salt" or kind=="mound" and "dig" or "tongs")
 if method=="dig" and not self.profile.shovel then self:Toast("需要铁锹，到杂货铺购买");return end
 local cost=method=="dig" and 3 or 1;local saltCost=method=="salt" and 1 or 0
 if self.profile.stamina<cost then self:OpenModal("food");return end
 if self.profile.salt<saltCost then self:Toast("盐用完了，可以改用铁锹挖");return end
 if State.used(self.profile)+Catalog.find(target.id).slots>State.capacity(self.profile) then self:Toast("水桶满了，带收获回家吧");return end
 local ok,msg,item=State.collect(self.profile,target.id,cost,saltCost)
 if ok then
  target.collected=true;self.shore.pickupUntil=self.playtime+.36
  self:Spark(target.x,target.y,14,false,"sand")
  self:Toast("收获 "..Catalog.find(item.id).name.."  +"..string.format("%.2f",item.weight).."kg")
  self:Save()
 else self:Toast(msg)end
 self:MarkUI()
end
function App:Spark(x,y,count,screen,kind)
 for i=1,count do local a=i*2.399;local speed=15+i*2
  self.particles[#self.particles+1]={x=x,y=y,born=self.time,life=.7+(i%4)*.12,vx=math.cos(a)*speed,vy=math.sin(a)*speed-22,size=2+i%3,screen=screen,kind=kind}
 end
end
function App:UpdateCastAim()
 local f=self.fish
 if self.scene3d then
  local p,x,y,reach=self.scene3d:CastTarget(f.guideX,f.guideY,f.charge or 0)
  f.castPoint=p;f.aimX=x;f.aimY=y;f.castRange=reach
 else f.aimX=f.guideX;f.aimY=f.guideY;f.castRange=12+24*(f.charge or 0)end
end
function App:CastPress(event)
 if self.modal then return end
 if self.fish.stage=="hooked" then self.reelHeld=true;self.reelPointer=event.pointerId;return end
 if self.fish.stage=="waiting" then self.fish.stage="idle";FishTraffic.Cancel(self.fish,self.playtime);self:MarkUI();return end
 if self.fish.stage~="idle" then return end
 if self.profile.stamina<2 then self:OpenModal("food");return end
 self.castHeld=true;self.castStart=self.time;self.aimPointer=event.pointerId
 local x,y=self:Local(event);self.castOrigin={x=x,y=y}
 self.fish.charge=0;self.fish.guideX=225;self.fish.guideY=self.h*.43
 if self.scene3d then self.fish.guideX,self.fish.guideY=self.scene3d:ClampAim(self.fish.guideX,self.fish.guideY)end
 self:UpdateCastAim()
end
function App:CastRelease(cancelled)
 self.reelHeld=false;self.reelPointer=nil
 if not self.castHeld then return end
 self.castHeld=false;self.aimPointer=nil
 if cancelled then self.fish.stage="idle";self.fish.charge=0;return end
 self:UpdateCastAim()
 self.fish.castDuration=FishingCast.Duration(self.fish.castRange)
 self.fish.castSerial=(self.fish.castSerial or 0)+1
 self.profile.stamina=math.max(0,self.profile.stamina-2)
 self.fish.stage="casting";self.fish.castT=0;self.fish.castElapsed=0;self.fish.flickT=0;self.fish.progress=0;self.fish.danger=0;self:MarkUI();self:Save()
 FishTraffic.Cancel(self.fish,self.playtime)
 self.fish.species=nil;self.fish.waited=0;self.fish.noBiteElapsed=0;self.fish.scan=0
 if self.scene3d then
  local p=self.fish.castPoint
  self.scene3d:PrepareCast(self.fish)
  self.fish.bait={x=p.x,y=-.4,z=p.z}
  local q=self.scene3d:FishingLandingPoint();self.fish.landPoint={x=q.x,y=q.y,z=q.z}
 else self.fish.bait=nil;self.fish.landPoint=nil end
 self:AcquireFishingTarget()
end
function App:AcquireFishingTarget()
 local f=self.fish;local best,bestd=nil,100
 if self.scene3d and f.bait then
  best=self.scene3d:FishingTarget(f.bait)
 else
  for i=1,#(f.population or {})do
   local x,y=World.fishPose(i,self.playtime,450,self.h)
   x=x+(f.viewX or 0);y=y+(f.viewY or 0)
   local d=distance(x,y,f.aimX,f.aimY)
   if d<bestd then best,bestd=(f.actors or {})[i],d end
  end
 end
 if not best then return end
 local bait=f.bait or {x=best.x+best.dx*.9,y=-.4,z=best.z+best.dz*.9}
 FishTraffic.Attract(f,best,bait,self.playtime)
end
function App:LandFish()
 self.pendingCatch=State.createCatch(self.fish.species.id)
 self.pendingFishActor=FishTraffic.Take(self.fish)
 if self.pendingFishActor and not self.pendingFishActor.guest then
  local key=self.fish.spotKey;self.fishingTaken[key]=(self.fishingTaken[key]or 0)+1
 end
 self.newDiscovery=State.discover(self.profile,self.pendingCatch.id)
 self.fish.stage="landed";self:CancelGestures();self:OpenModal("catch");self:Save()
 self:Spark(self.fish.aimX,self.fish.aimY,22,true)
end
function App:Local(event) return (event.x-self.x)/self.scale,(event.y-self.y)/self.scale end
function App:IsWalking()return self.mode=="shore"or self.mode=="forest"end
function App:WalkingState()return self.mode=="forest"and self.forest or self.shore end
function App:CreateForest()
 self.forest=ForestWorld.New(Catalog.forest,self.profile.trip and self.profile.trip.kind=="forest"and self.profile.trip or nil)
 self.nearTarget=nil
end
function App:Gather(target)
 if self.mode~="forest"or self.modal or not self.profile.trip or self.profile.trip.kind~="forest"then return end
 local member=false;for _,t in ipairs(self.forest.targets)do if t==target then member=true;break end end
 if not member or not ForestWorld.InReach(self.forest,target)then return end
 local ok,msg,item=State.collect(self.profile,target.id,1)
 if not ok then self:Toast(msg);if self.profile.stamina<1 then self:OpenModal("food")end;return end
 target.collected=true;self.profile.trip.gathered[target.key]=true
 self.forest.pickupUntil=self.playtime+.32
 self:Toast("采集 "..target.species.name.."  +1 · "..string.format("%.2f",item.weight).." kg")
 self.nearTarget=ForestWorld.Nearest(self.forest);self:MarkUI();self:Save()
end
function App:BeginShoreStick(event,which,fixed)
 if self.modal or not event:IsPrimaryAction()then return end
 local j=which=="look"and self.lookJoy or self.joy
 if j.active then
  if not fixed then
   local x,y=self:Local(event)
   self.pointers[event.pointerId]={x=x,y=y,lastX=x,lastY=y,startX=x,startY=y,time=self.time,maxDistance=0,shore="tap"}
  end
  return -- A third finger may tap a creature but cannot steal either stick.
 end
 local x,y=self:Local(event)
 self.pointers[event.pointerId]={x=x,y=y,lastX=x,lastY=y,startX=x,startY=y,time=self.time,maxDistance=0,shore=which}
 self.pointers[event.pointerId].fixed=fixed
 j.active=true;j.pointer=event.pointerId;j.dx=0;j.dy=0
 j.x=fixed and (which=="look"and 367 or 83)or x;j.y=fixed and self.h-174 or y
end
function App:WorldDown(event)
 if not event:IsPrimaryAction() then return end
 local x,y=self:Local(event)
 if self:IsWalking()and not self.modal then
  if y>(self.hudTop or 0)+145 then self:BeginShoreStick(event,x<225 and "move"or"look",false)end
  return
 end
 if self.mode=="map" and not self.modal then
  local l=SeaChart.Layout(self);if y<l.mapTop or y>l.mapBottom then return end
 end
 self.lastDragDistance=0
 local pointer={x=x,y=y,lastX=x,lastY=y,startX=x,startY=y,time=self.time,maxDistance=0}
 self.pointers[event.pointerId]=pointer
 for id,other in pairs(self.pointers) do
  if id~=event.pointerId then pointer.pinched=true;other.pinched=true end
 end
 if self.modal then return end
 if pointer.pinched then
  self.joy.active=false;self.joy.dx=0;self.joy.dy=0
 elseif self.mode=="sailing" or self.mode=="shore" then
  self.joy={active=true,x=x,y=y,dx=0,dy=0,pointer=event.pointerId}
 end
end
function App:PointerMove(event)
 local x,y=self:Local(event)
 if self.aimPointer==event.pointerId and self.castHeld then
  local o=self.castOrigin;self.fish.stage="aim"
  self.fish.guideX=clamp(225+(x-o.x)*1.4,35,415)
  self.fish.guideY=clamp(self.h*.43+(y-o.y)*1.4,140,self.h-180)
  if self.scene3d then self.fish.guideX,self.fish.guideY=self.scene3d:ClampAim(self.fish.guideX,self.fish.guideY)end
  self:UpdateCastAim()
 end
 local p=self.pointers[event.pointerId];if not p then return end
 local dx,dy=x-p.lastX,y-p.lastY;p.x=x;p.y=y;p.lastX=x;p.lastY=y
 p.maxDistance=math.max(p.maxDistance or 0,distance(x,y,p.startX,p.startY))
 if self.modal then
  if self.menuScrollTop and p.startY>=self.menuScrollTop and p.startY<=self.menuScrollBottom then
   if Menus.scroll(self,dy) then self:MarkUI() end
  end
  return
 end
 if self:IsWalking()then
  if p.shore=="tap"then return end
  local j=p.shore=="look"and self.lookJoy or self.joy
  if j.active and j.pointer==event.pointerId then
   local len=math.max(42,distance(x,y,j.x,j.y));j.dx=(x-j.x)/len;j.dy=(y-j.y)/len
  end
  return
 end
 local other
 for id,v in pairs(self.pointers) do if id~=event.pointerId then other=v;break end end
 if other and (self.mode=="home" or self.mode=="sailing" or self.mode=="map") then
  local now=distance(x,y,other.x,other.y);local old=distance(x-dx,y-dy,other.x,other.y)
  if old>15 then self:Zoom(now/old) end
  self.joy.active=false;return
 end
 if self.joy.active and self.joy.pointer==event.pointerId then
  local len=math.max(42,distance(x,y,self.joy.x,self.joy.y))
  self.joy.dx=(x-self.joy.x)/len;self.joy.dy=(y-self.joy.y)/len
 elseif self.mode=="home" or self.mode=="map" then
  if self.scene3d and self.mode=="home" then self.scene3d:Pan(x,y,dx,dy)
  else self.camera.x=self.camera.x-dx/self.camera.zoom;self.camera.y=self.camera.y-dy/self.camera.zoom end
  self:ClampCamera();self:PositionLandmarks()
 elseif self.mode=="fishing" and not self.castHeld and self.reelPointer~=event.pointerId
  and (self.fish.stage=="idle"or self.fish.stage=="casting"or self.fish.stage=="waiting"or self.fish.stage=="hooked")then
  self.fish.viewX,self.fish.viewY=FishingView.Drag(self.fish.viewX,self.fish.viewY,dx,dy)
  self.joy={active=true,x=p.startX,y=p.startY,dx=clamp((x-p.startX)/42,-1,1),dy=clamp((y-p.startY)/42,-1,1)}
 end
end
function App:PointerUp(event,cancelled)
 if self.aimPointer==event.pointerId or self.reelPointer==event.pointerId then self:CastRelease(cancelled) end
 local p=self.pointers[event.pointerId];self.pointers[event.pointerId]=nil
 self.lastDragDistance=p and (p.pinched and 999 or p.maxDistance or distance(p.x,p.y,p.startX,p.startY)) or 0
 if self.joy.pointer==event.pointerId or self.mode=="fishing" then self.joy.active=false;self.joy.dx=0;self.joy.dy=0 end
 if self.lookJoy.pointer==event.pointerId then self.lookJoy.active=false;self.lookJoy.dx=0;self.lookJoy.dy=0 end
 if not p or cancelled then return end
 if self:IsWalking()and not self.modal and not p.fixed and (p.maxDistance or 0)<12
  and self.time-p.time<.6 and self.scene3d then
  local forest=self.mode=="forest"
  local world=forest and ForestWorld or ShoreWorld
  local target=world.Pick(self:WalkingState(),p.x,p.y,function(i)
   if forest then return self.scene3d:ForestTargetBounds(i)end
   return self.scene3d:ShoreTargetBounds(i)
  end)
  if target then if forest then self:Gather(target)else self:Interact(target)end end
  return
 end
 if self.mode=="home" and not self.modal and not p.pinched and (p.maxDistance or 0)<8 then
  if self.scene3d then
   local best,bestd=nil,60
   for _,v in ipairs(self.landmarks or {})do
    local sx,sy=self:ScreenPoint(v.x,v.y);local d=distance(p.x,p.y,sx,sy)
    if d<bestd then best,bestd=v,d end
   end
   if best then self:Landmark(best.id)end
  else
   local wx,wy=World.toWorld(p.x,p.y,450,self.h,self.camera)
   for _,v in ipairs(self.landmarks or {}) do
    if distance(wx,wy,v.x,v.y)<v.radius then self:Landmark(v.id);break end
   end
  end
 end
end
function App:ClampCamera()
 if self.mode=="map"then
  -- Bound the visible right edge, not just the camera centre. Keep the
  -- mountain a coastal fringe at every zoom rather than panning inland.
  local b=Bay.navigation;local right=math.min(b.right,Bay.chartRight-225/self.camera.zoom)
  local half=self.h/2/self.camera.zoom
  self.camera.x=clamp(self.camera.x,math.min(b.left,right),right)
  self.camera.y=clamp(self.camera.y,math.max(b.top,1200-18000+half),math.min(b.bottom,1200+18000-half));return
 end
 local wx,wy=1000,2000
 self.camera.x=clamp(self.camera.x,wx*.15,wx*.85);self.camera.y=clamp(self.camera.y,wy*.18,wy*.84)
end
function App:Zoom(factor)
 if self.modal or self.mode=="fishing" or self:IsWalking() then return end
 local lo=self.mode=="home" and math.min(.40,self.h/2050) or self.mode=="map" and SeaChart.MinZoom(self) or .38
 if self.mode=="map" then
  local offset=SeaChart.Offset(self);local worldY=self.camera.y+offset/self.camera.zoom
  self.camera.zoom=clamp(self.camera.zoom*factor,lo,.65)
  self.camera.y=worldY-offset/self.camera.zoom
  self:ClampCamera()
 else self.camera.zoom=clamp(self.camera.zoom*factor,lo,self.mode=="home" and .95 or 1.0)end
 self:PositionLandmarks()
end
function App:Landmark(id)
 if id=="sea" then self:Depart("sea") elseif id=="shore" then self:Depart("shore")
 elseif id=="forest" then self:Depart("forest")
 elseif id=="coast" then self:Depart("coast");self:StartFishing()
 elseif id=="shop" then self:OpenModal("shop") elseif id=="sell" then self:OpenModal("cargo")
 elseif id=="home" then self:OpenModal("food")
 else self:Toast("开贝小铺尚待开放，先去林间或海边走走吧",3.5) end
end
function App:PositionLandmarks()
 local placed={}
 self.landmarkLabels={}
 for _,p in ipairs(self.landmarks or {}) do
  local b=self.buttons["landmark_"..p.id]
  if b then local x,y=self:ScreenPoint(p.x,p.y)
   local visible=y>135+self.hudTop and y<self.h-135 and x>0 and x<450
   if self.scene3d then
    local anchorX,anchorY=x,y
    local bestX,bestY,bestScore=x,y,math.huge
    for _,d in ipairs({{0,0},{0,-42},{-65,0},{65,0},{-95,36},{95,36},{0,42},{-65,-42},{65,-42},{-100,-42},{100,-42},{0,84}})do
     local cx,cy=clamp(anchorX+d[1],p.w/2+8,442-p.w/2),clamp(anchorY+d[2],145+self.hudTop,self.h-145)
     local score=(cx-anchorX)^2+(cy-anchorY)^2
     for _,r in ipairs(placed)do
      local ox=(p.w+r.w)/2+7-math.abs(cx-r.x);local oy=40-math.abs(cy-r.y)
      if ox>0 and oy>0 then score=score+ox*oy*1000 end
     end
     if score<bestScore then bestX,bestY,bestScore=cx,cy,score end
    end
    x,y=bestX,bestY
    if visible then
     placed[#placed+1]={x=x,y=y,w=p.w}
     self.landmarkLabels[#self.landmarkLabels+1]={x=anchorX,y=anchorY,lx=x,ly=y-13}
    end
   end
   b:SetStyle({left=(x-p.w/2)*self.scale,top=(y-31)*self.scale})
   b:SetVisible(visible)
  end
 end
end
function App:ScreenPoint(x,y)
 if self.mode=="map" then return SeaChart.Project(self,x,y)end
 if self.scene3d then return self.scene3d:ToScreen(x,y) end
 return World.toScreen(x,y,450,self.h,self.camera)
end
function App:AddButton(id,x,y,w,h,props)
 props=props or {};props.position="absolute";props.left=x*self.scale;props.top=y*self.scale
 props.width=w*self.scale;props.height=h*self.scale;props.vw=w;props.id=id
 if self.modal then
  local press,action=props.press,props.action
  props.press=function(e,b)self:WorldDown(e);if press then press(e,b) end end
  if action then props.action=function(b,e)if (self.lastDragDistance or 0)<9 then action(b,e) end end end
 end
 local b=Widgets.Button(props);self.host:AddChild(b);self.buttons[id]=b;return b
end
function App:BuildUI()
 local vw,vh=UI.GetViewportSize();local safe=UI.GetSafeAreaInsets()
 local width=math.min(vw-safe.left-safe.right,540)
 self.scale=width/450;self.h=(vh-safe.top-safe.bottom)/self.scale
 self.x=safe.left+(vw-safe.left-safe.right-width)/2;self.y=safe.top
 -- Minimum top reserve for browsers reporting zero cutout insets. The host
 -- already starts below safe.top, so only add the missing part, once.
 self.hudTop=math.max(0,56-safe.top/self.scale)
 self.buttons={};self.dirty=false;self.menuScrollTop=nil;self.menuScrollBottom=nil
 -- Menu paper covers the entire viewport, including cutouts and wide-screen
 -- gutters. Only its content stays inside the existing safe play surface.
 local root=UI.Panel{width="100%",height="100%",
  backgroundColor=self.modal and {255,253,236,255} or (self.scene3d and {0,0,0,0} or "#102C40"),
  pointerEvents=self.modal and "auto" or "box-none"}
 self.host=Widgets.Surface{position="absolute",left=self.x,top=self.y,width=width,height=self.h*self.scale,
  draw=function(vg,l) nvgSave(vg);nvgTranslate(vg,l.x,l.y);nvgScale(vg,self.scale,self.scale)
   self:Draw(vg,450,self.h);nvgRestore(vg) end,
  onPointerDown=function(e)self:WorldDown(e)end,
  onWheel=function(_,dy)self:Wheel(dy)end}
 -- Wheel is a widget virtual method, not a prop in the base widget.
 self.host.OnWheel=function(_,_,dy)self:Wheel(dy)end
 root:AddChild(self.host);UI.SetRoot(root,true)
 if self.modal=="performance" then PerformanceUI.Build(self)
 elseif self.modal then Menus.build(self)
 else HUD.build(self);PerformanceUI.Shortcut(self) end
 self:PositionLandmarks()
end
function App:Wheel(dy)
 if self.modal and self.menuScrollTop then if Menus.scroll(self,dy*32) then self:MarkUI() end
 else self:Zoom(dy>0 and 1.12 or .89) end
end
function App:Draw(vg,w,h)
 if self.modal then
  if self.modal~="performance" then Menus.draw(self,vg,w,h) end
 else
  local ctx={mode=self.mode,time=self.playtime,camera=self.camera,boat=self.boat,shore=self.shore,
   fish=self.fish,fishSchools=self.fishSchools,reefs=self.reefs,particles=self.particles}
  if self.scene3d then self.scene3d:DrawOverlay(vg,w,h) else World.draw(vg,w,h,ctx) end
  HUD.draw(self,vg,w,h)
 end
 if self.time<self.toastUntil then
  local alpha=math.floor(clamp((self.toastUntil-self.time)*3,0,1)*245)
  local y=self.modal and h-164 or 132+self.hudTop
  A.rect(vg,25,y,400,36,{16,41,59,alpha},18)
  A.text(vg,225,y+18,self.toastText,12,{255,250,221,alpha},NVG_ALIGN_CENTER)
 end
 if not self.modal and self.transition<1 then A.rect(vg,0,0,w,h,{219,255,244,math.floor((1-self.transition)*145)}) end
end
function App:UpdateFishing(dt)
 local f=self.fish
 if self.castHeld then
  f.charge=FishingCast.Charge((f.charge or 0)*FishingCast.chargeSeconds+dt)
  self:UpdateCastAim()
  if self.time-self.castStart>.22 then f.stage="aim" end
 end
 if f.stage=="casting" then
  f.castElapsed=(f.castElapsed or 0)+dt
  f.flickT=math.min(1,f.castElapsed/FishingCast.flickSeconds)
  f.castT=clamp((f.castElapsed-FishingCast.flickSeconds)/(f.castDuration or .9),0,1)
  if f.castT>=1 then f.stage="waiting";f.charge=0;f.waited=0;self:Spark(f.aimX,f.aimY,12,true);self:MarkUI() end
 elseif f.stage=="waiting" then
  f.waited=f.waited+dt;f.noBiteElapsed=(f.noBiteElapsed or 0)+dt;f.scan=(f.scan or 0)+dt
  if not f.target and f.noBiteElapsed>=FishingCast.guaranteeSeconds-FishingCast.arrivalSeconds then
   local species=f.population[math.random(1,math.max(1,#f.population))]or Catalog.fish[math.random(1,5)]
   local actor,added=FishTraffic.Arrive(f,f.bait or {x=0,y=-.4,z=8},species,self.playtime,math.random(1,2147483646))
   if actor and added then
    local key=f.spotKey;local taken=self.fishingTaken[key]or 0
    -- A genuine arrival replenishes a missing local fish. An extra visitor
    -- above the local stock must not deduct a second fish when caught.
    actor.guest=taken==0
    if taken>0 then self.fishingTaken[key]=taken-1;self:Save()end
   end
  elseif not f.target and f.scan>=.45 then f.scan=0;self:AcquireFishingTarget()end
  if f.target and f.waited>=f.waitFor then
   f.stage="hooked";f.power=.5;f.progress=.03;f.danger=0;self:Toast("上钩了！按住收线，松手缓力",2.5)
   self:MarkUI()
  end
 elseif f.stage=="hooked" then
  f.power=clamp(f.power+dt*(self.reelHeld and .42 or -.31)+math.sin(self.playtime*3.1)*dt*.10,.02,.98)
  local safe=f.power>=.32 and f.power<=.72
  f.progress=clamp(f.progress+dt*(safe and (.12+.015*self.profile.rodLevel) or -.025),0,1)
  f.danger=clamp(f.danger+dt*(safe and -1.1 or .72),0,4)
  f.rodSide=math.sin(self.playtime*2.6)*.25
  if f.progress>=1 then self:LandFish()
  elseif f.danger>=4 then f.stage="idle";self:CancelGestures();self:Toast(f.power>.72 and "线断了，松手缓一缓再试" or "线太松，鱼儿游走了");self:MarkUI() end
 end
 FishTraffic.Update(f,self.playtime,dt)
end
function App:UpdateSailing(dt)
 local t=self.profile.trip;if not t then return end
 local joy=self.joy;local length=math.sqrt(joy.dx^2+joy.dy^2)
 local target=length>.08 and 145+25*self.profile.boatLevel or 0
 if t.fuel<=0 or t.hull<=0 then target=0 end
 self.boat.speed=self.boat.speed+(target-self.boat.speed)*math.min(1,dt*5)
 if length>.08 then
  local a=math.atan(joy.dx,-joy.dy);self.boat.heading=self.boat.heading+angleDelta(self.boat.heading,a)*math.min(1,dt*5)
 end
 local oldx,oldy=self.boat.x,self.boat.y
 local bounds=Bay.navigation
 self.boat.x=clamp(oldx+math.sin(self.boat.heading)*self.boat.speed*dt,bounds.left,bounds.right)
 self.boat.y=clamp(oldy-math.cos(self.boat.heading)*self.boat.speed*dt,bounds.top,bounds.bottom)
 local bx,by,coastal=Bay.Resolve(self.boat.x,self.boat.y)
 if coastal then self.boat.x=bx;self.boat.y=by;self.boat.speed=0 end
 if self.boat.speed>5 then t.fuel=math.max(0,t.fuel-dt*.33) end
 self.hitCooldown=math.max(0,(self.hitCooldown or 0)-dt)
 for _,r in ipairs(self.reefs) do
  local d=distance(self.boat.x,self.boat.y,r.x,r.y);local radius=r.radius+40
  if d<radius then
   local nx,ny=0,-1
   if d>.001 then nx,ny=(self.boat.x-r.x)/d,(self.boat.y-r.y)/d end
   self.boat.x=r.x+nx*(radius+1);self.boat.y=r.y+ny*(radius+1);self.boat.speed=0
   if self.hitCooldown==0 then t.hull=math.max(0,t.hull-12);self.hitCooldown=2;self:Toast("碰到礁石！船耐久 -12");self:Spark(self.boat.x,self.boat.y,16,false) end
  end
 end
 for _,shark in ipairs(self.sharks)do
  SharkPatrol.Step(shark,dt)
  if distance(shark.x,shark.y,self.boat.x,self.boat.y)<100 and shark.cooldown==0 then
   t.hull=math.max(0,t.hull-8);shark.cooldown=9;self:Toast("鲨鱼撞击！船耐久 -8，快离开这里");self:Spark(self.boat.x,self.boat.y,18,false)
  end
 end
 self.camera.x=self.boat.x;self.camera.y=self.boat.y
 if (t.fuel<=0 or t.hull<=0) and not self.rescueNotice then
  self.rescueNotice=true;self:OpenModal("return");self:Toast("本次无法继续航行，可带着现有收获返航",4)
 end
end
function App:UpdateShore(dt)
 local s=self:WalkingState();local world=self.mode=="forest"and ForestWorld or ShoreWorld
 local move=self.joy
 if not move.active and input and input.GetKeyDown and KEY_W then
  move={dx=(input:GetKeyDown(KEY_D)and 1 or 0)-(input:GetKeyDown(KEY_A)and 1 or 0),
   dy=(input:GetKeyDown(KEY_S)and 1 or 0)-(input:GetKeyDown(KEY_W)and 1 or 0)}
 end
 world.Update(s,move,self.lookJoy,dt,false)
 self.camera.x=s.x;self.camera.y=s.y
 local nearest=world.Nearest(s)
 if nearest~=self.nearTarget then self.nearTarget=nearest;self:MarkUI() end
 HUD.positionContext(self)
end
function App:Update(dt)
 dt=clamp(dt,0,.05);self.time=self.time+dt;self.transition=math.min(1,self.transition+dt*3)
 local w,h=UI.GetViewportSize();local safe=UI.GetSafeAreaInsets()
 local scale=math.min(w-safe.left-safe.right,540)/450
 local x=safe.left+(w-safe.left-safe.right-math.min(w-safe.left-safe.right,540))/2
 if math.abs(scale-self.scale)>.001 or math.abs((h-safe.top-safe.bottom)/scale-self.h)>1
  or math.abs((self.y or 0)-safe.top)>.5 or math.abs(self.x-x)>.5 then self:CancelGestures();self:MarkUI() end
 if not self.modal then
  self.playtime=self.playtime+dt
  if self.profile.trip then self.profile.trip.elapsed=self.profile.trip.elapsed+dt end
  if self.mode=="fishing" then self:UpdateFishing(dt)
  elseif self.mode=="sailing" then self:UpdateSailing(dt)
  elseif self:IsWalking() then self:UpdateShore(dt) end
 end
 for i=#self.particles,1,-1 do
  self.particles[i].age=self.time-self.particles[i].born
  if self.particles[i].age>self.particles[i].life then table.remove(self.particles,i) end
 end
 self.saveClock=self.saveClock+dt
 if self.saveClock>=12 then self.saveClock=0;self:Save() end
 if self.dirty then self:BuildUI() end
 if self.scene3d then self.scene3d:Update(dt) end
end
function App:Key(key)
 if key==KEY_ESCAPE then
  if self.modal=="catch" then self:ReleaseCatch()
  elseif self.modal then self:CloseModal()
  elseif self.mode=="fishing" then self:ExitFishing()
  elseif self.mode=="map" then self:SetMode("sailing")
  elseif self.mode~="home" then self:OpenModal("return") end
 elseif key==KEY_SPACE and self.mode=="fishing" and not self.modal then
  self:Toast("使用右下抛竿按钮：点按或按住拖动")
 end
end
return App
