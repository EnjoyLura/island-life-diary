-- Retained, spatially batched forest. Built only on first entry.
local Mesh=require("Game.Mesh")
local W=require("Game.ForestWorld")
local Plants=require("Game.ShoreArt")
local Art=require("Game.ForestScenery")
local B={}
local sin,cos,pi=math.sin,math.cos,math.pi
local function v(x,y,z)return Vector3(x,y,z)end
local function mat(path)
 local m=Material:new();assert(m:SetSurfaceShader("Shaders/BLGL/"..path..".shader"));return m
end
local function finish(m,distance)m:finish();m.geometry.drawDistance=distance or 90 end
local function mushroom(m,color,seed)
 for i=1,3 do
  local x,z=cos(i*2.4+seed)*.19,sin(i*2.4+seed)*.19;local h=.22+i*.07
  m:tube(v(x,0,z),v(x+.025,h,z),.038,.030,{.88,.79,.57},6)
  m:ellipsoid(x+.025,h,z,.15+i*.016,.075,.15+i*.016,color,8,4)
  for j=1,3 do local a=j*2.1+i
   m:ellipsoid(x+.025+cos(a)*.09,h+.064,z+sin(a)*.09,.022,.012,.023,{.96,.88,.63},5,2)
  end
 end
end
local function resource(m,t)
 local c=t.species.color;local color={c[1]/255,c[2]/255,c[3]/255}
 if t.habitat=="tree"then
  local a=t.angle or 0;local inward=v(-cos(a),0,-sin(a))
  if t.kind=="berry"then
   Art.Limb(m,inward*.6+v(0,.24,0),v(0,.12,0),.035,.012,{.40,.30,.17},5)
   for i=1,7 do local aa=i*2.399
    m:ellipsoid(cos(aa)*.16,.12+(i%3)*.10,sin(aa)*.16,.065,.075,.065,color,6,3)
   end
   Plants.Fern(m,0,.18,0,.28,t.phase)
  elseif t.kind=="mushroom"then
   for i=1,3 do
    local p=inward*(.18-i*.06)+v(0,i*.16,0)
    m:ellipsoid(p.x,p.y,p.z,.23+i*.025,.055,.19+i*.02,color,9,3)
    m:ellipsoid(p.x,p.y+.025,p.z,.15,.035,.13,{.73,.40,.16},8,3)
   end
  else
   Art.Limb(m,inward*.55,v(0,.16,0),.075,.035,color,7)
   Art.Limb(m,inward*.10+v(0,.12,0),v(.18,.38,.07),.035,.013,color,5)
  end
 elseif t.kind=="mushroom"then mushroom(m,color,t.phase)
 elseif t.kind=="berry"then
  Plants.Shrub(m,0,0,0,.65,t.phase)
  for i=1,9 do local a=i*2.399
   m:ellipsoid(cos(a)*.31,.35+i%3*.1,sin(a)*.31,.058,.065,.058,color,6,3)
  end
 elseif t.kind=="wood"then
  m:tube(v(-.35,.09,-.18),v(.38,.15,.23),.065,.035,color,7)
  m:tube(v(.02,.12,.02),v(-.02,.20,.38),.04,.018,color,6)
 else
  Plants.Fern(m,0,0,0,.55,t.phase)
  if t.species.quality>=3 then
   m:tube(v(0,0,0),v(0,.48,0),.016,.009,{.42,.61,.30},5)
   for i=1,5 do local a=i*2*pi/5
    m:ellipsoid(cos(a)*.055,.48,sin(a)*.055,.045,.02,.045,{.96,.81,.40},5,2)
   end
  end
 end
end
local function waterEdge(z,side)
 local lo,hi=W.StreamWidth(z)-.5,W.StreamWidth(z)+2.3
 for _=1,9 do local d=(lo+hi)*.5
  if W.GroundHeight(W.Stream(z)+side*d,z)>W.WaterHeight(z)then hi=d else lo=d end
 end
 return W.Stream(z)+side*(lo+hi)*.5
end
local function stream(m,z0)
 local function sample(z,q)
  local lo,hi=waterEdge(z,-1),waterEdge(z,1)
  local x=lo+(hi-lo)*(q*.5+.5)
  local depth=math.max(0,W.WaterHeight(z)-W.GroundHeight(x,z))
  return v(x,W.WaterHeight(z)+.024,z),{depth/.5,q*.5+.5,W.Shade(x,z)}
 end
 -- Concentrate sections at the waterline instead of stretching one large
 -- triangle from a dry bank to the deep centre of a wide pool.
 local sections={-1,-.94,-.82,-.60,-.30,0,.30,.60,.82,.94,1}
 for z=z0,z0+23,1 do for i=1,#sections-1 do
  local q0,q1=sections[i],sections[i+1]
  local a,ca=sample(z,q0);local b,cb=sample(z+1,q0)
  local c,cc=sample(z+1,q1);local d,cd=sample(z,q1)
  for _,p in ipairs({{a,ca},{b,cb},{c,cc},{a,ca},{c,cc},{d,cd}})do m:vertex(p[1],Vector3.UP,p[2])end
  m.count=m.count+2
 end end
end
local function landmarks(s)
 local m=s:NewMesh(s.forest,"WoodlandLandmarks",false)
 for _,z in ipairs(W.bridges)do Art.Bridge(m,z)end
 for i=1,30 do
  local z=-9+i*4.7;local side=i%2==0 and 1 or -1
  local x=W.Stream(z)+side*(W.StreamWidth(z)+.55);local y=W.WaterHeight(z)-.18
  m:rock(x,y,z,.45+i%3*.18,.42+i%4*.10,.38+i%2*.17,{.36,.43,.34},i)
  if i%3==0 then Plants.Fern(m,x+side*.6,W.GroundHeight(x+side*.6,z),z,.8,i)end
 end
 for i,p in ipairs(W.layout)do if p.habitat=="log"then Art.Log(m,p.x+.7,p.z+.4,2.5,p.index*.7)end end
 for i,g in ipairs(W.glades)do
  local x,z=g.x+2.6,g.z+2.7;local y=W.GroundHeight(x,z)
  m:box(x,y+.43,z,2.1,.12,.68,{.51,.36,.21})
  for dx=-1,1,2 do m:box(x+dx*.76,y+.20,z,.13,.40,.45,{.35,.26,.16})end
  Art.Log(m,g.x-3,g.z+2,2.8,i*1.3)
  for j=1,6 do local a=j*pi/3
   m:rock(g.x+cos(a)*1.15,W.GroundHeight(g.x+cos(a)*1.15,g.z+sin(a)*1.15)-.05,g.z+sin(a)*1.15,.24,.22,.25,{.39,.43,.31},j)
  end
 end
 for i,p in ipairs({{W.Path(1)-2.7,1},{W.Path(26)-2.6,26},{W.WestPath(42)+2.6,42},{W.Stream(72)-5.0,72},{W.EastPath(101)+2.5,101},{W.Path(111)-2.6,111}})do
  local x,z=p[1],p[2];local y=W.GroundHeight(x,z)
  m:box(x,y+.63,z,.10,1.26,.10,{.41,.28,.16})
  m:box(x,y+1.12,z,1.05,.34,.10,{.70,.54,.30})
  m:tri(v(x+.2,y+1.02,z-.06),v(x+.43,y+1.12,z-.06),v(x+.2,y+1.23,z-.06),{.94,.87,.61})
 end
 finish(m,110)
end
function B.Build(s)
 if s.forest then return end
 s.forest=s.scene:CreateChild("Moonwood");s.forestTargets={};s.forestChunks={}
 s.forestGroundMat=mat("CrescentForestGround")
 s.forestGroundMat:SetSurfaceTexture("sand_art",assert(cache:GetResource("Texture2D","Textures/Crescent/SeabedSand.jpg")))
 s.forestLeavesMat=mat("CrescentForestLeaves");s.forestBarkMat=mat("CrescentForestBark")
 s.forestWaterMat=mat("CrescentForestStream")
 s.forestWaterMat:SetSurfaceTexture("ripples",assert(cache:GetResource("Texture2D","Textures/Crescent/WaterWaves.png")))
 s.forestWaterMat:SetSurfaceTexture("bed_art",assert(cache:GetResource("Texture2D","Textures/Crescent/SeabedSand.jpg")))
 for row=0,6 do for col=0,5 do
  local x0,z0=-72+col*24,-24+row*24;local id=row*6+col+1
  local root=s.forest:CreateChild("ForestCell"..id);s.forestChunks[#s.forestChunks+1]=root
  local ground=Mesh.new(root,"ForestGround",s.forestGroundMat);Art.Ground(ground,x0,z0);finish(ground,0)
  local trees={};for _,t in ipairs(W.trees)do if t.x>=x0 and t.x<x0+24 and t.z>=z0 and t.z<z0+24 then trees[#trees+1]=t end end
  if #trees>0 then
   local trunks=Mesh.new(root,"BranchedTrunks",s.forestBarkMat);local leaves=Mesh.new(root,"LayeredCanopies",s.forestLeavesMat)
   for _,t in ipairs(trees)do Art.Tree(trunks,leaves,t)end
   -- Both parts remain beyond the fog range; the small support margin
   -- accounts for their different bounding-box centres during culling.
   finish(trunks,155);finish(leaves,142)
  end
  local floor=s:NewMesh(root,"ForestUnderstory",false);Art.Understory(floor,x0,z0,id);finish(floor,52)
 end end
 for row=0,6 do
  local m=Mesh.new(s.forest,"RunningBrook"..row,s.forestWaterMat);stream(m,-24+row*24);finish(m,108)
 end
 landmarks(s)
 -- Connect the high planted edges to an outer bank. A low detached plane
 -- would expose sky below the terrain edge when seen through distant trees.
 local skirt=s:NewMesh(s.forest,"ForestGroundSkirt",false)
 local function apron(x,z,xx,zz)
  local function p(a,b)return v(a,W.GroundHeight(a,b)-.02,b)end
  skirt:quad(p(x,z),p(x,zz),p(xx,zz),p(xx,z),{.28,.39,.21})
 end
 for x=-72,70,2 do
  apron(x,-40,x+2,-24);apron(x,144,x+2,162)
 end
 for z=-40,160,2 do apron(-86,z,-72,z+2);apron(72,z,86,z+2)end
 finish(skirt,0)
 for i,t in ipairs(s.app.forest.targets)do
  local m=s:NewMesh(s.forest,"ForestFind"..i,false);resource(m,t);finish(m,32)
  local x,z=W.ToWorld(t.x,t.y);m.node.position=v(x,W.TargetHeight(t),z)
  s.forestTargets[i]=m.node;m.node.enabled=not t.collected
 end
 local focus=s:NewMesh(s.forest,"ForestPickupFocus",false)
 focus:torus(0,.018,0,.49,.012,{.97,.81,.37},nil,16);finish(focus);s.forestFocus=focus.node
 local basket=s:NewMesh(s.cameraNode,"GatheringBasket",false)
 local wicker={.62,.41,.20};basket:cone(0,0,0,.13,.21,.22,wicker,12)
 for i=0,4 do basket:torus(0,i*.048,0,.13+i*.017,.008,{.81,.61,.32},nil,12)end
 basket:tube(v(-.19,.22,0),v(-.17,.43,0),.015,.015,wicker,6)
 basket:tube(v(.19,.22,0),v(.17,.43,0),.015,.015,wicker,6)
 basket:tube(v(-.17,.43,0),v(.17,.43,0),.015,.015,wicker,6)
 basket:finish();basket.node.scale=v(.55,.55,.55);basket.node.position=v(.30,-.42,.80);basket.node.rotation=Quaternion(-12,8,-8)
 s.forestBasket=basket.node
end
function B.Update(s,t)
 local app=s.app;local state=app.forest
 s.forestLeavesMat:SetShaderParameter("wind_time",Variant(t))
 s.forestWaterMat:SetShaderParameter("flow_time",Variant(t))
 for i,node in ipairs(s.forestTargets)do local enabled=not state.targets[i].collected
  if node.enabled~=enabled then node.enabled=enabled end
 end
 local target=app.nearTarget;s.forestFocus.enabled=target~=nil
 if target then local x,z=W.ToWorld(target.x,target.y);s.forestFocus.position=v(x,W.TargetHeight(target)+.015,z)end
 local pick=math.max(0,(state.pickupUntil or 0)-t)/.32
 s.forestBasket.position=v(.30,-.42-pick*.05+(state.bob or 0)*.5,.80)
end
return B
