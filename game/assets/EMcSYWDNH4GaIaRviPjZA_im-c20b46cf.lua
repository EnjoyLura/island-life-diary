-- Deterministic woodland layout and metre-based walker; no engine or RNG.
local Beach=require("Game.ShoreWorld")
local F={unit=.04,eye=1.62,radius=.30,reach=4,speed=2.8,count=36}
local sin,cos,sqrt=math.sin,math.cos,math.sqrt
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
F.ToWorld=Beach.ToWorld;F.ToLogical=Beach.ToLogical
function F.Path(z)return 3.6*sin(z*.115) end
function F.Height(x,z)
 return .4+.013*z+.22*sin(z*.12)+.13*sin(x*.19+z*.06)+math.max(0,math.abs(x)-14)*.12
end
F.trees={}
for row=0,9 do for side=-1,1,2 do for col=1,3 do
 local z=-12+row*8.7+sin(row*4.3+col)*1.8
 local x=F.Path(z)+side*(5+col*5.2+sin(row+col)*1.5)
 F.trees[#F.trees+1]={x=x,z=z,r=.40,seed=#F.trees+1}
end end end
function F.Resolve(x,z)
 x,z=clamp(x,-23,23),clamp(z,-6,64)
 for _=1,2 do for _,t in ipairs(F.trees)do
  local dx,dz=x-t.x,z-t.z;local d=sqrt(dx*dx+dz*dz);local r=t.r+F.radius
  if d<r then if d<.0001 then dx,dz,d=1,0,1 end;x,z=t.x+dx/d*r,t.z+dz/d*r end
 end end
 return clamp(x,-23,23),clamp(z,-6,64)
end
function F.New(catalog,trip)
 local s={x=900,y=1050,yaw=.10,pitch=.20,vx=0,vz=0,gait=0,bob=0,targets={}}
 for i=1,F.count do
  local row=math.floor((i-1)/6);local col=(i-1)%6
  local z=3+row*9+sin(i*2.3)*1.4
  local x=F.Path(z)+(col%2==0 and -1 or 1)*(2.1+math.floor(col/2)*2.4)
  if i==1 then x,z=.3,3.2 end
  if i==2 then x,z=2.6,4.6 end
  x,z=F.Resolve(x,z);local lx,ly=F.ToLogical(x,z)
  -- Common finds near the trail; each glade contains a rarer discovery.
  local index=({1,2,3,1,4,5})[col+1]
  if i==18 then index=6 elseif i==30 then index=7 elseif i==36 then index=8 end
  local species=catalog[index]
  s.targets[i]={key=tostring(i),x=lx,y=ly,id=species.id,species=species,kind=species.shape,
   collected=trip and trip.gathered and trip.gathered[tostring(i)]==true or false,phase=i}
 end
 if trip and trip.forestPose then
  local p=trip.forestPose;local x,z=F.Resolve(p.x,p.z)
  s.x,s.y=F.ToLogical(x,z);s.yaw=p.yaw;s.pitch=p.pitch
 end
 return s
end
function F.Snapshot(s)
 local x,z=F.ToWorld(s.x,s.y);return {x=x,z=z,yaw=s.yaw,pitch=s.pitch}
end
-- Same dead zones, acceleration, camera FOV and touch-picking as the beach.
function F.Update(s,move,look,dt,blocked)return Beach.Update(s,move,look,dt,blocked,F)end
function F.Camera(s,aspect)return Beach.Camera(s,aspect,F)end
function F.InReach(s,t)return Beach.InReach(s,t)end
function F.Pick(s,x,y,project)return Beach.Pick(s,x,y,project)end
function F.Nearest(s)return Beach.Nearest(s)end
function F.Area(s)
 local _,z=F.ToWorld(s.x,s.y)
 return z<17 and "入口林径"or z<37 and "浆果林地"or "苔石空地"
end
function F.Remaining(s)
 local n=0;for _,t in ipairs(s.targets)do if not t.collected then n=n+1 end end;return n
end
return F
