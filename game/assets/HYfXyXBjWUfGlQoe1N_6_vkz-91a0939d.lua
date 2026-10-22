-- Deterministic metre-based woodland; terrain, paths and finds share this layout.
local Beach=require("Game.ShoreWorld")
local F={unit=.04,eye=1.62,radius=.30,reach=4,speed=2.8,count=96,
 bounds={minX=-54,maxX=60,minZ=-12,maxZ=132},bridges={26,72,111}}
local sin,cos,sqrt=math.sin,math.cos,math.sqrt
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function smooth(a,b,x)local t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t)end
F.ToWorld=Beach.ToWorld;F.ToLogical=Beach.ToLogical
function F.Path(z)return 3.6*sin(z*.115)+1.8*sin(z*.043)end
function F.Stream(z)return 17+4.2*sin(z*.065)+2.0*sin(z*.143)end
function F.StreamWidth(z)return 2.1+.4*sin(z*.09)+3.8*(1-smooth(3,12,math.abs(z-101)))end
function F.WaterHeight(z)return .28+.0045*z end
function F.WestPath(z)return -26+4*sin(z*.061)end
function F.EastPath(z)return F.Stream(z)+9+1.5*sin(z*.11)end
local function ribbon(x,z,c,lo,hi)
 local dz=math.max(lo-z,0,z-hi);return sqrt((x-c)^2+dz*dz)
end
F.glades={{x=F.WestPath(41),z=41,r=6.8},{x=F.Path(72),z=72,r=6.2},{x=F.EastPath(101),z=101,r=6.5}}
function F.PathDistance(x,z)
 local d=ribbon(x,z,F.Path(z),-12,125)
 d=math.min(d,ribbon(x,z,F.WestPath(z),14,117),ribbon(x,z,F.EastPath(z),16,120),ribbon(x,z,F.Stream(z)-6,12,121))
 for _,zz in ipairs(F.bridges)do
  local dx=math.max(F.WestPath(zz)-x,0,x-F.EastPath(zz))
  d=math.min(d,sqrt(dx*dx+(z-zz)^2))
 end
 for _,g in ipairs(F.glades)do d=math.min(d,math.max(0,sqrt((x-g.x)^2+(z-g.z)^2)-g.r))end
 return d
end
function F.GroundHeight(x,z)
 local base=.68+.007*z+.24*sin(z*.086)+.16*sin(x*.145+z*.071)
 local rim=math.max(0,math.abs(x-3)-42)/16
 base=base+rim*rim*3.2+math.max(0,z-116)*.18+math.max(0,-z-4)*.13
 local d=math.abs(x-F.Stream(z));local width=F.StreamWidth(z)
 local bank=smooth(width-.5,width+2.1,d)
 return (F.WaterHeight(z)-.48)*(1-bank)+base*bank
end
function F.Height(x,z)
 local y=F.GroundHeight(x,z)
 for _,zz in ipairs(F.bridges)do
  local d=math.abs(x-F.Stream(zz));local half=F.StreamWidth(zz)
  if math.abs(z-zz)<1.3 and d<half+4.0 then
   local deck=F.WaterHeight(zz)+.65
   y=math.max(y,y+(deck-y)*(1-smooth(half+1.1,half+4,d)))
  end
 end
 return y
end
function F.Normal(x,z)
 local e=.18;local nx=(F.GroundHeight(x-e,z)-F.GroundHeight(x+e,z))/(2*e)
 local nz=(F.GroundHeight(x,z-e)-F.GroundHeight(x,z+e))/(2*e);local n=sqrt(nx*nx+1+nz*nz)
 return nx/n,1/n,nz/n
end
-- Preserve V37 keys/species/coordinates for the first 36 finds.
F.layout={}
for i=1,36 do
 local row=math.floor((i-1)/6);local col=(i-1)%6
 local z=3+row*9+sin(i*2.3)*1.4
 local x=3.6*sin(z*.115)+(col%2==0 and -1 or 1)*(2.1+math.floor(col/2)*2.4)
 if i==1 then x,z=.3,3.2 elseif i==2 then x,z=2.6,4.6 end
 local index=({1,2,3,1,4,5})[col+1]
 if i==18 then index=6 elseif i==30 then index=7 elseif i==36 then index=8 end
 F.layout[i]={x=x,z=z,index=index,habitat=col<2 and "path"or"roots",height=0}
end
F.trees={};F.shadeCells={}
local function cell(x,z)return math.floor(x/12)..":"..math.floor(z/12)end
for row=0,22 do for col=0,19 do
 local seed=row*20+col+1
 local z=-20+row*7.2+sin(seed*2.39)*1.5
 local x=-68+col*7.1+sin(seed*1.71)*1.35
 local clear=F.PathDistance(x,z)<3.4 or math.abs(x-F.Stream(z))<F.StreamWidth(z)+1.7
 for _,find in ipairs(F.layout)do if (x-find.x)^2+(z-find.z)^2<1.5^2 then clear=true;break end end
 if not clear then
  local t={x=x,z=z,r=.32+seed%4*.045,seed=seed,
   kind=seed%9==0 and "pine"or seed%7==0 and "birch"or"oak",
   detail=x> -51 and x<57 and z> -10 and z<130}
  F.trees[#F.trees+1]=t;local key=cell(x,z)
  F.shadeCells[key]=F.shadeCells[key]or{};table.insert(F.shadeCells[key],t)
 end
end end
local ancient={x=F.Path(76)-5.8,z=76,r=.72,seed=991,kind="oak",detail=true,ancient=true}
F.trees[#F.trees+1]=ancient
local ancientKey=cell(ancient.x,ancient.z)
F.shadeCells[ancientKey]=F.shadeCells[ancientKey]or{}
table.insert(F.shadeCells[ancientKey],ancient)
-- Smaller trees close to bends let the path pass beneath a canopy instead of
-- reading as a broad empty avenue. Keep every old pickup footprint clear.
for i,z in ipairs({11,19,34,44,56,85,97,118})do
 local x=F.Path(z)+(i%2==0 and -1 or 1)*4.3;local clear=false
 for _,p in ipairs(F.layout)do if (x-p.x)^2+(z-p.z)^2<1.5^2 then clear=true;break end end
 for _,t in ipairs(F.trees)do if (x-t.x)^2+(z-t.z)^2<2.2^2 then clear=true;break end end
 if not clear then
  local t={x=x,z=z,r=.34,seed=1001+i,kind=i%3==0 and"birch"or"oak",detail=true}
  F.trees[#F.trees+1]=t;local key=cell(x,z);F.shadeCells[key]=F.shadeCells[key]or{};table.insert(F.shadeCells[key],t)
 end
end
function F.Shade(x,z)
 local shade=.97+.035*sin(x*.5+z*.31)
 local cx,cz=math.floor(x/12),math.floor(z/12)
 for j=cz-1,cz+1 do for i=cx-1,cx+1 do for _,t in ipairs(F.shadeCells[i..":"..j]or{})do
  local d=(x-t.x-1.9)^2+(z-t.z-.7)^2
  if d<28 then shade=math.min(shade,.60+d*.013)end
 end end end
 return shade
end
-- Collision plan (top view): circular trunks, radius r + player .30 m.
-- Shallow streams stay wadeable; bridge rectangles provide raised walking.
-- Bounds lie behind rising banks and staggered trees. Exact centres and
-- touching circles resolve deterministically, without a rigid-body world.
function F.Resolve(x,z)
 local b=F.bounds;x,z=clamp(x,b.minX,b.maxX),clamp(z,b.minZ,b.maxZ)
 local cx,cz=math.floor(x/12),math.floor(z/12)
 for _=1,3 do for j=cz-1,cz+1 do for i=cx-1,cx+1 do for _,t in ipairs(F.shadeCells[i..":"..j]or{})do
  local dx,dz=x-t.x,z-t.z;local d=sqrt(dx*dx+dz*dz);local r=t.r+F.radius
  if d<r then if d<.0001 then dx,dz,d=1,0,1 end;x,z=t.x+dx/d*r,t.z+dz/d*r end
 end end end end
 return clamp(x,b.minX,b.maxX),clamp(z,b.minZ,b.maxZ)
end
-- Stream-edge flora sits above the water and outside bridge ramps.
for i=37,60 do
 local j=i-37;local z=-2+j*5.2;local side=j%2==0 and -1 or 1
 local x=F.Stream(z)+side*(F.StreamWidth(z)+1.8)
 F.layout[i]={x=x,z=z,index=({3,2,7,1,3,5})[j%6+1],habitat="stream",height=0}
end
local hosts={}
for _,t in ipairs(F.trees)do if t.detail and t.z>10 and t.z<120 then hosts[#hosts+1]=t end end
for i=61,78 do
 local t=hosts[1+((i-61)*13)%#hosts];local angle=t.seed*2.399
 local index=i%3==0 and 8 or i%3==1 and 5 or 4
 F.layout[i]={x=t.x+cos(angle)*(t.r+.38),z=t.z+sin(angle)*(t.r+.38),index=index,
  habitat="tree",height=1.05+(i%3)*.28,host=t,angle=angle}
end
for i=79,96 do
 local j=i-79;local z=18+j*6.2;local side=j%2==0 and -1 or 1
 local x=(side<0 and F.WestPath(z)or F.EastPath(z))+side*(2.4+(j%3)*.75)
 F.layout[i]={x=x,z=z,index=({1,2,3,6,4,7})[j%6+1],habitat=j%3==0 and "log"or"roots",height=0}
end
function F.TargetHeight(t)
 local x,z=F.ToWorld(t.x,t.y);return F.GroundHeight(x,z)+(t.height or 0)+.025
end
function F.New(catalog,trip)
 local s={x=900,y=1050,yaw=.10,pitch=.20,vx=0,vz=0,gait=0,bob=0,targets={}}
 for i,p in ipairs(F.layout)do
  local x,z=F.Resolve(p.x,p.z);local lx,ly=F.ToLogical(x,z);local species=catalog[p.index]
  s.targets[i]={key=tostring(i),x=lx,y=ly,id=species.id,species=species,kind=species.shape,
   height=p.height,habitat=p.habitat,angle=p.angle,host=p.host,
   collected=trip and trip.gathered and trip.gathered[tostring(i)]==true or false,phase=i}
 end
 if trip and trip.forestPose then local p=trip.forestPose;local x,z=F.Resolve(p.x,p.z)
  s.x,s.y=F.ToLogical(x,z);s.yaw=p.yaw;s.pitch=p.pitch
 end
 return s
end
function F.Snapshot(s)local x,z=F.ToWorld(s.x,s.y);return {x=x,z=z,yaw=s.yaw,pitch=s.pitch}end
function F.Update(s,move,look,dt,blocked)return Beach.Update(s,move,look,dt,blocked,F)end
function F.Camera(s,aspect)return Beach.Camera(s,aspect,F)end
function F.InReach(s,t)return Beach.InReach(s,t)end
function F.Pick(s,x,y,project)return Beach.Pick(s,x,y,project)end
function F.Nearest(s)return Beach.Nearest(s)end
function F.Area(s)
 local x,z=F.ToWorld(s.x,s.y)
 if math.abs(x-F.Stream(z))<10 then return z>87 and "苔石溪潭"or"潺溪水岸"end
 if x< -12 then return "蕨荫密林"end
 return z<21 and "入口林径"or z<60 and "浆果林地"or"古树空地"
end
function F.Remaining(s)local n=0;for _,t in ipairs(s.targets)do if not t.collected then n=n+1 end end;return n end
return F
