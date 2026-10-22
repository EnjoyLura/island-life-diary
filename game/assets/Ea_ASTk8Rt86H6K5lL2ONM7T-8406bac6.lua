-- Lazy, retained woodland. Spatial batches, opaque leaves, zero shadow casters.
local Mesh=require("Game.Mesh")
local W=require("Game.ForestWorld")
local Plants=require("Game.ShoreArt")
local B={}
local sin,cos,pi=math.sin,math.cos,math.pi
local function v(x,y,z)return Vector3(x,y,z)end
local function mat(path)
 local m=Material:new();assert(m:SetSurfaceShader("Shaders/BLGL/"..path..".shader"));return m
end
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
 if t.kind=="mushroom"then mushroom(m,color,t.phase)
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
function B.Build(s)
 if s.forest then return end
 s.forest=s.scene:CreateChild("Moonwood");s.forestTargets={}
 s.forestGroundMat=mat("CrescentForestGround")
 s.forestGroundMat:SetSurfaceTexture("sand_art",assert(cache:GetResource("Texture2D","Textures/Crescent/SeabedSand.jpg")))
 s.forestLeavesMat=mat("CrescentForestLeaves")
 for chunk=1,8 do
  local z0=-20+(chunk-1)*12
  local ground=Mesh.new(s.forest,"WoodlandGround"..chunk,s.forestGroundMat)
  local trunks=s:NewMesh(s.forest,"WoodlandTrunks"..chunk,false)
  local leaves=Mesh.new(s.forest,"WoodlandCanopy"..chunk,s.forestLeavesMat)
  local floor=s:NewMesh(s.forest,"WoodlandUnderstory"..chunk,false)
  for z=z0,z0+10,2 do for x=-48,46,2 do
   local function p(xx,zz)return v(xx,W.Height(xx,zz),zz)end
   local a,b,c,d=p(x,z),p(x,z+2),p(x+2,z+2),p(x+2,z)
   local shade=1.02+.05*sin(x*.27+z*.18)
   -- Bake the crowns' ground shade at construction, instead of shadow maps.
   for _,tree in ipairs(W.trees)do
    local d=(x-tree.x-2.8)^2+(z-tree.z-1.1)^2
    if d<15 then shade=math.min(shade,.72+d*.019)end
   end
   ground:quad(a,b,c,d,{shade,shade,shade})
  end end
  for _,t in ipairs(W.trees)do if t.z>=z0 and t.z<z0+12 then
   local x,z,seed=t.x,t.z,t.seed;local y=W.Height(x,z);local h=5.1+seed%4*.7
   local segments,rows=z>24 and 6 or 7,z>24 and 3 or 4
   local lean=sin(seed*2.1)*.6;local bark={.34+seed%3*.025,.25,.15}
   trunks:tube(v(x,y-.06,z),v(x+lean,y+h,z+.25),.40,.16,bark,7)
   for k=1,3 do local a=k*2.1+seed
    trunks:tube(v(x,y+.30,z),v(x+cos(a)*.9,y+.02,z+sin(a)*.9),.18,.04,bark,5)
    local tip=v(x+lean+cos(a)*1.5,y+h-.3,z+sin(a)*1.5)
    trunks:tube(v(x+lean*.8,y+h-1.8,z),tip,.13,.055,bark,5)
    leaves:ellipsoid(tip.x,tip.y,tip.z,2.7,1.65,2.5,k==1 and {.27,.44,.19}or k==2 and {.37,.52,.22}or{.46,.60,.26},segments,rows)
   end
   leaves:ellipsoid(x+lean,y+h+1.0,z,2.5,1.6,2.6,{.40,.55,.23},segments,rows)
   for k=1,8 do local a=k*pi/4+seed;local root=v(x+lean+cos(a)*2,y+h+.6,z+sin(a)*2)
    local tip=root+v(cos(a)*1.3,-.15,sin(a)*1.3);local side=v(-sin(a)*.38,-.12,cos(a)*.38)
    leaves:tri(root,root+(tip-root)*.5-side,tip,{.39,.55,.22})
    leaves:tri(root,tip,root+(tip-root)*.5+side,{.46,.61,.26})
   end
  end end
  -- Keep the trail and pickup footprints open; denser foliage sits at its edges.
  for i=1,7 do
   local z=z0+(i*.618%1)*12;local side=i%2==0 and 1 or -1
   local x=W.Path(z)+side*(6+(i*2.37)%13)
   Plants.Shrub(floor,x,W.Height(x,z)-.02,z,.65+i%3*.22,i+chunk*11)
   if i%2==0 then Plants.Fern(floor,x-side*1.2,W.Height(x-side*1.2,z),z,.7,i+chunk)end
  end
  -- Amber leaf litter is geometry in the same batch, never per-leaf nodes.
  for i=1,32 do local x=-19+(i*3.71+chunk)%38;local z=z0+(i*1.37)%12;local y=W.Height(x,z)+.015
   floor:quad(v(x-.10,y,z),v(x,y+.015,z+.15),v(x+.10,y,z),v(x,y-.005,z-.10),i%2==0 and {.58,.42,.21}or{.55,.55,.25})
  end
  ground:finish();trunks:finish();leaves:finish();floor:finish()
 end
 local rocks=s:NewMesh(s.forest,"MossyWoodlandBoulders",false)
 for i=1,14 do local z=8+i*3.8;local x=W.Path(z)+(i%2==0 and 1 or -1)*(7.5+i%3*1.7);local y=W.Height(x,z)
  rocks:rock(x,y-.18,z,1.05,.7+i%3*.25,.8,{.40,.45,.32},i)
  Plants.Fern(rocks,x+.7,W.Height(x+.7,z),z+.6,.7,i)
 end
 -- A fallen log and three trail signs make the route recognisable.
 rocks:tube(v(8,W.Height(8,29)+.24,28),v(11,W.Height(11,29)+.24,30),.3,.24,{.37,.26,.15},9)
 for _,z in ipairs({-1,22,48})do local x=W.Path(z)-2.8;local y=W.Height(x,z)
  rocks:box(x,y+.65,z,.10,1.3,.10,{.43,.28,.15})
  rocks:box(x,y+1.14,z,.95,.33,.10,{.74,.58,.33})
  rocks:tri(v(x+.26,y+1.03,z-.06),v(x+.44,y+1.14,z-.06),v(x+.26,y+1.25,z-.06),{.94,.88,.65})
 end
 rocks:finish()
 local horizon=s:NewMesh(s.forest,"WoodlandDistantGround",false)
 -- Sample the centre of distant strips as well as their high outer edges;
 -- a single quad across both hills would become a floating roof over the sky.
 local xs={-240,-120,-80,-48,0,48,80,120,240}
 local zs={-240,-120,-60,-20,0,76,100,160,240}
 for j=1,#zs-1 do for i=1,#xs-1 do
  local x0,z0,x1,z1=xs[i],zs[j],xs[i+1],zs[j+1]
  if x0< -48 or x1>48 or z0< -20 or z1>76 then
   local function p(x,z)
    local xx,zz=math.max(-48,math.min(48,x)),math.max(-20,math.min(76,z))
    local edge=math.max(math.abs(x-xx),math.abs(z-zz))
    local fade=math.max(0,1-edge/100)
    return v(x,(W.Height(xx,zz)-.02)*fade+.05*(1-fade),z)
   end
   horizon:quad(p(x0,z0),p(x0,z1),p(x1,z1),p(x1,z0),{.32,.43,.22})
  end
 end end
 horizon:finish()
 for i,t in ipairs(s.app.forest.targets)do
  local m=s:NewMesh(s.forest,"ForestFind"..i,false);resource(m,t);m:finish()
  local x,z=W.ToWorld(t.x,t.y);m.node.position=v(x,W.Height(x,z)+.02,z)
  s.forestTargets[i]=m.node;m.node.enabled=not t.collected
 end
 local focus=s:NewMesh(s.forest,"ForestPickupFocus",false)
 focus:torus(0,.018,0,.49,.012,{.97,.81,.37},nil,16);focus:finish();s.forestFocus=focus.node
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
 for i,node in ipairs(s.forestTargets)do local enabled=not state.targets[i].collected
  if node.enabled~=enabled then node.enabled=enabled end
 end
 local target=app.nearTarget
 s.forestFocus.enabled=target~=nil
 if target then local x,z=W.ToWorld(target.x,target.y);s.forestFocus.position=v(x,W.Height(x,z)+.025,z)end
 local pick=math.max(0,(state.pickupUntil or 0)-t)/.32
 s.forestBasket.position=v(.30,-.42-pick*.05+(state.bob or 0)*.5,.80)
end
return B
