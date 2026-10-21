-- Retained first-person beach. All terrain is built once; only the tool and
-- nearby creatures move. Sand detail and local surf never read the screen.
local Mesh=require("Game.Mesh")
local World=require("Game.ShoreWorld")
local B={}
local sin,cos,pi=math.sin,math.cos,math.pi
local function v(x,y,z)return Vector3(x,y,z)end
local sand={.91,.82,.64};local stone={.48,.51,.47};local steel={.72,.80,.80}
local function material(path)
 local m=Material:new();assert(m:SetSurfaceShader("Shaders/BLGL/"..path..".shader"));return m
end
local function axis()
 local a={-700,-300,-160,-110,-80}
 for z=-76,76,2 do a[#a+1]=z end
 for _,z in ipairs({80,110,160,300,700})do a[#a+1]=z end
 return a
end
local function crab(m)
 local green={.24,.43,.32};local dark={.08,.16,.14};local orange={.66,.35,.19}
 m:ellipsoid(0,.12,0,.23,.11,.17,green,10,5)
 m:ellipsoid(0,.16,.02,.19,.07,.14,{.35,.53,.36},8,4)
 for _,side in ipairs({-1,1})do
  for k=1,4 do
   local z=.13-k*.075;local joint=v(side*.32,.09,z-.06)
   m:tube(v(side*.15,.10,z),joint,.022,.016,green,5)
   m:tube(joint,v(side*(.36+k*.018),.025,z-.13),.016,.007,orange,5)
  end
  m:tube(v(side*.17,.14,.11),v(side*.29,.17,.27),.035,.048,green,6)
  m:ellipsoid(side*.29,.18,.30,.075,.06,.095,orange,8,4)
  for _,sign in ipairs({-1,1})do
   m:tube(v(side*.29+sign*.038,.18,.34),v(side*.29+sign*.028,.18,.41),.022,.008,orange,5)
  end
  m:tube(v(side*.09,.18,.12),v(side*.11,.25,.16),.012,.010,green,5)
  m:ellipsoid(side*.11,.25,.16,.025,.024,.025,dark,6,4)
 end
end
local function shell(m,conch)
 if conch then
  for i=0,14 do
   local a=i*.62;local b=(i+1)*.62;local r=.17*(1-i/18);local rr=.17*(1-(i+1)/18)
   m:tube(v(cos(a)*r,.05+i*.007,sin(a)*r),v(cos(b)*rr,.05+(i+1)*.007,sin(b)*rr),.048-i*.002,.046-i*.002,
    i%3==0 and {.88,.70,.45}or{.94,.81,.62},6)
  end
  m:ellipsoid(-.15,.05,-.07,.09,.045,.065,{.36,.26,.21},8,4)
 else
  for i=0,15 do local a=-pi*.5+i*pi/16;local b=a+pi/16
   local p=v(sin(a)*.23,.025,cos(a)*.23);local q=v(sin(b)*.23,.025,cos(b)*.23)
   local c=i%2==0 and {.90,.76,.66}or{.99,.90,.78}
   m:tri(v(0,.10,-.05),p,q,c)
   m:tube(v(0,.105,-.05),(p+q)*.5+v(0,.008,0),.006,.004,{.76,.57,.45},4)
  end
  m:box(0,.025,-.065,.15,.04,.09,{.86,.69,.57})
 end
end
local function palm(trunks,leaves,x,z,seed)
 local h=4.4+seed%3*.55;local y=World.Height(x,z)
 trunks:tube(v(x,y,z),v(x+.6,y+h,z),.18,.10,{.43,.31,.19},8)
 for k=0,6 do
  local a=k*2*pi/7+seed;local across=v(-sin(a),0,cos(a))
  for j=0,3 do local t=j/4;local u=(j+1)/4
   local p=v(x+.6+cos(a)*t*3,y+h+sin(t*pi)*.5-t*t,z+sin(a)*t*3)
   local q=v(x+.6+cos(a)*u*3,y+h+sin(u*pi)*.5-u*u,z+sin(a)*u*3)
   local w=sin((t+.05)*pi)*.40;local ww=sin(u*pi)*.40
   local c=(j+k)%3==0 and {.39,.57,.23}or{.20,.40,.22}
   leaves:quad(p,q,q+across*ww-v(0,.10,0),p+across*w-v(0,.10,0),c)
   leaves:quad(p-across*w-v(0,.10,0),q-across*ww-v(0,.10,0),q,p,c)
  end
 end
end
function B.Build(s)
 s.shoreSandMat=material("CrescentBeachSand")
 s.shoreWaterMat=material("CrescentBeachWater")
 local sandArt=assert(cache:GetResource("Texture2D","Textures/Crescent/SeabedSand.jpg"))
 s.shoreSandMat:SetSurfaceTexture("sand_art",sandArt)
 s.shoreWaterMat:SetSurfaceTexture("sand_art",sandArt)
 s.shoreWaterMat:SetSurfaceTexture("wave_data",assert(cache:GetResource("Texture2D","Textures/Crescent/WaterWaves.png")))
 local zs=axis();local xs={-80,-32,-16,-8,-4,-2,0,2,4,6,8,10,12,15,18,22,28,36,50,80,240}
 -- Each strip is an independently culled static chunk.
 for first=1,#zs-1,4 do
  local m=Mesh.new(s.shore,"BeachSandStrip"..first,s.shoreSandMat)
  for j=first,math.min(#zs-1,first+3)do for i=1,#xs-1 do
   -- Curved shoreline vertices need separate x at each row. Exact shared
   -- vertices keep neighbouring strips closed without skirts or a drop-off.
   local z,zz=zs[j],zs[j+1]
   local function point(d,az)
    local x=World.Coast(az)+d;local nx,ny,nz=World.Normal(x,az)
    return v(x,World.Height(x,az),az),v(nx,ny,nz)
   end
   local a,na=point(xs[i],z);local b,nb=point(xs[i],zz)
   local c,nc=point(xs[i+1],zz);local d,nd=point(xs[i+1],z)
   m:smoothTri(a,b,c,na,nb,nc,sand);m:smoothTri(a,c,d,na,nc,nd,sand)
  end end
  m:finish()
 end
 local sea=Mesh.new(s.shore,"LocalBeachOcean",s.shoreWaterMat)
 local offsets={-1300,-500,-180,-70,-32,-16,-8,-4,-2,-.35}
 for j=1,#zs-1 do for i=1,#offsets-1 do
  local z,zz=zs[j],zs[j+1];local a,b=offsets[i],offsets[i+1]
  sea:quad(v(World.Coast(z)+a,0,z),v(World.Coast(zz)+a,0,zz),v(World.Coast(zz)+b,0,zz),v(World.Coast(z)+b,0,z),{1,1,1})
 end end
 sea:finish();s.shoreOcean=sea.node
 local rocks=s:NewMesh(s.shore,"BeachRockGroups")
 for _,o in ipairs(World.obstacles)do local y=World.Height(o.x,o.z)
  rocks:rock(o.x,y-.16,o.z,o.r,.6+o.seed%4*.24,o.r,stone,o.seed)
  rocks:rock(o.x+o.r*.6,y-.04,o.z-.3,o.r*.4,.36,o.r*.4,{.59,.58,.50},o.seed+9)
 end
 -- Closing rocky headlands and dunes disguise the small world's walk limits.
 for _,side in ipairs({-1,1})do for i=0,11 do
  local z=side*(64+i*.9);local x=World.Coast(z)-3+i*2.6
  rocks:rock(x,World.Height(x,z)-.2,z,2.0,1.4+i%3*.5,2.0,stone,i+31)
 end end
 rocks:finish()
 local trunks=s:NewMesh(s.shore,"BeachPalmTrunks");local leaves=s:NewMesh(s.shore,"BeachPalmCanopy")
 for _,p in ipairs(World.palms)do
  palm(trunks,leaves,p.x,p.z,p.seed)
 end
 trunks:finish();leaves:finish()
 local grass=s:NewMesh(s.shore,"BeachDuneGrasses",false)
 for i=1,100 do local z=-68+(i*7.31)%136;local x=World.Coast(z)+22+(i*3.37)%19;local y=World.Height(x,z)
  for k=0,3 do local a=i+k*1.57;local tip=v(x+cos(a)*.20,y+.35+(i%3)*.1,z+sin(a)*.20)
   grass:tri(v(x-.08,y,z),tip,v(x+.08,y,z),{.41,.49,.24})
  end
 end
 grass:finish()
 for i,t in ipairs(s.app.shore.targets)do
  local m=s:NewMesh(s.shore,"ShoreTarget"..i,false)
  if t.kind=="crab"then crab(m)
  elseif t.kind=="shell"then shell(m,t.id=="conch")
  elseif t.kind=="hole"then
   m:cone(0,0,0,.10,.065,.006,{.23,.20,.15},12)
   m:torus(0,.008,0,.105,.015,sand,nil,12)
  else
   m:rock(0,-.02,0,.28,.10,.22,{.77,.68,.51},i)
   m:cone(.05,.06,.02,.045,.04,.005,{.29,.25,.18},10)
  end
  m:finish();s.targets[i]=m.node
 end
 -- Attached to the camera, not to an animated world-space billboard.
 local toolParent=s.cameraNode or s.shore
 s.tongs=toolParent:CreateChild("HeldBeachTongs")
 local grip=Mesh.new(s.tongs,"TongsGrip",s.metal)
 grip:box(0,0,-.11,.075,.045,.28,{.13,.25,.27})
 grip:box(0,.025,-.16,.08,.015,.09,{.89,.59,.23})
 grip:tube(v(0,0,-.04),v(0,0,.05),.028,.024,steel,8);grip:finish()
 s.tongJaws={}
 for _,side in ipairs({-1,1})do
  local m=Mesh.new(s.tongs,"TongsJaw",s.metal)
  m:box(side*.014,-.008,.31,.021,.026,.59,steel)
  m:tube(v(side*.014,-.008,.59),v(side*.022,-.075,.70),.018,.022,steel,6)
  m:box(side*.014,-.076,.715,.065,.016,.10,steel)
  for k=1,4 do m:box(side*.014,-.088,.675+k*.017,.062,.008,.005,{.43,.51,.51})end
  m:finish();s.tongJaws[#s.tongJaws+1]=m.node
 end
 s.tongs:SetEnabledRecursive(false)
end
function B.Update(s,t)
 local state=s.app.shore;local px,pz=World.ToWorld(state.x or 900,state.y or 1050)
 s.shoreSandMat:SetShaderParameter("beach_time",Variant(t))
 s.shoreWaterMat:SetShaderParameter("beach_time",Variant(t))
 for i,node in ipairs(s.targets)do local target=state.targets[i]
  local x,z=0,0;if target and target.x then x,z=World.ToWorld(target.x,target.y)end
  local visible=target~=nil and not target.collected and (x-px)^2+(z-pz)^2<38^2
  node.enabled=visible
  if visible then
   local lift=target.kind=="crab"and sin(t*3+target.phase)*.008 or 0
   node.position=v(x,World.Height(x,z)+.015+lift,z)
   node.rotation=Quaternion(0,target.kind=="crab"and sin(t*.65+target.phase)*9 or i*137,0)
  end
 end
 local progress=state.action and state.action.t or 0
 local reach=sin(math.min(1,progress)*pi)
 local gait=state.gait or 0;local bob=state.bob or 0
 s.tongs.position=v(.20+sin(gait*.5)*math.abs(bob)*.7,-.28-bob-reach*.08,.43+reach*.22)
 s.tongs.rotation=Quaternion(13+reach*15,-12,-7)
 for i,jaw in ipairs(s.tongJaws)do jaw.rotation=Quaternion(0,(i==1 and -1 or 1)*(12-reach*10),0)end
end
return B
