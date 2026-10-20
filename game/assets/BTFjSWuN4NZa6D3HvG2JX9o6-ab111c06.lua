-- Art construction only; gameplay coordinates, inventory and collision rules
-- remain in App/State. All scenery is retained geometry, never a backdrop image.
local A={}
local sin,cos,pi=math.sin,math.cos,math.pi
local function v(x,y,z)return Vector3(x,y,z)end
local C={wood={.40,.23,.12},plank={.72,.49,.28},cream={.96,.89,.69},white={.91,.95,.89},
 blue={.10,.46,.62},navy={.065,.19,.27},red={.86,.31,.19},gold={.97,.71,.27},steel={.67,.76,.76},
 leaf={.16,.45,.24},lime={.42,.68,.25},green={.27,.58,.26},sand={.94,.81,.53}}
A.colors=C
local function schoolModel(s,wide)
 s.schoolModels=s.schoolModels or {}
 if s.schoolModels[wide]then return s.schoolModels[wide]end
 -- Identical silhouette vertices/normals/material, stored once per body width.
 -- StaticModel instances can share the buffers and the engine's instance batches.
 local m=s:NewMesh(s.sea,"SchoolSilhouettePrototype",false)
 local c={.06,.23,.29}
 local outline={{0,.66},{wide*.70,.36},{wide,.02},{wide*.65,-.32},
  {.07,-.55},{.30,-.83},{0,-.68},{-.30,-.83},{-.07,-.55},
  {-wide*.65,-.32},{-wide,.02},{-wide*.70,.36}}
 for i=1,#outline do local a,b=outline[i],outline[i%#outline+1]
  m:tri(v(0,0,0),v(a[1],0,a[2]),v(b[1],0,b[2]),c)
 end
 for _,side in ipairs({-1,1})do
  m:tri(v(side*wide*.55,0,.20),v(side*.47,0,-.20),v(side*wide*.55,0,-.18),c)
 end
 m:finish()
 local model=Model:new();assert(m.geometry:FillModel(model),"School silhouette model conversion failed")
 s.schoolModels[wide]=model;m.node:Dispose()
 return model
end
local function barrel(m,x,y,z,r)
 m:cone(x,y,z,r*.85,r, .22,C.wood,12)
 m:cone(x,y+.22,z,r,r*.86,r*1.55,C.plank,12)
 m:torus(x,y+.21,z,r+.015,.026,C.navy,nil,16)
 m:torus(x,y+r*1.52,z,r*.9,.024,C.navy,nil,16)
 for i=0,9 do local a=i*2*pi/10
  m:tube(v(x+cos(a)*r*.92,y+.25,z+sin(a)*r*.92),v(x+cos(a)*r*.85,y+r*1.7,z+sin(a)*r*.85),.008,.008,C.wood,4)
 end
end
function A.house(s,parent,x,y,z,size,name)
 local root=parent:CreateChild(name);root.position=v(x,y,z);root.scale=v(size,size,size)
 local m=s:NewMesh(root,"TimberPlasterTiles")
 m:box(0,.18,0,4.5,.36,3.9,{.62,.65,.55})
 m:box(0,1.47,0,4.2,2.6,3.6,C.cream)
 for i=0,11 do m:box(-2.0+i*.36,.22,-1.97,.30,.26,.09,{.72,.73,.62})end
 for _,side in ipairs({-1,1})do
  m:box(side*2.08,1.52,-1.84,.15,2.65,.15,C.wood)
  m:box(side*2.08,1.52,1.76,.15,2.65,.15,C.wood)
 end
 for _,front in ipairs({-1,1})do
  m:tri(v(-2.1,2.76,front*1.8),v(0,4.16,front*1.8),v(2.1,2.76,front*1.8),C.cream)
  m:beam(v(-2.15,2.74,front*1.85),v(2.15,2.74,front*1.85),.07,C.wood)
  m:beam(v(0,2.8,front*1.86),v(0,4.13,front*1.86),.065,C.wood)
 end
 -- Individual staggered tile courses and deep eaves read at a close zoom.
 for _,side in ipairs({-1,1})do
  m:quad(v(0,4.2,-2.15),v(0,4.2,2.15),v(side*2.55,2.72,2.15),v(side*2.55,2.72,-2.15),C.red)
  for row=0,5 do for col=0,11 do
   local u0=row/6;local u1=(row+1.10)/6
   local za=-2.15+col*.36+(row%2)*.08;local zb=math.min(2.23,za+.35)
   local shade=.89+((row*7+col*3)%9)*.016
   local c={.88*shade,.36*shade,.20*shade}
   m:quad(v(side*u0*2.55,4.23-u0*1.48,za),v(side*u0*2.55,4.23-u0*1.48,zb),
    v(side*u1*2.55,4.23-u1*1.48,zb),v(side*u1*2.55,4.23-u1*1.48,za),c)
  end end
  m:beam(v(side*2.55,2.72,-2.24),v(side*2.55,2.72,2.24),.075,C.wood)
 end
 for i=0,11 do m:ellipsoid(0,4.22,-2.07+i*.38,.13,.12,.22,{.94,.43,.24},8,4)end
 -- Panelled door, handle, framed blue glazing and painted shutters.
 m:box(0,1.23,-1.84,.91,2.12,.12,C.wood)
 for i=-1,1 do m:box(i*.265,1.25,-1.92,.24,1.96,.04,{.58,.34,.17})end
 m:ellipsoid(.27,1.2,-1.98,.055,.055,.04,C.gold,8,4)
 for _,sx in ipairs({-1,1})do
  local wx=sx*1.30
  m:box(wx,1.68,-1.86,.94,1.0,.14,C.wood)
  m:box(wx,1.69,-1.96,.76,.82,.025,{.19,.56,.64})
  m:box(wx,1.69,-1.99,.06,.83,.025,C.cream);m:box(wx,1.69,-1.99,.77,.055,.025,C.cream)
  m:box(wx-.53,1.68,-1.9,.17,1.03,.08,C.blue);m:box(wx+.53,1.68,-1.9,.17,1.03,.08,C.blue)
  m:box(wx,1.04,-2.02,1.03,.25,.35,C.red)
  for j=0,4 do
   m:ellipsoid(wx-.38+j*.19,1.28,-2.03,.16,.17,.16,j%2==0 and C.green or C.lime,8,4)
   m:ellipsoid(wx-.34+j*.18,1.41,-2.06,.08,.07,.08,j%2==0 and {.98,.77,.28} or {.98,.61,.48},8,4)
  end
 end
 m:box(2.15,1.7,.2,.14,.98,1.0,C.wood);m:box(2.23,1.7,.2,.025,.80,.82,C.blue)
 m:box(2.25,1.7,.2,.025,.80,.055,C.cream)
 for i=1,3 do m:box(0,.12*i,-2.12-i*.3,1.35,.15,.34,{.71,.67,.51})end
 m:box(1.15,3.8,.65,.58,1.42,.65,{.66,.58,.44});m:box(1.15,4.55,.65,.76,.16,.83,C.wood)
 barrel(m,-2.8,0,.8,.38)
 m:box(-2.8,.32,-.35,.77,.64,.75,C.plank)
 for i=0,2 do m:box(-3.2,.12+i*.22,-.75,.06,.1,.06,C.wood)end
 m:finish();return root
end
function A.tree(s,parent,x,y,z,seed,palm)
 local root=parent:CreateChild(palm and "CoastalPalm" or "BroadleafTree");root.position=v(x,y,z)
 local trunk=s:NewMesh(root,"CurvedTrunkBranches")
 local height=palm and 4.4 or 2.9;local lean=palm and .55 or .12
 for i=0,5 do
  local t=i/6;local u=(i+1)/6
  trunk:tube(v(lean*t*t,t*height,0),v(lean*u*u,u*height,0),.20-t*.09,.20-u*.09,C.wood,8)
  if palm then trunk:torus(lean*u*u,u*height,0,.20-u*.09+.012,.018,{.61,.43,.23},nil,10)end
 end
 if not palm then for i=0,2 do local a=i*2*pi/3+seed
  trunk:tube(v(0,1.5,0),v(cos(a)*.85,2.8,sin(a)*.85),.11,.045,C.wood,7)
 end end
 trunk:finish()
 local crown=root:CreateChild("WindCrown");crown.position=v(lean,height-.05,0)
 local leaves=s:NewMesh(crown,"LayeredLeaves")
 if palm then
  for i=0,7 do local a=i*2*pi/8+seed*.3;local dir=v(cos(a),0,sin(a));local cross=v(-sin(a),0,cos(a))
   local previous=v(0,.15,0)
   for j=0,6 do local t=j/7;local u=(j+1)/7
    local p=dir*(t*2.9)+v(0,sin(t*pi)*.65-t*t*.9,0)
    local q=dir*(u*2.9)+v(0,sin(u*pi)*.65-u*u*.9,0)
    local width=sin((t+.06)*pi)*.43;local nextWidth=sin(u*pi)*.43
    local c=(i+j)%3==0 and C.lime or C.green
    leaves:quad(p,q,q+cross*nextWidth-v(0,.09,0),p+cross*width-v(0,.09,0),c)
    leaves:quad(p-cross*width-v(0,.09,0),q-cross*nextWidth-v(0,.09,0),q,p,C.leaf)
    leaves:tube(previous,q,.016,.008,{.44,.61,.25},4);previous=q
   end
  end
  for i=0,2 do leaves:ellipsoid(cos(i*2)*.21,-.12,sin(i*2)*.21,.19,.23,.19,C.wood,8,5)end
 else
  local palette={C.green,C.lime,{.24,.57,.27},{.37,.66,.28},C.leaf}
  for i=0,5 do local a=i*2.399+seed*.7;local r=i==0 and 0 or 1.0
   leaves:ellipsoid(cos(a)*r,.1+sin(i*3.7)*.40,sin(a)*r,1.05+(i%2)*.2,1.18,1.05,palette[(i+seed)%#palette+1],12,7)
  end
  leaves:ellipsoid(-.15,1.02,.03,1.0,.85,.95,{.40,.68,.29},12,7)
 end
 leaves:finish();s.trees[#s.trees+1]={node=crown,seed=seed,owner=parent};return root
end
function A.boat(s,parent,name)
 local root=parent:CreateChild(name);local m=s:NewMesh(root,"PaintedClinkerHull")
 -- Curved bow, broad transom, three hull strakes and a recessed planked deck.
 local ring={}
 for i=0,31 do local a=i*2*pi/32;local z=cos(a)*2.2
  ring[#ring+1]={sin(a)*(z>0 and 1-z*.19 or .96),z< -1.65 and -1.65 or z}
 end
 for i=1,#ring do local j=i%#ring+1;local a,b=ring[i],ring[j]
  for row=0,2 do local t=row/3;local u=(row+1)/3
   local function p(q,k)return v(q[1]*(.61+.39*k),-.20+k*.86,q[2]*(.86+.14*k))end
   m:quad(p(a,t),p(b,t),p(b,u),p(a,u),row==2 and C.blue or { .10+row*.015,.32+row*.055,.43+row*.07})
  end
  m:tri(v(0,.39,0),v(a[1]*.91,.39,a[2]*.92),v(b[1]*.91,.39,b[2]*.92),C.plank)
  m:tube(v(a[1],.67,a[2]),v(b[1],.67,b[2]),.055,.055,C.cream,6)
  m:tube(v(a[1]*.96,.53,a[2]*.985),v(b[1]*.96,.53,b[2]*.985),.018,.018,C.gold,5)
 end
 for i=0,10 do local z=-1.48+i*.30;local width=z>1 and 1.55-(z-1)*.6 or 1.68
  m:box(0,.415,z,width,.035,.014,C.wood)
  for _,x in ipairs({-.61,.61})do if z<1.6 then m:ellipsoid(x,.437,z,.015,.008,.015,C.navy,6,3)end end
 end
 for _,z in ipairs({-.83,.65})do
  m:box(0,.61,z,1.62,.16,.38,C.cream)
  m:box(0,.70,z,1.48,.035,.31,{.82,.61,.37})
  for _,x in ipairs({-.65,.65})do m:box(x,.46,z,.09,.3,.2,C.wood)end
 end
 -- Empty helm; no driver, hands or body model.
 m:box(.5,.68,-.20,.45,.60,.43,C.cream);m:box(.5,1.0,-.20,.47,.10,.46,C.navy)
 m:torus(.5,1.14,-.20,.17,.024,C.wood,v(0,.4,1),16)
 m:box(-.42,.65,-.32,.53,.49,.61,C.blue);m:box(-.42,.92,-.32,.59,.10,.66,C.cream)
 m:box(-.42,.93,-.65,.18,.05,.025,C.steel)
 m:box(0,.58,-1.83,.49,.65,.30,C.navy);m:ellipsoid(0,.9,-1.84,.28,.21,.23,C.blue,12,6)
 m:tube(v(0,.4,-1.86),v(0,-.32,-1.92),.09,.07,C.steel,8)
 m:torus(-.92,.73,-.6,.28,.075,C.red,v(1,0,0),20)
 for i=0,2 do m:torus(-.44,.46,1.36,.19+i*.025,.026,C.cream,nil,20)end
 for _,side in ipairs({-1,1})do
  for _,z in ipairs({.9,1.55})do m:tube(v(side*.68,.66,z),v(side*.68,1.05,z),.025,.025,C.steel,6)end
  m:tube(v(side*.68,1.05,.9),v(side*.5,1.05,1.85),.025,.025,C.steel,6)
  m:ellipsoid(side*.77,.5,.28,.09,.26,.09,C.cream,8,5)
  m:tube(v(side*.87,.69,-1.02),v(side*.87,.72,-.86),.035,.035,C.steel,6)
 end
 m:finish();return root
end
-- The close fishing view stands on a raised bow deck. The hull continues down
-- to the waterline; lifting a normal dinghy would leave it floating in mid-air.
-- Helm/seats stay aft of the eye, outside this forward observation station.
function A.fishingBoat(s,parent,name,deckY)
 local root=parent:CreateChild(name);local m=s:NewMesh(root,"RaisedBowDeck")
 local ring={};local railY=deckY+.60
 for i=0,31 do local a=i*2*pi/32;local z=cos(a)*4.0
  ring[#ring+1]={sin(a)*(z>0 and 2.0-z*.28 or 1.85),math.max(-3.2,z)}
 end
 for i=1,#ring do local j=i%#ring+1;local a,b=ring[i],ring[j]
  local function p(q,y,k)return v(q[1]*k,y,q[2]*k)end
  m:quad(p(a,-.35,.70),p(b,-.35,.70),p(b,deckY-.22,1),p(a,deckY-.22,1),C.blue)
  m:quad(p(a,deckY-.22,1),p(b,deckY-.22,1),p(b,railY,1),p(a,railY,1),C.cream)
  -- Blue inner bulwark, broad timber cap and an unbroken deck behind the bow.
  m:quad(p(b,deckY,.91),p(a,deckY,.91),p(a,railY,.94),p(b,railY,.94),C.navy)
  m:quad(p(a,railY,1.025),p(b,railY,1.025),p(b,railY,.92),p(a,railY,.92),C.wood)
  m:tri(v(0,deckY,0),p(a,deckY,.92),p(b,deckY,.92),C.plank)
  m:tube(p(a,railY+.014,.96),p(b,railY+.014,.96),.035,.035,{.78,.55,.30},6)
 end
 -- Longitudinal plank seams stop at the hull outline rather than protruding.
 for i=-7,7 do local x=i*.20;local crossings={}
  for j,a in ipairs(ring)do local b=ring[j%#ring+1]
   if (a[1]*.92<=x and b[1]*.92>x)or(b[1]*.92<=x and a[1]*.92>x)then
    local k=(x/.92-a[1])/(b[1]-a[1])
    crossings[#crossings+1]=(a[2]+(b[2]-a[2])*k)*.92
   end
  end
  if #crossings==2 then
   local lo,hi=math.min(crossings[1],crossings[2]),math.max(crossings[1],crossings[2])
   m:box(x,deckY+.006,(lo+hi)*.5,.009,.012,hi-lo-.03,C.wood)
  end
 end
 -- Cleat feet sit on the solid timber cap at the stem.
 for _,x in ipairs({-.08,.08})do
  m:box(x,railY+.05,3.86,.05,.10,.10,C.steel)
 end
 m:tube(v(-.21,railY+.11,3.86),v(.21,railY+.11,3.86),.035,.035,C.steel,8)
 m:finish();return root
end
function A.fish(s,parent,name,tint,shadow,index)
 local root=parent:CreateChild(name)
 local variant=index or 1
 if shadow then
  local drawable=root:CreateComponent("StaticModel")
  drawable.model=schoolModel(s,variant%3==0 and .30 or .22)
  drawable.material=s.schoolMat or s.solid;drawable.castShadows=false
  return root
 end
 local m=s:NewMesh(root,"StreamlinedFish")
 ---@type number[][][]
 local palettes={{{.18,.59,.71},{.88,.93,.78},{.11,.34,.51}},
  {{.94,.63,.21},{1,.91,.56},{.78,.37,.13}},{{.67,.39,.63},{.95,.80,.70},{.37,.25,.47}}}
 local palette=palettes[(variant-1)%#palettes+1]
 local c=shadow and {.06,.23,.29} or tint or palette[1]
 local belly=shadow and c or palette[2];local fin=shadow and c or palette[3]
 local wide=variant%3==0 and .30 or .22;local tall=variant%3==0 and .30 or .22
 -- Longitudinal sections provide a pointed nose and a pinched tail stock.
 local sections={{-.65,.025},{-.43,.38},{-.18,.86},{.13,1},{.39,.74},{.59,.24},{.64,.035}}
 for row=1,#sections-1 do for i=0,11 do
  local a,b=i*2*pi/12,(i+1)*2*pi/12
  local l,r=sections[row],sections[row+1]
  local function p(sec,angle)return v(cos(angle)*wide*sec[2],sin(angle)*tall*sec[2],sec[1])end
  local function n(sec,angle)return v(cos(angle),sin(angle),sec[1]*.30):Normalized()end
  local shade=sin((a+b)*.5)>.15 and c or belly
  m:smoothTri(p(l,a),p(r,b),p(r,a),n(l,a),n(r,b),n(r,a),shade)
  m:smoothTri(p(l,a),p(l,b),p(r,b),n(l,a),n(l,b),n(r,b),shade)
 end end
 m:tri(v(0,tall*.6,.22),v(0,tall+.28,-.10),v(0,tall*.64,-.33),fin)
 for _,side in ipairs({-1,1})do
  m:tri(v(side*wide*.68,-.02,.18),v(side*.51,-.08,-.24),v(side*wide*.63,-.06,-.23),fin)
  if not shadow then
   m:ellipsoid(side*wide*.69,.075,.42,.047,.054,.061,C.cream,10,5)
   m:ellipsoid(side*(wide*.69+.035),.078,.43,.023,.033,.037,C.navy,8,5)
   m:ellipsoid(side*(wide*.69+.050),.094,.447,.009,.010,.012,C.white,6,3)
   -- Gill arcs and lateral marks follow the surface instead of floating labels.
   for j=0,4 do local zz=-.30+j*.13
    m:ellipsoid(side*wide*.95,.09,zz,.014,.075,.022,fin,6,4)
   end
   m:tube(v(side*wide*.84,-.01,.30),v(side*wide*.82,-.10,.25),.008,.008,fin,5)
  end
 end
 m:finish();m.geometry.castShadows=false
 local tail=root:CreateChild("AnimatedTail");tail.position=v(0,0,-.55)
 local t=s:NewMesh(tail,"ForkedTailFin")
 t:tri(v(0,0,.04),v(-.32,.025,-.39),v(-.13,.02,-.29),fin)
 t:tri(v(0,0,.04),v(-.13,.02,-.29),v(.13,.02,-.29),c)
 t:tri(v(0,0,.04),v(.13,.02,-.29),v(.32,.025,-.39),fin)
 t:finish();t.geometry.castShadows=false;s.fishTails[#s.fishTails+1]={node=tail,seed=#s.fishTails+1,owner=parent,index=variant}
 return root
end
function A.shark(s,parent)
 local root=parent:CreateChild("ReefShark");local m=s:NewMesh(root,"SharkSilhouette")
 local grey={.19,.34,.39};local dark={.13,.27,.33}
 m:ellipsoid(0,0,0,.31,.26,1.4,grey,16,8)
 m:ellipsoid(0,-.11,.30,.28,.12,1.03,{.57,.65,.60},14,6)
 m:tri(v(0,.15,.2),v(0,1.0,-.30),v(0,.15,-.66),dark)
 for _,side in ipairs({-1,1})do
  m:tri(v(side*.20,-.04,.40),v(side*1.03,-.12,-.51),v(side*.21,-.06,-.34),dark)
  m:ellipsoid(side*.215,.09,.98,.027,.030,.035,C.navy,8,4)
 end
 m:finish();m.geometry.castShadows=false
 local tail=root:CreateChild("SharkTail");tail.position=v(0,0,-1.1)
 local t=s:NewMesh(tail,"SharkTailFin")
 t:tri(v(0,0,.1),v(0,.72,-.65),v(0,.08,-.40),dark)
 t:tri(v(0,0,.1),v(0,-.34,-.5),v(0,.08,-.40),grey)
 t:finish();t.geometry.castShadows=false;s.fishTails[#s.fishTails+1]={node=tail,seed=#s.fishTails+1,owner=parent,index=0}
 return root
end
function A.coral(s,parent,x,y,z,seed)
 local m=s:NewMesh(parent,"ReefGarden"..seed,false)
 local pink={.85,.47,.43};local purple={.58,.43,.69}
 m:rock(x,y,z,.7,.42,.6,{.44,.61,.51},seed)
 if seed%3==0 then
  for i=0,4 do local a=i*2.399
   local p=v(x+cos(a)*.27,y+.13,z+sin(a)*.27);local q=p+v(cos(a)*.25,.55+i*.08,sin(a)*.25)
   m:tube(p,q,.055,.025,pink,7)
   m:tube(q-v(0,.22,0),q+v(.20,.12,.10),.032,.013,pink,6)
   m:ellipsoid(q.x,q.y,q.z,.05,.05,.05,{.98,.67,.52},6,4)
  end
 elseif seed%3==1 then
  for i=0,3 do m:ellipsoid(x+sin(i*3)*.3,y+.25+i*.09,z+cos(i*3)*.3,.40,.13,.38,purple,12,5)end
 else
  for i=0,6 do local a=i*2.399
   m:tube(v(x+cos(a)*.24,y,z+sin(a)*.24),v(x+cos(a)*.6,y+.6,z+sin(a)*.6),.035,.012,C.green,6)
  end
 end
 m:finish()
end
return A
