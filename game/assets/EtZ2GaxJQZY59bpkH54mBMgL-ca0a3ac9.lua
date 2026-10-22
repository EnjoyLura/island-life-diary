-- Metres, Y-up. One terrain function is shared by walking, art and pickups.
-- Like Tidewater's walker: camera-relative motion, eased velocity and a small
-- distance-driven head bob. No rigid-body world or invisible avatar mesh.
local W={unit=.04,eye=1.62,radius=.30,reach=4.0,speed=2.8}
local sin,cos,sqrt=math.sin,math.cos,math.sqrt
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
function W.Coast(z)return -9+2*sin(z*.055)+.8*sin(z*.17)end
function W.Height(x,z)
 local d=x-W.Coast(z)
 if d<0 then return .08+d*.14 end
 local inland=clamp((d-18)/20,0,1);inland=inland*inland*(3-2*inland)
 local dunes=inland*(.6+.4*sin(z*.10)+.25*sin(z*.21+1))
 return .08+math.min(d,24)*.095+math.max(0,d-15)*.025*(1+sin(z*.11))+dunes
end
function W.Normal(x,z)
 local e=.08
 local nx,nz=(W.Height(x-e,z)-W.Height(x+e,z))/(2*e),(W.Height(x,z-e)-W.Height(x,z+e))/(2*e)
 local n=sqrt(nx*nx+1+nz*nz);return nx/n,1/n,nz/n
end
function W.ToWorld(x,y)return (x-900)*W.unit,-(y-1050)*W.unit end
function W.ToLogical(x,z)return 900+x/W.unit,1050-z/W.unit end
-- The same circles locate the visible rock groups and prevent walking through them.
W.obstacles={}
for i=1,22 do
 local z=-61+(i-1)*5.8
 local d=i%3==0 and 3.0 or 19+(i%4)*2.3
 W.obstacles[i]={x=W.Coast(z)+d,z=z,r=.65+(i%3)*.24,seed=i}
end
W.palms={}
for i=1,13 do
 local z=-52+math.floor((i-1)/3)*25+((i-1)%3)*3.7
 W.palms[i]={x=W.Coast(z)+26+(i%3)*2.8,z=z,r=.22,seed=i}
end
function W.Resolve(x,z)
 z=clamp(z,-61,61);x=clamp(x,W.Coast(z)-2.3,W.Coast(z)+34)
 for _=1,2 do for _,group in ipairs({W.obstacles,W.palms})do for _,o in ipairs(group)do
  local dx,dz=x-o.x,z-o.z;local d=sqrt(dx*dx+dz*dz);local r=o.r+W.radius
  if d<r then
   if d<.0001 then dx,dz,d=1,0,1 end
   x=o.x+dx/d*r;z=o.z+dz/d*r
  end
 end end end
 z=clamp(z,-61,61);x=clamp(x,W.Coast(z)-2.3,W.Coast(z)+34)
 return x,z
end
function W.New(catalog)
 local s={x=900,y=1050,yaw=-.48,pitch=.30,vx=0,vz=0,gait=0,bob=0,targets={}}
 local kinds={"crab","hole","mound","shell","mound"}
 for i=1,30 do
  local k=(i-1)%5+1;local z=-47+math.floor((i-1)/5)*18+sin(i*2.3)*2
  local x=W.Coast(z)+2.2+(i-1)%5*3.8
  x,z=W.Resolve(x,z)
  local lx,ly=W.ToLogical(x,z)
  s.targets[i]={x=lx,y=ly,id=catalog[k].id,species=catalog[k],kind=kinds[k],collected=false,phase=i}
 end
 -- A clearly visible first crab, two short steps ahead of the starting point.
 s.targets[1].x,s.targets[1].y=W.ToLogical(-1.3,2.4)
 return s
end
local function stick(x,y)
 local d=sqrt(x*x+y*y)
 if d<=.10 then return 0,0 end
 local k=math.min(1,(d-.10)/.90)/d;return x*k,y*k
end
function W.Update(s,move,look,dt,blocked,world)
 local W=world or W
 dt=clamp(dt,0,.05)
 local lx,ly=stick(look.dx or 0,look.dy or 0)
 s.yaw=((s.yaw or 0)+lx*1.85*dt+math.pi)%(math.pi*2)-math.pi
 s.pitch=clamp((s.pitch or .30)+ly*1.25*dt,-1.05,1.34)
 local mx,my=stick(move.dx or 0,move.dy or 0)
 if blocked then mx,my=0,0 end
 local yaw=s.yaw;local x,z=W.ToWorld(s.x,s.y)
 local wade=clamp(-W.Height(x,z)/.5,0,1)
 local speed=W.speed*(1-wade*.35)
 local vx=(mx*cos(yaw)-my*sin(yaw))*speed
 local vz=(-mx*sin(yaw)-my*cos(yaw))*speed
 local ease=1-math.exp(-14*dt)
 s.vx=(s.vx or 0)+(vx-(s.vx or 0))*ease;s.vz=(s.vz or 0)+(vz-(s.vz or 0))*ease
 if blocked then s.vx,s.vz=0,0 end
 local xx,zz=W.Resolve(x+s.vx*dt,z+s.vz*dt)
 local moved=sqrt((xx-x)^2+(zz-z)^2)
 s.x,s.y=W.ToLogical(xx,zz);s.gait=(s.gait or 0)+moved*8
 local bob=sin(s.gait)*.018*math.min(1,sqrt(s.vx*s.vx+s.vz*s.vz)/W.speed)
 s.bob=(s.bob or 0)+(bob-(s.bob or 0))*ease
end
function W.Camera(s,aspect,world)
 local W=world or W
 local x,z=W.ToWorld(s.x or 900,s.y or 1050)
 local yaw,pitch=s.yaw or -.48,s.pitch or .30
 -- Keep a useful horizontal FOV on narrow phones without distorting the view.
 local fov=2*math.atan(math.tan(52*math.pi/360)/math.min(1,math.max(.42,aspect)))*180/math.pi
 return x,W.Height(x,z)+W.eye+(s.bob or 0),z,sin(yaw)*cos(pitch),-sin(pitch),cos(yaw)*cos(pitch),math.min(84,fov)
end
-- A broad forward half-plane; pitch/reticle alignment never gates a pickup.
function W.InReach(s,t)
 if not t or t.collected then return false end
 local dx,dy=t.x-s.x,t.y-s.y;local d2=dx*dx+dy*dy
 return d2<=(W.reach/W.unit)^2 and (d2<1 or dx*sin(s.yaw or 0)-dy*cos(s.yaw or 0)>=0)
end
-- Projection returns the visible model's padded screen rectangle. Resolve the
-- clicked creature, not the nearest creature or the one under the crosshair.
function W.Pick(s,x,y,project)
 local best,score=nil,math.huge
 for i,t in ipairs(s.targets)do if W.InReach(s,t)then
  local l,top,r,bottom=project(i,t)
  if l and x>=l and x<=r and y>=top and y<=bottom then
   local d=((x-(l+r)*.5)/math.max(1,r-l))^2+((y-(top+bottom)*.5)/math.max(1,bottom-top))^2
   if d<score then best,score=t,d end
  end
 end end
 return best
end
function W.Nearest(s)
 local best,range=nil,W.reach/W.unit
 for _,t in ipairs(s.targets)do if W.InReach(s,t)then
  local dx,dy=t.x-s.x,t.y-s.y;local d=sqrt(dx*dx+dy*dy)
  if d<=range then best,range=t,d end
 end end
 return best
end
return W
