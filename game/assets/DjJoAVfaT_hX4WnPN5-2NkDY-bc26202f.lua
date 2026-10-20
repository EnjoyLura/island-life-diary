-- Runtime 3D environments based on templates/scaffold-3d-scene.lua.
-- A retained Scene/Camera/Viewport lives behind the existing transparent UI.
-- Island: layered cel art in world space. Sea/fishing: limited real-time 3D.
-- No character meshes, hands or body parts are used.
local Mesh=require("Game.Mesh")
local Scenery=require("Game.Scenery")
local LayeredIsland=require("Game.LayeredIsland")
local FishArt=require("Game.FishArt")
local Catalog=require("Game.Catalog")
local RenderSettings=require("Game.RenderSettings")
local Ocean=require("Game.OceanMotion")
local ReefArt=require("Game.ReefArt")
local CoastalShelf=require("Game.CoastalShelf")
local IslandShape=require("Game.IslandShape")
local WakeTrail=require("Game.WakeTrail")
local Bay=require("Game.Bay")
local WaterRenderer=require("Game.OceanRenderer")
local LegacyOcean=require("Game.OceanMotionLegacy")
local SceneTarget=require("Game.SceneTarget")
---@class CrescentScene3D
---@field islandGroundMat Material
---@field islandWindMat Material
---@field homeDetails Node
---@field homeMedium Node
---@field moored Node
---@field mooredAnchor {x:number,z:number}
---@field skyNode Node
---@field seabedNode Node
local S={};S.__index=S
local sin,cos,pi=math.sin,math.cos,math.pi
local C={sand={.94,.80,.48},grass={.38,.65,.24},leaf={.23,.56,.24},leafLight={.44,.72,.29},
 wood={.51,.29,.14},plank={.77,.51,.27},cream={1,.91,.68},roof={.79,.29,.16},
 rock={.43,.53,.53},blue={.15,.47,.60},dark={.12,.23,.27},white={.91,.97,.87},gold={.95,.67,.22},steel={.67,.76,.76}}
local function clamp(n,a,b)return math.max(a,math.min(b,n))end
local function vec(x,y,z)return Vector3(x,y,z)end
local function surface(path)
 local m=Material:new()
 assert(m:SetSurfaceShader(path),"Crescent surface failed: "..path)
 return m
end
function S.new(app)
 local self=setmetatable({},S)
 local trace=debug and debug.traceback or tostring
 local ok,err=xpcall(function()self:Init(app)end,trace)
 if ok then return self end
 self:Stop()
 if RenderSettings.legacy then error(err,0)end
 -- Release the incomplete scene before one attempt with the retained renderer.
 -- A second failure is fatal and must reach the host's visible startup error.
 for key in pairs(self)do self[key]=nil end
 collectgarbage("collect")
 RenderSettings.legacy=true
 print("[CrescentStartup] ocean-fallback: "..tostring(err))
 self=setmetatable({},S)
 local recovered,fallbackError=xpcall(function()self:Init(app)end,trace)
 if not recovered then
  self:Stop()
  error("New ocean initialization: "..tostring(err).."\nCompatibility initialization: "..tostring(fallbackError),0)
 end
 return self
end
function S:Init(app)
 self.app=app;self.mode="";self.trees={};self.birds={};self.fishNodes={};self.schoolNodes={};self.targets={};self.fishTails={}
 self.scene=Scene();self.scene:CreateComponent("Octree")
 self.solid=surface("Shaders/BLGL/CrescentSolid.shader")
 self.motion=RenderSettings.legacy and LegacyOcean or Ocean
 self.waterMat=surface(RenderSettings.legacy and "Shaders/BLGL/CrescentLegacyWater.shader" or "Shaders/BLGL/CrescentWater.shader")
 local waterData=cache:GetResource("Texture2D","Textures/Crescent/OceanData.png")
 assert(waterData,"Crescent water data texture is missing")
 local sandArt=cache:GetResource("Texture2D","Textures/Crescent/SeabedSand.jpg")
 assert(sandArt,"Crescent bed texture is missing")
 if RenderSettings.legacy then
  self.waterMat:SetSurfaceTexture("ocean_data",waterData)
  self.waterMat:SetSurfaceTexture("wave_art",assert(cache:GetResource("Texture2D","Textures/Crescent/OceanPaint.jpg")))
 else
  local waveData=assert(cache:GetResource("Texture2D","Textures/Crescent/WaterWaves.png"))
  self.waterMat:SetSurfaceTexture("wave_data",waveData)
  local api=graphics:GetApiName():lower()
  self.waterMat:SetShaderParameter("screen_y_sign",Variant(api:find("opengl",1,true) and 1 or -1))
  self.deepWaterMat=surface("Shaders/BLGL/CrescentDeepWater.shader")
  self.deepWaterMat:SetSurfaceTexture("wave_data",waveData);Ocean.Bind(self.deepWaterMat)
  self.waterHomeField=assert(cache:GetResource("Texture2D","Textures/Crescent/WaterFieldHome.png"))
  self.waterBayField=assert(cache:GetResource("Texture2D","Textures/Crescent/WaterFieldBay.png"))
  self.schoolMat=surface("Shaders/BLGL/CrescentSchool.shader")
  self.schoolMat:SetSurfaceTexture("water_field",self.waterBayField);Ocean.Bind(self.schoolMat)
  self.schoolMat:SetShaderParameter("wave_strength",Variant(Ocean.Strength("sailing")))
  self.schoolMat.renderOrder=132
 end
 self.motion.Bind(self.waterMat)
 self.wakeMat=surface(RenderSettings.legacy and "Shaders/BLGL/CrescentLegacyWake.shader" or "Shaders/BLGL/CrescentWake.shader")
 self.motion.Bind(self.wakeMat)
 if not RenderSettings.legacy then self.wakeMat:SetSurfaceTexture("water_field",self.waterBayField)end
 self.wakeMat.renderOrder=135
 self.wakeMat:SetShaderParameter("wave_strength",Variant(self.motion.Strength("sailing")))
 self.bedMat=surface("Shaders/BLGL/CrescentSeabed.shader")
 self.bedMat:SetSurfaceTexture("sand_art",sandArt)
 self.bedMat:SetSurfaceTexture("ocean_data",waterData)
 self.apronMat=surface("Shaders/BLGL/CrescentCoastalShelf.shader")
 local shelfArt=cache:GetResource("Texture2D","Textures/CelWorld/shore-shelf.png")
 assert(shelfArt,"Crescent extended island shelf texture is missing")
 self.apronMat:SetSurfaceTexture("shelf_art",shelfArt)
 self.apronMat:SetSurfaceTexture("sand_art",sandArt)
 self.apronMat:SetSurfaceTexture("ocean_data",waterData)
 self.rockMat=surface("Shaders/BLGL/CrescentRock.shader")
 local stone=cache:GetResource("Texture2D","Textures/Crescent/ReefStone.png")
 local reefs=cache:GetResource("Texture2D","Textures/Crescent/ReefData.png")
 assert(stone and reefs,"Crescent reef textures are missing")
 self.rockMat:SetSurfaceTexture("stone_map",stone)
 self.rockMat:SetSurfaceTexture("ocean_data",waterData)
 if RenderSettings.legacy then self.waterMat:SetSurfaceTexture("reef_data",reefs);Bay.Bind(self.waterMat)end
 self.skyMat=surface("Shaders/BLGL/CrescentSky.shader")
 self.skyMat:SetSurfaceTexture("ocean_data",waterData)
 self.fishMat=surface("Shaders/BLGL/CrescentFish.shader")
 self.metal=surface("Shaders/BLGL/CrescentSolid.shader")
 self.metal:SetShaderParameter("surface_roughness",Variant(.28));self.metal:SetShaderParameter("surface_metallic",Variant(.55))
 local env=self.scene:CreateChild("Environment"):CreateComponent("Zone")
 env.boundingBox=BoundingBox(vec(-500,-100,-500),vec(500,300,500))
 env.ambientSource=AMBIENT_COLOR;env.ambientColor=Color(.38,.46,.49)
 env.fogColor=Color(.15,.56,.73);env.depthFogStart=180;env.depthFogEnd=340
 env.depthFogEnable=false;env.heightFogEnable=false
 local light=self.scene:CreateChild("Sun");light.direction=vec(.50,-.84,.20)
 local sun=light:CreateComponent("Light");sun.lightType=LIGHT_DIRECTIONAL;sun.brightness=1.15
 sun.color=Color(1,.94,.82);sun.castShadows=true;sun.shadowIntensity=.32
 sun.shadowBias=BiasParameters(.0003,.6);sun.shadowCascade=CascadeParameters(18,65,180,300,.85)
 self.cameraNode=self.scene:CreateChild("Camera");self.camera=self.cameraNode:CreateComponent("Camera")
 self.camera.nearClip=.1;self.camera.farClip=1600;self.camera.orthographic=true
 self.viewport=Viewport:new(self.scene,self.camera)
 self.target=SceneTarget.new(self.viewport,RenderSettings.sceneScale)
 -- One shadowed directional light; no full-screen post effects on mobile.
 renderer.hdrRendering=false
 renderer.drawShadows=true;renderer.shadowMapSize=1024
 self.home=self.scene:CreateChild("Island");self.sea=self.scene:CreateChild("SailingSea")
 self.fishing=self.scene:CreateChild("FishingBay");self.shore=self.scene:CreateChild("TidalBeach")
 self:CreateOcean();self:CreateIsland();self:CreateSea();self:CreateFishing();self:CreateShore()
 self:CreateBirds();self:Update(0)
 print("[Crescent3D] retained real-time scenes ready")
end
function S:NewMesh(parent,name,castShadow)
 local m=Mesh.new(parent,name,self.solid);m.geometry.castShadows=castShadow~=false;return m
end
function S:CreateOcean()
 local sky=Mesh.new(self.scene,"ProceduralSkyDome",self.skyMat)
 sky:ellipsoid(0,0,0,960,960,960,C.white,40,16);sky:finish();self.skyNode=sky.node
 local bed=Mesh.new(self.scene,"AnimatedCausticSeabed",self.bedMat)
 bed:quad(vec(-720,-28,-720),vec(-720,-28,720),vec(720,-28,720),vec(720,-28,-720),C.white);bed:finish();self.seabedNode=bed.node
 if RenderSettings.legacy then
  local water=Mesh.new(self.scene,"MovingWaterSurface",self.waterMat)
  local axis=LegacyOcean.GridAxis()
  for i=1,#axis-1 do for j=1,#axis-1 do local x,z,xx,zz=axis[i],axis[j],axis[i+1],axis[j+1]
   water:quad(vec(x,0,z),vec(x,0,zz),vec(xx,0,zz),vec(xx,0,z),C.white)
  end end
  water:finish();self.legacyWater=water.node;self.legacyWater.enabled=RenderSettings.waterVisible
 else
  self.waterRegions={}
  for _,mode in ipairs({"home","sailing","fishing"})do
   self.waterRegions[mode]=WaterRenderer.Build(self.scene,mode,self.waterMat,self.deepWaterMat)
   self.waterRegions[mode].root:SetEnabledRecursive(false)
  end
 end
end
function S:CreateIsland()
 LayeredIsland.Build(self)
 CoastalShelf.Build(self.home,self.apronMat)
 local strand=CoastalShelf.Rocks()
 ReefArt.Build(self.home,"StrandRockGroups",self.rockMat,strand)
 ReefArt.Build(self.home,"SubmergedCoastalRocks",self.rockMat,ReefArt.HomeLayout())
end
function S:House(parent,x,y,z,size,name)
 return Scenery.house(self,parent,x,y,z,size,name)
end
function S:Tree(parent,x,y,z,seed,palm)
 return Scenery.tree(self,parent,x,y,z,seed,palm)
end
function S:LightHouse(x,y,z)
 local m=self:NewMesh(self.home,"Lighthouse")
 m:cone(x,y,z,1.6,1.0,6.5,C.cream,12);m:cone(x,y+2,z,1.42,1.25,1.1,C.roof,12)
 m:cone(x,y+6.5,z,1.3,1.3,.3,C.dark,12);m:cone(x,y+6.8,z,.9,.9,1.1,C.blue,12)
 m:cone(x,y+7.9,z,1.5,0,1,C.roof,12);m:finish()
end
function S:Boat(parent,name)
 return Scenery.boat(self,parent,name)
end
function S:Fish(parent,name,tint,shadow,index)
 return Scenery.fish(self,parent,name,tint,shadow,index)
end
function S:CreateSea()
 Bay.Build(self)
 self.boat=self:Boat(self.sea,"PlayerBoat")
 self.boat.scale=vec(1.6,1.6,1.6)
 ReefArt.BuildBanks(self.sea,self.bedMat,self.app.reefs)
 ReefArt.Build(self.sea,"TexturedReefClusters",self.rockMat,ReefArt.Layout(self.app.reefs))
 for i,school in ipairs(self.app.fishSchools)do for j=1,school.count do
  local f=self:Fish(self.sea,"SchoolFish",nil,true,i+j);f.scale=vec(.82,.7,.82)
  self.schoolNodes[#self.schoolNodes+1]={node=f,school=school,phase=j*2.399+i}
 end end
 self.shark=Scenery.shark(self,self.sea);self.shark.scale=vec(1.25,1.25,1.25)
 self.wakeTrail=WakeTrail.New()
 self.wakeMesh=Mesh.new(self.sea,"CurvedBoatWake",self.wakeMat)
 self.wakeMesh.geometry.castShadows=false;self.wakeMesh.geometry:SetDynamic(true)
 WakeTrail.Build(self.wakeMesh,{{x=0,z=-2},{x=0,z=-3}},0)
 self.wake=self.wakeMesh.node
end
function S:CreateFishing()
 local floor=self:NewMesh(self.fishing,"BayRocksAndCoral",false)
 for i=1,16 do local a=i*2.399;local r=5+i%5
  floor:rock(cos(a)*r,-5.8-i%3*.45,sin(a)*r,.45+(i%3)*.25,.4+(i%4)*.13,.65,{.25,.44,.49},i)
  if i%2==0 then Scenery.coral(self,self.fishing,cos(a)*r,-5.8-i%3*.45,sin(a)*r,i)end
 end
 floor:finish()
 self.fishSpecies={}
 for i=1,9 do
  self.fishNodes[i]=FishArt.Build(self,self.fishing,"CatchableFish"..i,Catalog.fish[(i-1)%5+1],i)
  self.fishSpecies[i]=Catalog.fish[(i-1)%5+1].id
 end
 -- The fishing position is fixed but the view opens toward an ocean horizon.
 -- Nearby reefs stay below water; no wall of primitive green hills in front.
 self.fishingBoat=self:Boat(self.fishing,"FishingBoatEdge")
 self.fishingBoat.scale=vec(1.9,1,1.9);self.fishingBoat.position=vec(0,.1,-10.3)
 self.rodRoot=self.fishing:CreateChild("FloatingRod")
 self.rodParts={}
 for i=1,9 do
  local part=Mesh.new(self.rodRoot,"RodSegment"..i,self.metal)
  local r=.036-(i-1)*.003
  part:tube(vec(0,0,0),vec(0,0,1),r,r*.91,i<3 and {.14,.20,.22} or {.70,.27,.11},10)
  part:torus(0,0,.08,r+.003,.008,C.gold,Vector3.FORWARD,12)
  part:torus(0,.055,.88,.046,.009,C.dark,Vector3.FORWARD,12)
  part:tube(vec(0,0,.88),vec(0,.043,.88),.012,.012,C.gold,6)
  if i==1 then for j=0,9 do part:torus(0,0,j*.08,r+.006,.012,{.24,.20,.15},Vector3.FORWARD,12)end end
  part:finish();part.node.scale=vec(1,1,.76);self.rodParts[i]=part.node
 end
 local reel=Mesh.new(self.rodRoot,"SpinningReel",self.metal)
 reel:tube(vec(0,-.02,.35),vec(0,-.23,.35),.04,.04,C.dark,8)
 reel:ellipsoid(0,-.28,.35,.15,.17,.19,C.dark,12,7)
 reel:tube(vec(0,-.28,.37),vec(0,-.28,.65),.13,.13,C.gold,14)
 for j=0,4 do reel:torus(0,-.28,.43+j*.035,.125,.012,C.cream,Vector3.FORWARD,16)end
 reel:torus(0,-.28,.58,.18,.015,C.white,Vector3.FORWARD,20)
 reel:tube(vec(0,-.28,.34),vec(-.24,-.28,.34),.024,.024,C.steel,8)
 reel:tube(vec(-.24,-.28,.34),vec(-.24,-.42,.48),.024,.024,C.steel,8)
 reel:ellipsoid(-.24,-.42,.48,.065,.05,.10,C.dark,10,5);reel:finish()
 self.bobber=self:NewMesh(self.fishing,"Bobber")
 self.bobber:cone(0,0,0,.07,.07,.32,C.cream,8);self.bobber:cone(0,.12,0,.09,.04,.16,C.roof,8);self.bobber:finish()
 self.line=Mesh.new(self.fishing,"FishingLine",self.solid);self.line.geometry:SetDynamic(true)
 self.line:beam(vec(0,-10,0),vec(0,-10,.1),.009,C.cream);self.line:finish();self.line.node.enabled=false
 local ripple=self:NewMesh(self.fishing,"FloatRipples")
 for i=0,2 do ripple:torus(0,i*.003,0,.18+i*.22,.009,{.63,.89,.85},nil,32)end
 ripple:finish();ripple.geometry.castShadows=false;self.ripple=ripple.node
end
function S:CreateShore()
 local sand=self:NewMesh(self.shore,"TidalSand")
 sand:quad(vec(-38,.08,-45),vec(-38,.08,45),vec(38,.08,45),vec(38,.08,-45),C.sand)
 for i=1,28 do local x=sin(i*7)*27;local z=cos(i*3)*30
  if math.abs(x)>13 then sand:rock(x,.05,z,1+i%3,1+i%2,1.5,C.rock,i)end
 end
 sand:finish()
 for i,target in ipairs(self.app.shore.targets)do
  local m=self:NewMesh(self.shore,"ShoreTarget"..i,false)
  if target.kind=="hole" then m:cone(0,.08,0,.35,.25,.02,C.dark,12)
  elseif target.kind=="mound" then m:rock(0,.08,0,.5,.26,.45,{.70,.55,.32},i)
  else
   m:rock(0,.1,0,.3,.19,.2,target.kind=="crab" and C.roof or C.cream,i)
   if target.kind=="crab" then for k=-1,1,2 do
    m:beam(vec(k*.2,.18,0),vec(k*.5,.1,.2),.035,C.roof)
    m:beam(vec(k*.2,.18,0),vec(k*.55,.1,-.2),.035,C.roof)
   end end
  end
  m:finish();self.targets[i]=m.node
 end
end
function S:CreateBirds()
 for i=1,6 do
  local m=self:NewMesh(self.scene,"SeaBird"..i,false)
  m:tri(vec(0,0,0),vec(-.75,.12,-.12),vec(-.3,0,.15),C.white)
  m:tri(vec(0,0,0),vec(.3,0,.15),vec(.75,.12,-.12),C.white)
  m:finish();self.birds[i]=m.node
 end
end
function S:HomePoint(x,y)
 local xx,zz=IslandShape.Map((x-500)*.04,-(y-1000)*.026)
 return vec(xx,.13,zz)
end
function S:Point(x,y)
 if self.app.mode=="home" then return self:HomePoint(x,y)end
 if self.app.mode=="shore" then return vec((x-900)*.04,.2,-(y-1050)*.04)end
 return vec((x-1000)*.04,.1,-(y-1200)*.04)
end
function S:Project(p)
 local uv=self.camera:WorldToScreenPoint(p)
 return uv.x*450,uv.y*self.app.h
end
function S:ToScreen(x,y) return self:Project(self:Point(x,y))end
---@return Vector3
function S:RayPoint(x,y,height)
 local r=self.camera:GetScreenRay(x/450,y/self.app.h)
 local k=((height or 0)-r.origin.y)/math.min(-.001,r.direction.y)
 return r.origin+r.direction*math.max(0,k)
end
function S:FishPoint(i,t)
 local a=t*(.15+i%3*.027)+i*1.73
 return vec(cos(a)*(3.6+i%3*.65),-1.1-i%3*.20+sin(t*.65+i)*.09,3.1+sin(a)*(2.8+i%2*.8))
end
function S:Pan(x,y,dx,dy)
 local d=self:RayPoint(x-dx,y-dy,.13)-self:RayPoint(x,y,.13)
 local c=self.app.camera;local focus=self:HomePoint(c.x,c.y)+d
 local xx,zz=IslandShape.Unmap(focus.x,focus.z)
 c.x=500+xx/.04;c.y=1000-zz/.026
end
function S:FishPose(i,t)
 local p=self:FishPoint(i,t);local x,y=self:Project(p)
 return x,y,0,40,(i-1)%6+1
end
function S:ClampAim(x,y)
 local _,waterY=self:Project(vec(-(self.app.fish.viewX or 0)*.5,0,120))
 return clamp(x,35,415),clamp(y,math.max(140,waterY+10),self.app.h-230)
end
function S:SetCamera()
 local app=self.app;local mode=app.mode
 local c=app.camera;local f=app.fish or {};local old=self.cameraState
 local gw,gh=graphics:GetWidth(),graphics:GetHeight()
 local uiw=select(1,require("urhox-libs/UI").GetViewportSize())
 local vx,vy=f.viewX or 0,f.viewY or 0
 if old and old.mode==mode and old.cx==c.x and old.cy==c.y and old.zoom==c.zoom
  and old.vx==vx and old.vy==vy and old.h==app.h and old.scale==app.scale
  and old.x==app.x and old.y==app.y and old.gw==gw and old.gh==gh and old.uiw==uiw then return false end
 self.cameraState={mode=mode,cx=c.x,cy=c.y,zoom=c.zoom,vx=vx,vy=vy,h=app.h,scale=app.scale,
  x=app.x,y=app.y,gw=gw,gh=gh,uiw=uiw}
 local focus=self:Point(app.camera.x,app.camera.y)
 if mode=="fishing" then
  self.camera.orthographic=false;self.camera.fov=57
  local f=app.fish
  self.cameraNode.position=vec(0,3.0,-9)
  self.cameraNode:LookAt(vec(-(f.viewX or 0)*.09,-.6+(f.viewY or 0)*.025,14))
 elseif mode=="home" then
  self.camera.orthographic=true;self.camera.orthoSize=app.h*.061/app.camera.zoom
  self.cameraNode.position=focus+vec(0,88,-70)
  self.cameraNode:LookAt(focus)
 elseif mode=="shore" then
  self.camera.orthographic=true;self.camera.orthoSize=app.h*.04/app.camera.zoom
  self.cameraNode.position=focus+vec(0,24,-16);self.cameraNode:LookAt(focus)
 elseif mode=="map" then
  self.camera.orthographic=true;self.camera.orthoSize=app.h*.04/app.camera.zoom
  self.cameraNode.position=focus+vec(0,100,0);self.cameraNode.rotation=Quaternion(90,0,0)
 else
  self.camera.orthographic=true;self.camera.orthoSize=app.h*.04/app.camera.zoom
  self.cameraNode.position=focus+vec(0,46,-27);self.cameraNode:LookAt(focus)
 end
 if self.waterRegions then
  -- Ortho rays are parallel: using camera-position per fragment makes a false
  -- radial reflection patch when panning/zooming the harbour and chart.
  local direction=(self.cameraNode.position-focus):Normalized()
  local view=Variant(Vector4(direction.x,direction.y,direction.z,self.camera.orthographic and 1 or 0))
  self.waterMat:SetShaderParameter("water_view",view)
  self.deepWaterMat:SetShaderParameter("water_view",view)
 end
 -- UI uses a centred portrait play surface even on a landscape desktop.
 local scale=gw/uiw
 local left,top=math.floor(app.x*scale),math.floor(app.y*scale)
 local right,bottom=math.floor((app.x+450*app.scale)*scale),math.floor((app.y+app.h*app.scale)*scale)
 self.camera.autoAspectRatio=false;self.camera.aspectRatio=(right-left)/math.max(1,bottom-top)
 if self.target then self.target:Resize(left,top,right,bottom)
 else self.viewport.rect=IntRect(left,top,right,bottom)end
 return true
end
function S:AnimateVisible(t,mode)
 local active=mode=="home" and self.home or mode=="fishing" and self.fishing or (mode=="sailing" or mode=="map") and self.sea or self.shore
 for _,tree in ipairs(self.trees)do
  if tree.owner==active then tree.node.rotation=Quaternion(sin(t*.8+tree.seed)*2,0,cos(t*.6+tree.seed)*2)end
 end
 local count=#(self.app.fish.population or {})
 for _,tail in ipairs(self.fishTails)do
  if tail.owner==active and (tail.owner~=self.fishing or tail.index<=count)then
   tail.node.rotation=Quaternion(0,sin(t*7.5+tail.seed)*23,0)
  end
 end
end
function S:Update(dt)
 local a=self.app;local t=a.playtime;local mode=a.mode
 local motion=self.motion or (RenderSettings.legacy and LegacyOcean or Ocean)
 -- Secondary pages are opaque; retain resources but skip the hidden 3D view.
 if a.modal then
  if not self.worldSuspended then
   if self.target then self.target:SetActive(false)else renderer:SetViewport(0,nil)end
   self.worldSuspended=true
  end
  return
 elseif self.worldSuspended then
  if self.target then self.target:SetActive(true)else renderer:SetViewport(0,self.viewport)end
  self.worldSuspended=false
 end
 local homeVisible=mode=="home" or mode=="sailing" or mode=="map"
 local modeChanged=self.mode~=mode
 if modeChanged then
  -- Orthographic modes are completely covered by water/land; drawing a
  -- three-sample sky dome behind them only adds hidden fragment work.
  self.skyNode.enabled=RenderSettings.legacy or mode=="fishing"
  -- Node.enabled only affects its own components. Scene roots need descendants too.
  Bay.PlaceHome(self,mode=="home")
  self.home:SetEnabledRecursive(homeVisible)
  self.sea:SetEnabledRecursive(mode=="sailing" or mode=="map")
  if self.boat then self.boat:SetEnabledRecursive(mode=="sailing")end
  if self.shark then self.shark:SetEnabledRecursive(mode=="sailing")end
  for _,fish in ipairs(self.schoolNodes)do fish.node:SetEnabledRecursive(mode=="sailing")end
  self.fishing:SetEnabledRecursive(mode=="fishing")
  self.shore:SetEnabledRecursive(mode=="shore")
  self.activeFishCount=nil
  local radius=mode=="home" and 23.5 or mode=="fishing" and 3 or -35
  self.waterMat:SetShaderParameter("island_radius",Variant(radius))
  self.waterMat:SetShaderParameter("wave_strength",Variant(motion.Strength(mode)))
  self.waterMat:SetShaderParameter("reef_mode",Variant((mode=="sailing" or mode=="map") and 1 or 0))
  self.waterMat:SetShaderParameter("home_mode",Variant(mode=="home" and 1 or 0))
  self.waterMat:SetShaderParameter("fishing_mode",Variant(mode=="fishing" and 1 or 0))
  self.waterMat:SetShaderParameter("chart_mode",Variant(mode=="map" and 1 or 0))
  if self.waterRegions then
   local region=mode=="home" and "home" or mode=="fishing" and "fishing" or mode=="shore" and "fishing" or "sailing"
   for key,value in pairs(self.waterRegions)do value.root:SetEnabledRecursive(key==region and RenderSettings.waterVisible)end
   self.waterMat:SetSurfaceTexture("water_field",mode=="home" and self.waterHomeField or self.waterBayField)
   self.waterMat:SetShaderParameter("field_span",Variant(mode=="home" and 160 or 256))
   self.waterMat:SetShaderParameter("fishing_mode",Variant((mode=="fishing" or mode=="shore") and 1 or 0))
   self.deepWaterMat:SetShaderParameter("wave_strength",Variant(Ocean.Strength(mode)))
   self.deepWaterMat:SetShaderParameter("home_mode",Variant(mode=="home" and 1 or 0))
   self.deepWaterMat:SetShaderParameter("chart_mode",Variant(mode=="map" and 1 or 0))
  end
 end
 local cameraChanged=self:SetCamera()
 if self.target then self.target:Queue()end
 if cameraChanged then self.skyNode.position=self.cameraNode.position end
 local lod=a.camera.zoom<.46 and 0 or a.camera.zoom<.7 and 1 or 2
 if modeChanged or self.lod~=lod then
  self.homeDetails.enabled=homeVisible and lod==2
  self.homeMedium.enabled=homeVisible and lod>=1;self.lod=lod
 end
 if mode=="home" and cameraChanged then a:PositionLandmarks()end
 self.mode=mode
 -- Modal panels already pause playtime. Preserve their frozen frame without
 -- re-uploading uniforms, rebuilding wakes or writing identical transforms.
 if self.animationTime==t and not modeChanged then return end
 self.animationTime=t
 local oceanTime=Variant(t)
 self.waterMat:SetShaderParameter("ocean_time",oceanTime)
 if self.deepWaterMat then self.deepWaterMat:SetShaderParameter("ocean_time",oceanTime)end
 if self.schoolMat and mode=="sailing" then self.schoolMat:SetShaderParameter("ocean_time",oceanTime)end
 self.bedMat:SetShaderParameter("ocean_time",oceanTime)
 self.skyMat:SetShaderParameter("ocean_time",oceanTime)
 if homeVisible then
  self.apronMat:SetShaderParameter("ocean_time",oceanTime)
  self.rockMat:SetShaderParameter("ocean_time",oceanTime)
  self.islandGroundMat:SetShaderParameter("ocean_time",oceanTime)
  self.islandWindMat:SetShaderParameter("wind_time",oceanTime)
 end
 self:AnimateVisible(t,mode)
 for i,b in ipairs(self.birds)do
  if modeChanged then b.enabled=mode~="fishing" and mode~="shore"end
  if b.enabled then
   b.position=vec(sin(t*.10+i)*30,12+sin(t*.3+i)*2,cos(t*.10+i)*23)
   b.rotation=Quaternion(0,-t*5.7-i*57, sin(t*4+i)*15)
  end
 end
 if homeVisible then
  local anchor=self.mooredAnchor
  local x,z,k=0,0,1;if mode~="home" then x,z,k=Bay.HomeFrame()end
  local h,pitch,roll=motion.FloatPose(x+anchor.x*k,z+anchor.z*k,t,mode,15*pi/180,3*k,1.3*k)
  self.moored.position=vec(anchor.x,.28+h/k,anchor.z)
  self.moored.rotation=Quaternion(pitch,15+sin(t*.65)*2,roll)
 end
 if mode=="sailing" or mode=="map" then
  local boat=a.boat;local p=self:Point(boat.x,boat.y)
  local height,pitch,roll=motion.FloatPose(p.x,p.z,t,mode,boat.heading,4.6,1.7)
  self.boat.position=p+vec(0,.18+height,0)
  self.boat.rotation=Quaternion(pitch,boat.heading*180/pi,roll)
  self.wake.enabled=mode=="sailing" and boat.speed>8
  local points,opacity=WakeTrail.Sample(self.wakeTrail,p.x,p.z,boat.heading,boat.speed)
  if self.wake.enabled then
   self.wakeMat:SetShaderParameter("ocean_time",oceanTime)
   WakeTrail.Build(self.wakeMesh,points,opacity)
  end
  if mode=="sailing" then for _,f in ipairs(self.schoolNodes)do
   local phase=t*.26+f.phase;local s=f.school
   f.node.position=self:Point(s.x+cos(phase)*70,s.y+sin(phase)*48)+vec(0,-.02,0)
   f.node.rotation=Quaternion(0,math.atan(-sin(phase),-cos(phase)*.69)*180/pi,sin(t*4+f.phase)*4)
  end end
  local sharkPoint=self:Point(a.shark.x,a.shark.y)
  self.shark.position=sharkPoint+vec(0,motion.At(sharkPoint.x,sharkPoint.z,t,mode)-.2,0)
  self.shark.rotation=Quaternion(0,a.shark.phase*180/pi,0)
 elseif mode=="fishing" then self:UpdateFishing(t)
 elseif mode=="shore" then
  for i,node in ipairs(self.targets)do local target=a.shore.targets[i]
   node.enabled=target~=nil and not target.collected
   if target and not target.collected then node.position=self:Point(target.x,target.y);node.rotation=Quaternion(0,sin(t+target.phase)*5,0)end
  end
 end
end
function S:UpdateFishing(t)
 local a=self.app;local f=a.fish
 local motion=self.motion or (RenderSettings.legacy and LegacyOcean or Ocean)
 self.fishMat:SetShaderParameter("swim_time",Variant(t))
 local count=math.min(#(f.population or {}),#self.fishNodes)
 for i=1,count do local species=f.population[i]
  if self.fishSpecies[i]~=species.id then
   self.fishNodes[i]:Remove()
   self.fishNodes[i]=FishArt.Build(self,self.fishing,"CatchableFish"..i,species,i)
   self.fishSpecies[i]=species.id;self.activeFishCount=nil
  end
 end
 if self.activeFishCount~=count then
  for i,node in ipairs(self.fishNodes)do node:SetEnabledRecursive(i<=count)end
  self.activeFishCount=count
 end
 for i=1,count do local node=self.fishNodes[i]
  node.position=self:FishPoint(i,t)
  local nextp=self:FishPoint(i,t+.05)
  node:LookAt(nextp);node.rotation=node.rotation*Quaternion(0,sin(t*6+i)*8,0)
 end
 local height,pitch,roll=motion.FloatPose(0,-10.3,t,"fishing",0,4.8,1.8)
 self.fishingBoat.position=vec(0,.15+height,-10.3)
 self.fishingBoat.rotation=Quaternion(pitch,0,roll)
 self.rodRoot.position=vec(1.25,1.0,-7.4)
 local hooked=f.stage=="hooked";local casting=f.stage=="casting"
 local bend=hooked and (.22+f.power*.45) or .035
 self.rodRoot.rotation=Quaternion(-18+(casting and sin((f.castT or 0)*pi)*-32 or 0),hooked and sin(t*2.6)*8 or -12,0)
 if hooked or self.rodBend~=bend then
  for i,part in ipairs(self.rodParts)do
   part.position=vec(hooked and sin(t*2.6)*i*i*.005 or 0,-bend*i*i*.025,(i-1)*.72)
   part.rotation=Quaternion(bend*i*4.5,0,0)
  end
  self.rodBend=bend
 end
 local active=f.stage=="casting" or f.stage=="waiting" or hooked
 self.bobber.node.enabled=active;self.line.node.enabled=active
 self.ripple.enabled=active
 if active then
  local p=self:RayPoint(f.aimX or 225,f.aimY or a.h*.43,.06)
  if casting then local k=clamp(f.castT or 0,0,1);p=vec(1.2,1,-7)+(p-vec(1.2,1,-7))*k+vec(0,sin(k*pi)*2.8,0)end
  if hooked then p=p+vec(sin(t*3)*.3,0,cos(t*3)*.25)end
  if not casting then p=vec(p.x,motion.Height(p.x,p.z,t,1)+.08,p.z)end
  self.bobber.node.position=p
  self.ripple.position=vec(p.x,motion.Height(p.x,p.z,t,1)+.04,p.z)
  local size=.85+(sin(t*2.4)*.5+.5)*.35;self.ripple.scale=vec(size,1,size)
  self.line.geometry:BeginGeometry(0,TRIANGLE_LIST)
  self.line.count=0
  ---@type Node
  local endPart=self.rodParts[9]
  local tip=endPart.worldPosition+endPart.worldRotation*vec(0,0,.76)
  self.line:beam(tip,p,.009,C.cream);self.line.geometry:Commit()
 end
end
function S:DrawOverlay(v,w,h)
 if self.target then self.target:Draw(v,w,h)end
 local A=require("Game.Art");local a=self.app
 if a.mode=="shore" then
  require("Game.World").drawTool(v,w,h,a.shore,a.playtime,a.camera,function(x,y)return self:ToScreen(x,y)end)
 end
 if a.mode=="fishing" and a.fish.stage=="aim" then
  local x,y=a.fish.aimX,a.fish.aimY
  for i=1,15 do local t=i/15
   A.circle(v,w*.76+(x-w*.76)*t,h*.82+(y-h*.82)*t-sin(t*pi)*80,2,{255,245,188,220})
  end
  A.ellipse(v,x,y,24,10,{255,216,83,35},{255,235,158,255},2)
  A.circle(v,x,y,4,{255,235,158,255})
 end
 if a.mode=="home" then
  for _,p in ipairs(a.landmarkLabels or {})do
   A.line(v,{p.x,p.y,p.lx,p.ly},{255,247,218,175},1.4)
   A.circle(v,p.x,p.y,2.5,A.cream)
  end
  local top=a.hudTop or 0
  A.rect(v,277,86+top,157,32,{18,46,66,205},12)
  local label=self.lod==0 and "全岛" or self.lod==1 and "近景" or "细节"
  A.text(v,355,102+top,"视野 "..label,11,A.cream,NVG_ALIGN_CENTER)
 end
end
function S:GetRenderInfo()
 local info=self.target and self.target:Info()or {scale=1,mode="native"}
 info.scaleSource=RenderSettings.sceneScaleSource
 info.waterVisible=RenderSettings.waterVisible
 return info
end
function S:Stop()
 if self.target then self.target:Stop();self.target=nil else renderer:SetViewport(0,nil)end
 self.scene=nil
end
return S
