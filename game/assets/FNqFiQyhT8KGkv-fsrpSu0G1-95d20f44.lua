-- Bounded, engine-free encounter simulation. Each retained slot swims through a
-- new world-space route, leaves into depth/distance, rests, then makes a new pass.
-- The controller and renderer read the same actor identities and positions.
local Art=require("Game.FishArt")
local F={capacity=15,schoolCount=14,coastCount=9}
local sin,cos,pi=math.sin,math.cos,math.pi
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function smooth(x)x=clamp(x,0,1);return x*x*(3-2*x)end
local function mix(a,b,k)return a+(b-a)*k end
local function random(a,lo,hi)
 a.seed=(a.seed*48271)%2147483647
 return lo+(hi-lo)*a.seed/2147483647
end
local function point(x,y,z)return {x=x,y=y,z=z}end
local function direction(a,x,y,z)
 local n=math.sqrt(x*x+y*y+z*z)
 if n>1e-6 then a.dx,a.dy,a.dz=x/n,y/n,z/n end
end
local function route(a,now,escape)
 local side=random(a,0,1)<.5 and -1 or 1
 local z=random(a,-7,36);local deep=random(a,0,1)<.45
 local x,y,zz=a.x,a.y,a.z
 a.route=(a.route or 0)+1;a.start=now;a.duration=random(a,32,48)
 a.p0=point(side*random(a,30,44),deep and -random(a,8,12)or-random(a,2,4),z)
 a.p1=point(side*random(a,3,12),-random(a,1.5,3.8),random(a,-5,24))
 a.p2=point(-side*random(a,5,20),-random(a,1.6,4.2),random(a,8,43))
 a.p3=point(-side*random(a,36,52),deep and -random(a,9,14)or-random(a,2,5),random(a,22,60))
 -- Most passes cross the useful casting area; the others range farther
 -- offshore. A larger world should not push every visible fish into the fog.
 if a.slot%3~=0 then
  a.p0.z=random(a,-6,14);a.p1.z=random(a,0,14);a.p2.z=random(a,8,26)
  a.p1.x=side*random(a,2,6);a.p2.x=-side*random(a,3,8)
 end
 if random(a,0,1)<.45 then a.p3=point(random(a,-24,24),-random(a,12,16),random(a,38,68))end
 if escape then
  a.p0=point(x,y,zz);a.p1=point(x+a.dx*3,y-.9,zz+a.dz*3)
  a.p2=point(x+a.dx*7,-8,zz+a.dz*8);a.p3=point(x+a.dx*12,-15,zz+a.dz*15)
  a.duration=random(a,5,8)
 end
 a.active=true;a.control=nil;a.gape=0;a.roll=0
end
local function free(a,now)
 if now<a.start then a.active=false;return end
 local u=(now-a.start)/a.duration
 if u>=1 then
  route(a,now+random(a,4,12));a.active=false;return
 end
 local v=1-u;local p,q,r,s=a.p0,a.p1,a.p2,a.p3
 a.x=v*v*v*p.x+3*v*v*u*q.x+3*v*u*u*r.x+u*u*u*s.x
 a.y=v*v*v*p.y+3*v*v*u*q.y+3*v*u*u*r.y+u*u*u*s.y
 a.z=v*v*v*p.z+3*v*v*u*q.z+3*v*u*u*r.z+u*u*u*s.z
 direction(a,3*v*v*(q.x-p.x)+6*v*u*(r.x-q.x)+3*u*u*(s.x-r.x),
  3*v*v*(q.y-p.y)+6*v*u*(r.y-q.y)+3*u*u*(s.y-r.y),
  3*v*v*(q.z-p.z)+6*v*u*(r.z-q.z)+3*u*u*(s.z-r.z))
 a.active=true;a.gape=0;a.roll=sin(now*1.4+a.slot)*2
end
function F.New(population,now,seed)
 local actors={}
 for i,species in ipairs(population)do
  local a={slot=i,species=species,seed=((seed or 1)+i*7919)%2147483646+1,
   x=0,y=-14,z=25,dx=0,dy=0,dz=1,beat=0}
  route(a,now)
  if i<=math.min(5,#population)then a.start=now-a.duration*random(a,.40,.60)
  else a.start=now+(i-5)*random(a,.9,1.8)end
  free(a,now);actors[#actors+1]=a
 end
 return actors
end
function F.Mouth(a)
 local n=Art.Nose(a.species)
 return a.x+a.dx*n,a.y+a.dy*n,a.z+a.dz*n
end
function F.Attract(f,a,bait,now)
 f.target=a;f.species=a.species;f.bait=bait;f.waited=0;f.bite=0
 a.control="reserved";a.gape=0
 local dx,dy,dz=bait.x-a.x,bait.y-a.y,bait.z-a.z
 a.approach=clamp(math.sqrt(dx*dx+dy*dy+dz*dz)/1.7,.85,4)
 a.inspect=random(a,1.1,1.6)
 -- A late natural encounter also completes its inspection by the 30 s limit.
 a.approach=math.min(a.approach,math.max(.85,30-(f.noBiteElapsed or 0)-a.inspect))
 f.waitFor=a.approach+a.inspect
 a.beat=now*6.2+a.slot
end
-- Bring an actual fish up from depth, with a retained slot and mouth animation.
-- Spare slots are filled first; at capacity reuse an unseen fish, never remove
-- a visible swimmer just to make the guarantee. No mesh creation per frame.
function F.Arrive(f,bait,species,now,seed)
 if f.target then return end
 local used={};local hidden,nearest,best=nil,nil,math.huge
 for _,a in ipairs(f.actors)do
  used[a.slot]=true
  if not a.active or a.y< -6.5 then hidden=hidden or a end
  local d=(a.x-bait.x)^2+(a.z-bait.z)^2
  if d<best then nearest,best=a,d end
 end
 local slot
 for i=1,F.capacity do if not used[i]then slot=i;break end end
 local added=slot~=nil
 local a=slot and {slot=slot,species=species,seed=(seed or 1)%2147483646+1,beat=now*6.2}or hidden or nearest
 if not a then return end
 if added or a==hidden then
  local angle=random(a,0,2*pi);local r=random(a,1.7,3.2)
  a.x,a.y,a.z=bait.x+cos(angle)*r,bait.y-6.8,bait.z+sin(angle)*r
  direction(a,bait.x-a.x,bait.y-a.y,bait.z-a.z)
  a.active=true;a.roll=0
 end
 if added then f.actors[#f.actors+1]=a;f.population[#f.population+1]=a.species end
 F.Attract(f,a,bait,now)
 a.approach=2.6;a.inspect=1.4;f.waitFor=4
 return a,added
end
function F.Escape(a,now)route(a,now,true)end
function F.Cancel(f,now)
 if f.target then F.Escape(f.target,now)end
 f.target=nil;f.bite=0
end
function F.Update(f,now,dt)
 f.bite=0
 local target=f.target;local stage=f.stage
 if target and stage~="casting"and stage~="waiting"and stage~="hooked"then
  F.Escape(target,now);f.target=nil;target=nil
 end
 for _,a in ipairs(f.actors or {})do
  if a~=target then free(a,now)
  elseif stage=="casting"then
   a.x=a.x+a.dx*dt*.65;a.y=a.y+a.dy*dt*.65;a.z=a.z+a.dz*dt*.65;a.active=true
  elseif stage=="waiting"then
   local bait=f.bait
   if a.control~="approach"then
    a.control="approach";a.from=point(a.x,a.y,a.z)
    local dx,dz=bait.x-a.x,bait.z-a.z;local n=math.sqrt(dx*dx+dz*dz)
    a.hx,a.hz=n>1e-5 and dx/n or 0,n>1e-5 and dz/n or 1
    a.oldx,a.oldy,a.oldz=a.dx,a.dy,a.dz
   end
   local u=smooth((f.waited or 0)/a.approach);local n=Art.Nose(a.species)
   local q=math.max(0,(f.waited or 0)-a.approach)
   a.gape=q>0 and math.max(0,sin(q*pi*4.5))^3 or 0
   local lunge=a.gape*.16;local bx,bz=bait.x-a.hx*(n-lunge),bait.z-a.hz*(n-lunge)
   local by=bait.y-.04-sin(q*5)*.045
   a.x=mix(a.from.x,bx,u)+a.hz*sin(u*pi)*.28
   a.y=mix(a.from.y,by,u);a.z=mix(a.from.z,bz,u)-a.hx*sin(u*pi)*.28
   local turn=smooth((f.waited or 0)/.4)
   direction(a,mix(a.oldx,a.hx,turn),mix(a.oldy,0,turn),mix(a.oldz,a.hz,turn))
   a.active=true;a.roll=sin(q*6)*3;f.bite=a.gape
  elseif stage=="hooked"then
   if a.control~="fight"then
    a.control="fight";a.from=point(a.x,a.y,a.z);a.fightTime=now
   end
   local land=f.landPoint or point(.8,5.1,-8.5)
   local progress=clamp(f.progress or 0,0,1);local k=smooth(progress/.88)
   local t=now-a.fightTime;local run=(1-k)*(.45+(f.power or .5)*.65)
   local x=mix(a.from.x,land.x,k)+sin(t*4.7)*run
   local z=mix(a.from.z,land.z,k)+sin(t*3.8)*run*.75
   local y=mix(a.from.y,-.35,k)-math.abs(sin(t*4.1))*(1-k)*.50
   y=mix(y,land.y,smooth((progress-.84)/.16))
   direction(a,x-a.x,y-a.y,z-a.z)
   a.x,a.y,a.z=x,y,z;a.active=true;a.gape=.65
   a.roll=sin(t*8)*(15+18*(f.power or .5))*(1-smooth((progress-.88)/.12))
  end
  a.beat=(a.beat or 0)+dt*(a==target and (stage=="hooked"and 19 or 10)or 6.2)
 end
end
function F.Take(f)
 local a=f.target;if not a then return end
 for i,actor in ipairs(f.actors or {})do if actor==a then
  table.remove(f.actors,i);table.remove(f.population,i)
  f.target=nil;f.bite=0;a.active=false;a.control=nil;return a
 end end
end
function F.Return(f,a,now)
 if not a then return end
 a.y=-.8;a.dy=-.15
 F.Escape(a,now);f.actors[#f.actors+1]=a;f.population[#f.population+1]=a.species
end
return F
