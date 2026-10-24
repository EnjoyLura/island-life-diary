-- Runtime 3D environments based on templates/scaffold-3d-scene.lua.
-- A retained Scene/Camera/Viewport lives behind the existing transparent UI.
-- Island: layered cel art in world space. Sea/fishing: limited real-time 3D.
-- No character meshes, hands or body parts are used.
local Mesh=require("Game.Mesh")
local ShoreWorld=require("Game.ShoreWorld")
local ShoreScene=require("Game.ShoreScene")
local ForestWorld=require("Game.ForestWorld")
local ForestScene=require("Game.ForestScene")
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
local FishingView=require("Game.FishingView")
local FishTraffic=require("Game.FishTraffic")
local FishingCast=require("Game.FishingCast")
local OceanField=require("Game.OceanField")
---@class CrescentScene3D
---@field islandGroundMat Material
---@field islandWindMat Material
---@field homeDetails Node
---@field homeMedium Node
---@field moored Node
---@field mooredAnchor {x:number,z:number}
---@field skyNode Node
---@field seabedNode Node
---@field tongs Node?
---@field shoreWaterMat Material?
---@field shoreOcean Node?
---@field forest Node?
---@field forestBasket Node?
---@field forestTargets Node[]?
---@field environment Zone
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
  self.schoolMat:SetShaderParameter("field_span",Variant(Bay.fieldSpan))
  self.schoolMat:SetShaderParameter("field_size",Variant(Bay.fieldSize))
  self.schoolMat:SetShaderParameter("wave_strength",Variant(Ocean.Strength("sailing")))
  self.schoolMat.renderOrder=132
 end
 self.motion.Bind(self.waterMat)
 self.wakeMat=surface(RenderSettings.legacy and "Shaders/BLGL/CrescentLegacyWake.shader" or "Shaders/BLGL/CrescentWake.shader")
 self.motion.Bind(self.wakeMat)
 if not RenderSettings.legacy then
  self.wakeMat:SetSurfaceTexture("water_field",self.waterBayField)
  self.wakeMat:SetShaderParameter("field_span",Variant(Bay.fieldSpan))
  self.wakeMat:SetShaderParameter("field_size",Variant(Bay.fieldSize))
 end
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
 assert(stone,"Crescent reef texture is missing")
 self.rockMat:SetSurfaceTexture("stone_map",stone)
 self.rockMat:SetSurfaceTexture("ocean_data",waterData)
 if RenderSettings.legacy then
  self.waterMat:SetSurfaceTexture("reef_data",assert(cache:GetResource("Texture2D","Textures/Crescent/ReefData.png")))
  Bay.Bind(self.waterMat)
 end
 self.skyMat=surface("Shaders/BLGL/CrescentSky.shader")
 local skyClouds=cache:GetResource("Texture2D","Textures/Crescent/SkyClouds.png")
 assert(skyClouds,"Crescent sky cloud data is missing")
 self.skyMat:SetSurfaceTexture("cloud_data",skyClouds)
 self.fishMat=surface("Shaders/BLGL/CrescentFish.shader")
 self.metal=surface("Shaders/BLGL/CrescentSolid.shader")
 self.metal:SetShaderParameter("surface_roughness",Variant(.28));self.metal:SetShaderParameter("surface_metallic",Variant(.55))
 local env=self.scene:CreateChild("Environment"):CreateComponent("Zone")
 self.environment=env
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
  for _,mode in ipairs({"home","sailing","chart","fishing"})do
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
 self.sharkNodes={}
 for _=1,#self.app.sharks do
  local node=Scenery.shark(self,self.sea);node.scale=vec(1.25,1.25,1.25)
  self.sharkNodes[#self.sharkNodes+1]=node
 end
 self.wakeTrail=WakeTrail.New()
 self.wakeMesh=Mesh.new(self.sea,"CurvedBoatWake",self.wakeMat)
 self.wakeMesh.geometry.castShadows=false;self.wakeMesh.geometry:SetDynamic(true)
 WakeTrail.Build(self.wakeMesh,{{x=0,z=-2},{x=0,z=-3}},0)
 self.wake=self.wakeMesh.node
end
function S:CreateFishing()
 -- Open-water drop-off. Sparse distant rocks sit well below the passing fish;
 -- the old six-metre coral garden made every fishing spot read as a pond.
 local floor=Mesh.new(self.fishing,"DeepFishingBed",self.bedMat)
 for i=1,4 do local x=(i%2==0 and -1 or 1)*(12+i*2);local z=12+i*5
  floor:rock(x,-24-i*.5,z,1.2,.7,1.8,{.27,.39,.37},i)
 end
 floor:finish();floor.geometry.castShadows=false
 self.fishSpecies={}
 for i=1,FishTraffic.capacity do
  self.fishNodes[i]=FishArt.Build(self,self.fishing,"CatchableFish"..i,Catalog.fish[(i-1)%5+1],i)
  self.fishSpecies[i]=Catalog.fish[(i-1)%5+1].id
 end
 -- The fishing position is fixed but the view opens toward an ocean horizon.
 -- Nearby reefs stay below water; no wall of primitive green hills in front.
 self.fishingBoat=Scenery.fishingBoat(self,self.fishing,"FishingBow",FishingView.height-1.7)
 self.fishingBoat.position=vec(0,0,-FishingView.back-3.56)
 self.rodRoot=self.fishing:CreateChild("HeldFishingRod")
 self.rodParts={}
 for i=1,9 do
  local part=Mesh.new(self.rodRoot,"RodSegment"..i,self.metal)
  local r=.036-(i-1)*.003
  part:tube(vec(0,0,0),vec(0,0,1),r,r*.91,i<3 and {.14,.20,.22} or {.70,.27,.11},10)
  part:torus(0,0,.08,r+.003,.008,C.gold,Vector3.FORWARD,12)
  part:torus(0,.055,.88,.046,.009,C.dark,Vector3.FORWARD,12)
  part:tube(vec(0,0,.88),vec(0,.043,.88),.012,.012,C.gold,6)
  if i==1 then
   -- Rear grip extends under the implied forearm, beyond the bottom of frame.
   part:tube(vec(0,0,-.95),vec(0,0,.64),.050,.046,{.22,.18,.13},10)
   for j=-11,8 do part:torus(0,0,j*.08,r+.015,.009,{.36,.29,.20},Vector3.FORWARD,12)end
  end
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
 self.baitMesh=Mesh.new(self.fishing,"HookAndBait",self.metal)
 self.baitMesh:torus(0,0,0,.045,.009,C.steel,Vector3.FORWARD,12)
 self.baitMesh:tube(vec(0,-.03,0),vec(.04,-.10,.02),.025,.018,{.86,.49,.25},7)
 self.baitMesh:tube(vec(.04,-.10,.02),vec(.01,-.16,.03),.018,.008,{.86,.49,.25},7)
 self.baitMesh:finish();self.baitMesh.geometry.castShadows=false
 self.line=Mesh.new(self.fishing,"FishingLine",self.solid);self.line.geometry:SetDynamic(true)
 self.line:beam(vec(0,-10,0),vec(0,-10,.1),.009,C.cream);self.line:finish();self.line.node.enabled=false
 -- One overlay ring is drawn after the water. Opaque stacked tori can enter
 -- the refraction source and create a second displaced cluster of rings.
 self.ripple=self.fishing:CreateChild("FloatRippleAnchor")
end
function S:CreateShore()
 ShoreScene.Build(self)
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
 if self.app.mode=="shore" then
  local xx,z=ShoreWorld.ToWorld(x,y);return vec(xx,ShoreWorld.Height(xx,z)+.15,z)
 end
 if self.app.mode=="forest"then
  local xx,z=ForestWorld.ToWorld(x,y);return vec(xx,ForestWorld.Height(xx,z)+.15,z)
 end
 return vec((x-1000)*.04,.1,-(y-1200)*.04)
end
function S:Project(p)
 local uv=self.camera:WorldToScreenPoint(p)
 return uv.x*450,uv.y*self.app.h
end
function S:ToScreen(x,y) return self:Project(self:Point(x,y))end
function S:ShoreTargetBounds(i)
 local target=self.app.shore.targets[i];local node=self.targets[i]
 local radius=target and (target.kind=="crab"and .48 or target.kind=="hole"and .14 or .30)or .3
 local height=target and target.kind=="crab"and .29 or .16
 return self:GatherTargetBounds(target,node,radius,height)
end
function S:ForestTargetBounds(i)
 local target=self.app.forest.targets[i];local node=self.forestTargets and self.forestTargets[i]
 return self:GatherTargetBounds(target,node,target and target.kind=="berry"and .72 or .48,.75)
end
function S:GatherTargetBounds(target,node,radius,height)
 if not target or target.collected or not node or not node.enabled then return nil end
 local p=node.position
 if self.cameraNode:WorldToLocal(p).z<=.15 then return nil end
 local l,top,r,bottom=math.huge,math.huge,-math.huge,-math.huge
 for _,dx in ipairs({-radius,radius})do for _,dy in ipairs({0,height})do for _,dz in ipairs({-radius,radius})do
  local corner=p+vec(dx,dy,dz)
  if self.cameraNode:WorldToLocal(corner).z<=.08 then return nil end
  local x,y=self:Project(corner);l=math.min(l,x);r=math.max(r,x);top=math.min(top,y);bottom=math.max(bottom,y)
 end end end
 -- Finger-friendly padding in design pixels, independent of render resolution.
 if r<0 or l>450 or bottom<0 or top>self.app.h then return nil end
 return l-18,top-18,r+18,bottom+18
end
---@return Vector3
function S:RayPoint(x,y,height)
 local r=self.camera:GetScreenRay(x/450,y/self.app.h)
 local k=((height or 0)-r.origin.y)/math.min(-.001,r.direction.y)
 return r.origin+r.direction*math.max(0,k)
end
function S:CastTarget(x,y,charge)
 local p,reach=FishingCast.Target(self.cameraNode.position,self:RayPoint(x,y,0),charge)
 local sx,sy=self:Project(vec(p.x,p.y,p.z))
 local cx,cy=self:ClampAim(sx,sy)
 if math.abs(cx-sx)>.01 or math.abs(cy-sy)>.01 then
  -- A steep downward view has less distant water on screen. Keep the charged
  -- landing guide visible rather than launching above the observation window.
  local q=self:RayPoint(cx,cy,0);p={x=q.x,y=0,z=q.z}
  local origin=self.cameraNode.position;reach=math.sqrt((p.x-origin.x)^2+(p.z-origin.z)^2)
  sx,sy=self:Project(q)
 end
 return p,sx,sy,reach
end
function S:FishPoint(i,_)
 local actor=(self.app.fish.actors or {})[i]
 if not actor then return nil end
 return vec(actor.x,actor.y,actor.z)
end
function S:FishingLandingPoint()
 return self.cameraNode:LocalToWorld(vec(.3,-.25,3.8))
end
function S:Pan(x,y,dx,dy)
 local d=self:RayPoint(x-dx,y-dy,.13)-self:RayPoint(x,y,.13)
 local c=self.app.camera;local focus=self:HomePoint(c.x,c.y)+d
 local xx,zz=IslandShape.Unmap(focus.x,focus.z)
 c.x=500+xx/.04;c.y=1000-zz/.026
end
function S:FishPose(i,t)
 local actor=(self.app.fish.actors or {})[i]
 if not actor or not actor.active or actor.y< -6.5 then return nil end
 local p=self:FishPoint(i,t)
 if self.cameraNode:WorldToLocal(p).z<=.1 then return nil end
 local x,y=self:Project(p)
 if x<20 or x>430 or y<140 or y>self.app.h-180 then return nil end
 return x,y,0,40,(i-1)%6+1
end
function S:ClampAim(x,y)
 local h=self.app.h
 local top=math.min(h-180,FishingView.AimTop(self.app.fish.viewY or 0,450/h,h))
 return clamp(x,35,415),clamp(y,top,h-180)
end
function S:SetCamera()
 local app=self.app;local mode=app.mode
 local c=app.camera;local f=app.fish or {};local old=self.cameraState
 local gw,gh=graphics:GetWidth(),graphics:GetHeight()
 local uiw=select(1,require("urhox-libs/UI").GetViewportSize())
 local vx,vy=f.viewX or 0,f.viewY or 0
 local shore=(mode=="forest"and app.forest or app.shore)or {};local sy,sp,sb=shore.yaw or 0,shore.pitch or 0,shore.bob or 0
 if old and old.mode==mode and old.cx==c.x and old.cy==c.y and old.zoom==c.zoom
  and old.vx==vx and old.vy==vy and old.h==app.h and old.scale==app.scale
  and old.x==app.x and old.y==app.y and old.gw==gw and old.gh==gh and old.uiw==uiw
  and ((mode~="shore"and mode~="forest")or (old.sy==sy and old.sp==sp and old.sb==sb))then return false end
 self.cameraState={mode=mode,cx=c.x,cy=c.y,zoom=c.zoom,vx=vx,vy=vy,h=app.h,scale=app.scale,
  x=app.x,y=app.y,gw=gw,gh=gh,uiw=uiw,sy=sy,sp=sp,sb=sb}
 local focus=self:Point(app.camera.x,app.camera.y)
 if mode=="fishing" then
  local fov,dx,dy,dz=FishingView.Camera(vx,vy,450/app.h)
  self.camera.orthographic=false;self.camera.fov=fov
  self.cameraNode.position=vec(0,FishingView.height,-FishingView.back)
  self.cameraNode:LookAt(self.cameraNode.position+vec(dx,dy,dz)*20)
 elseif mode=="home" then
  self.camera.orthographic=true;self.camera.orthoSize=app.h*.061/app.camera.zoom
  self.cameraNode.position=focus+vec(0,88,-70)
  self.cameraNode:LookAt(focus)
 elseif mode=="shore"or mode=="forest" then
  local world=mode=="forest"and ForestWorld or ShoreWorld
  local x,y,z,dx,dy,dz,fov=world.Camera(shore,450/app.h)
  self.camera.orthographic=false;self.camera.fov=fov
  self.cameraNode.position=vec(x,y,z);self.cameraNode:LookAt(vec(x+dx,y+dy,z+dz))
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
 local active=mode=="forest"and self.forest or mode=="home" and self.home or mode=="fishing" and self.fishing or (mode=="sailing" or mode=="map") and self.sea or self.shore
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
  if mode=="forest"then ForestScene.Build(self)end
  if self.target and self.target.SetWorldMode then self.target:SetWorldMode(mode)end
  -- Orthographic modes are completely covered by water/land; drawing a
  -- sky dome behind them only adds hidden fragment work.
  self.skyNode.enabled=RenderSettings.legacy or mode=="fishing"or mode=="shore"or mode=="forest"
  if self.seabedNode then self.seabedNode.enabled=mode~="shore"and mode~="forest"end
  if self.legacyWater then self.legacyWater.enabled=mode~="shore"and mode~="forest"and RenderSettings.waterVisible end
  if self.environment then
   self.environment.depthFogEnable=mode=="forest"
   self.environment.depthFogStart=48;self.environment.depthFogEnd=115
   self.environment.fogColor=mode=="forest"and Color(.39,.51,.38)or Color(.15,.56,.73)
  end
  -- Node.enabled only affects its own components. Scene roots need descendants too.
  Bay.PlaceHome(self,mode=="home")
  self.home:SetEnabledRecursive(homeVisible)
  self.sea:SetEnabledRecursive(mode=="sailing" or mode=="map")
  if self.boat then self.boat:SetEnabledRecursive(mode=="sailing")end
  for _,node in ipairs(self.sharkNodes or {})do node:SetEnabledRecursive(mode=="sailing")end
  for _,fish in ipairs(self.schoolNodes)do fish.node:SetEnabledRecursive(mode=="sailing")end
  self.fishing:SetEnabledRecursive(mode=="fishing")
  self.shore:SetEnabledRecursive(mode=="shore")
  if self.forest then self.forest:SetEnabledRecursive(mode=="forest")end
  if self.forestBasket then self.forestBasket:SetEnabledRecursive(mode=="forest")end
  if self.shoreOcean then self.shoreOcean.enabled=mode=="shore"and RenderSettings.waterVisible end
  if self.tongs then self.tongs:SetEnabledRecursive(mode=="shore")end
  self.activeFishCount=nil
  local radius=mode=="home" and 23.5 or mode=="fishing" and 3 or -35
  self.waterMat:SetShaderParameter("island_radius",Variant(radius))
  self.waterMat:SetShaderParameter("wave_strength",Variant(motion.Strength(mode)))
  self.waterMat:SetShaderParameter("reef_mode",Variant((mode=="sailing" or mode=="map") and 1 or 0))
  self.waterMat:SetShaderParameter("home_mode",Variant(mode=="home" and 1 or 0))
  self.waterMat:SetShaderParameter("fishing_mode",Variant(mode=="fishing" and 1 or 0))
  self.waterMat:SetShaderParameter("chart_mode",Variant(mode=="map" and 1 or 0))
  if self.waterRegions then
   self.waterMat:SetSurfaceTexture("water_field",mode=="home" and self.waterHomeField or self.waterBayField)
   local span,size=OceanField.Dimensions(mode)
   self.waterMat:SetShaderParameter("field_span",Variant(span))
   self.waterMat:SetShaderParameter("field_size",Variant(size))
   self.waterMat:SetShaderParameter("fishing_mode",Variant((mode=="fishing" or mode=="shore") and 1 or 0))
   self.deepWaterMat:SetShaderParameter("wave_strength",Variant(Ocean.Strength(mode)))
   self.deepWaterMat:SetShaderParameter("home_mode",Variant(mode=="home" and 1 or 0))
   self.deepWaterMat:SetShaderParameter("chart_mode",Variant(mode=="map" and 1 or 0))
  end
 end
 if self.waterRegions then
  local region=mode=="forest"and "woodland"or mode=="shore"and "local-beach"or WaterRenderer.Region(mode,a.camera.zoom)
  if self.activeWaterRegion~=region then
   for key,value in pairs(self.waterRegions)do value.root:SetEnabledRecursive(key==region and RenderSettings.waterVisible)end
   self.activeWaterRegion=region
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
 if mode=="forest"then
  self.skyMat:SetShaderParameter("ocean_time",oceanTime)
  ForestScene.Update(self,t)
  return
 end
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
  if modeChanged then b.enabled=mode~="fishing" and mode~="shore"and mode~="forest"end
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
  if mode=="sailing"then for i,shark in ipairs(a.sharks)do
   local point=self:Point(shark.x,shark.y);local node=self.sharkNodes[i]
   node.position=point+vec(0,motion.At(point.x,point.z,t,mode)-.2,0)
   node.rotation=Quaternion(0,shark.heading*180/pi,0)
  end end
 elseif mode=="fishing" then self:UpdateFishing(t,dt)
 elseif mode=="shore" then
  if self.shoreWaterMat then ShoreScene.Update(self,t)end
 elseif mode=="forest"then ForestScene.Update(self,t)
 end
end
-- Bait stays in the world when the player looks away. Nearby swimmers can
-- notice it even outside the screen; changing the camera cannot choose a fish.
function S:FishingTarget(bait)
 local best,bestDistance=nil,81
 for _,actor in ipairs(self.app.fish.actors or {})do
  if actor.active and actor.y>=-6.5 then
   local dx,dy,dz=actor.x-bait.x,actor.y-bait.y,actor.z-bait.z
   local d=dx*dx+dy*dy+dz*dz
   if d<bestDistance then best,bestDistance=actor,d end
  end
 end
 return best
end
function S:AlignRod(pose,target)
 if not target then return pose end
 local eye=self.cameraNode.position
 local x,z=target.x-eye.x,target.z-eye.z;local length=math.sqrt(x*x+z*z)
 if length<1e-6 then return pose end
 local normal=self.cameraNode:WorldToLocal(eye+vec(z/length,0,-x/length))
 local f=self.app.fish
 local release=FishingView.RodPose(450/self.app.h,f.viewY,"casting",f.charge,FishingCast.flickSeconds)
 FishingView.AlignRod(release,normal.x,normal.y,normal.z)
 -- Keep one swing plane through the backswing too. Solving yaw again when
 -- the rod is near vertical would spin it sideways around its own grip.
 pose.yaw=release.yaw
 return pose
end
function S:CastPath(f)
 local pose=FishingView.RodPose(450/self.app.h,f.viewY,"casting",f.charge,FishingCast.flickSeconds)
 self:AlignRod(pose,f.castPoint)
 local x,y,z=FishingView.RodTip(pose)
 local launch=self.cameraNode:LocalToWorld(vec(x,y,z))
 local duration=FishingCast.Duration(f.castRange or 18)
 local motion=self.motion or (RenderSettings.legacy and LegacyOcean or Ocean)
 local p=f.castPoint
 local water=motion.Height(p.x,p.z,self.app.playtime+FishingCast.flickSeconds+duration,1)
 return launch,vec(p.x,water+.08,p.z),duration
end
function S:PrepareCast(f)
 f.rodStart={}
 local pose=self.rodPose or FishingView.RodPose(450/self.app.h,f.viewY,"idle",0)
 for key,value in pairs(pose)do f.rodStart[key]=value end
 local launch,landing=self:CastPath(f)
 f.castLaunch={x=launch.x,y=launch.y,z=launch.z}
 f.castLanding={x=landing.x,y=landing.y,z=landing.z}
end
function S:UpdateFishing(t,dt)
 local a=self.app;local f=a.fish
 local motion=self.motion or (RenderSettings.legacy and LegacyOcean or Ocean)
 self.fishMat:SetShaderParameter("swim_time",Variant(t))
 local present={};self.fishVisible=self.fishVisible or {}
 for _,actor in ipairs(f.actors or {})do
  local slot=actor.slot;present[slot]=actor
  if self.fishSpecies[slot]~=actor.species.id then
   self.fishNodes[slot]:Remove()
   self.fishNodes[slot]=FishArt.Build(self,self.fishing,"CatchableFish"..slot,actor.species,slot)
   self.fishSpecies[slot]=actor.species.id;self.fishVisible[slot]=nil
  end
  if actor.active then
   local node=self.fishNodes[slot]
   node.position=vec(actor.x,actor.y,actor.z)
   node.rotation=Quaternion(-math.asin(clamp(actor.dy,-1,1))*180/pi,math.atan(actor.dx,actor.dz)*180/pi,actor.roll or 0)
  end
 end
 for slot,node in ipairs(self.fishNodes)do
  local visible=present[slot]~=nil and present[slot].active
  if self.activeFishCount==nil or self.fishVisible[slot]~=visible then node:SetEnabledRecursive(visible);self.fishVisible[slot]=visible end
 end
 self.activeFishCount=#(f.actors or {})
 local selected=f.target
 self.fishMat:SetShaderParameter("fish_action",Variant(selected and Vector4(selected.slot,selected.gape or 0,f.stage=="hooked"and 1 or 0,selected.beat or 0)or Vector4(-1,0,0,0)))
 local boatZ=-FishingView.back-3.56
 local height,pitch,roll=motion.FloatPose(0,boatZ,t,"fishing",0,4.8,1.8)
 height,pitch,roll=FishingView.Bob(height,pitch,roll,t)
 self.fishingBoat.position=vec(0,height,boatZ)
 self.fishingBoat.rotation=Quaternion(pitch,0,roll)
 -- Share the small heave with the eye; keep the horizon level for touch aiming.
 self.cameraNode.position=vec(0,FishingView.height+height*.7,-FishingView.back)
 local hooked=f.stage=="hooked";local casting=f.stage=="casting"
 local charge=f.charge or 0
 local desired=FishingView.RodPose(450/a.h,f.viewY,f.stage,charge,f.castElapsed,f.rodStart)
 self:AlignRod(desired,f.castPoint)
 desired.pitch=desired.pitch+(casting and 0 or sin(t*1.3)*.35)
 desired.yaw=desired.yaw+(hooked and sin(t*2.6)*5 or 0)
 if hooked then desired.bend=.22+f.power*.45 end
 -- A time-sampled stroke meets its release pose exactly at every frame rate.
 -- Applying another low-pass here delayed the tip behind the flying lure.
 self.rodPose=casting and desired or FishingView.SmoothRod(self.rodPose,desired,dt,f.stage)
 local pose=self.rodPose
 local bend=pose.bend
 local rootX,rootY,rootZ=FishingView.RodRoot(pose)
 self.rodRoot.position=self.cameraNode:LocalToWorld(vec(rootX,rootY,rootZ))
 self.rodRoot.scale=vec(pose.size,pose.size,pose.size)
 self.rodRoot.rotation=self.cameraNode.worldRotation*Quaternion(pose.pitch,pose.yaw,pose.roll)
 if hooked or self.rodBend~=bend then
  local side=hooked and sin(t*2.6)*.005 or 0
  for i,part in ipairs(self.rodParts)do
   local j=i-1
   local start=vec(side*j*j,-bend*j*j*.025,j*FishingView.rodStep)
   local finish=vec(side*i*i,-bend*i*i*.025,i*FishingView.rodStep)
   local delta=finish-start;local length=delta.length
   part.position=start;part.scale=vec(1,1,length)
   part.rotation=Quaternion(-math.asin(delta.y/length)*180/pi,math.atan(delta.x,delta.z)*180/pi,0)
  end
  self.rodBend=bend
 end
 local active=f.stage=="casting" or f.stage=="waiting" or hooked
 -- Use the engine hierarchy for both framing and guide attachment.
 local tip=self.rodParts[9]:LocalToWorld(vec(0,0,1))
 self.rodTip=tip
 self.bobber.node.enabled=active;self.baitMesh.node.enabled=active;self.line.node.enabled=active
 self.ripple.enabled=active and not casting
 if active and tip then
  local aim=f.bait
  if not aim then local q=self:RayPoint(f.aimX or 225,f.aimY or a.h*.43,0);aim={x=q.x,y=-.4,z=q.z}end
  local x,z=aim.x,aim.z
  if hooked and f.target then local hx,hy,hz=FishTraffic.Mouth(f.target);x,z=hx,hz end
  local water=motion.Height(x,z,t,1)
  local p=vec(x,water+.08-(f.bite or 0)*.15,z)
  local bait=vec(x,water-.4,z)
  if f.bait then f.bait.y=motion.Height(f.bait.x,f.bait.z,t,1)-.4 end
  if casting then
   local token=f.castSerial or f
   if self.castFish~=f or self.castToken~=token then self.castTip=nil;self.castToken=token;self.castFish=f end
   if (f.flickT or 1)<1 then p=tip
   else
    self.castTip=self.castTip or (f.castLaunch and vec(f.castLaunch.x,f.castLaunch.y,f.castLaunch.z))or tip
    local endPoint=f.castLanding or p
    local q=FishingCast.Flight(self.castTip,endPoint,f.castT or 0,f.castDuration or .9)
    p=vec(q.x,q.y,q.z)
   end
   bait=p-vec(0,.4,0)
  elseif hooked and f.target then
   local hx,hy,hz=FishTraffic.Mouth(f.target);bait=vec(hx,hy,hz)
   if hy>water then p=bait end
  end
  self.bobber.node.position=p;self.baitMesh.node.position=bait
  self.ripple.position=vec(p.x,water+.04,p.z)
  self.ripple.enabled=not casting and p.y<=water+.18
  local size=.85+(sin(t*2.4)*.5+.5)*.35;self.ripple.scale=vec(size,1,size)
  self.line.geometry:BeginGeometry(0,TRIANGLE_LIST)
  self.line.count=0
  if (p-tip).length>.01 then self.line:beam(tip,p,.006,C.cream)end
  if (bait-p).length>.02 then self.line:beam(p,bait,.004,C.cream)end
  self.line.geometry:Commit()
 end
end
function S:DrawOverlay(v,w,h)
 if self.target then self.target:Draw(v,w,h)end
 local Skin=require("Game.UISkin")
 local A=require("Game.Art");local a=self.app
 if a.mode=="fishing" and a.fish.stage=="aim" then
  local f=a.fish;local x,y=f.aimX,f.aimY
  if f.castPoint then
   local launch,landing,duration=self:CastPath(f)
   local dots=FishingCast.Guide(launch,landing,duration,function(q)
    local p=vec(q.x,q.y,q.z);local localPoint=self.cameraNode:WorldToLocal(p)
    if localPoint.z<=.15 then return 0,0,localPoint.z end
    local sx,sy=self:Project(p);return sx,sy,localPoint.z
   end,{left=12,right=w-12,top=(a.hudTop or 56)+150,bottom=h-180})
   for _,p in ipairs(dots)do A.circle(v,p.x,p.y,1.8,{255,245,188,210})end
  end
  if not Skin.Draw(v,"NAV-target",x-27,y-14,54,28)then A.ellipse(v,x,y,24,10,{255,216,83,35},{255,235,158,255},2)end
  A.circle(v,x,y,4,{255,235,158,255})
 end
 if a.mode=="fishing"and self.ripple.enabled then
  local contact=self.ripple.position
  if self.cameraNode:WorldToLocal(contact).z>.15 then
   local x,y=self:Project(contact)
   if x>0 and x<w and y>0 and y<h then
    local radius=.16+.09*(.5+.5*sin(a.playtime*2.4))
    local xx,xy=self:Project(contact+vec(radius,0,0))
    local zx,zy=self:Project(contact+vec(0,0,radius))
    local points={}
    for i=0,32 do local angle=i*2*pi/32;local c,s=math.cos(angle),sin(angle)
     points[#points+1]=x+(xx-x)*c+(zx-x)*s;points[#points+1]=y+(xy-y)*c+(zy-y)*s
    end
    A.line(v,points,{183,233,221,145},1)
   end
  end
 end
 if a.mode=="home" then
  nvgSave(v);nvgIntersectScissor(v,0,0,w,h)
  for _,p in ipairs(a.landmarkLabels or {})do
   A.line(v,{p.x,p.y,p.lx,p.ly},{255,247,218,175},1.4)
   A.circle(v,p.x,p.y,2.5,A.cream)
  end
  nvgRestore(v)

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
