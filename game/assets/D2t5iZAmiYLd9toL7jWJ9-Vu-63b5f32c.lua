-- Static coastal art. Deterministic shapes, shared batches, no per-plant updates.
local A={}
local sin,cos,pi=math.sin,math.cos,math.pi
local function v(x,y,z)return Vector3(x,y,z)end
function A.Rock(m,x,y,z,rx,ry,rz,seed)
 local n=8;local rings={};local yaw=seed*2.399;local co,si=cos(yaw),sin(yaw)
 local profile={{-.10,.70},{.17,1},{.54,.91},{.84,.65},{.97,.26}}
 for j,row in ipairs(profile)do
  rings[j]={}
  for i=1,n do
   local a=i*2*pi/n+.045*sin(seed+i*2.1)
   local r=row[2]*(1+.15*sin(i*2.71+seed)+.065*sin(j*2.3+i*1.8+seed*.4))
   local xx=rx*(cos(a)*r+.17*row[1]*sin(seed))
   local zz=rz*(sin(a)*r+.12*row[1]*cos(seed*.7))
   rings[j][i]=v(x+xx*co-zz*si,y+ry*(row[1]+.055*sin(i*1.7+j*.8+seed)),z+xx*si+zz*co)
  end
 end
 ---@param a Vector3
 ---@param b Vector3
 ---@param c Vector3
 local function tri(a,b,c)
  local face=(b-a):CrossProduct(c-a):Normalized()
  local tint=.93+(seed%5)*.028
  for _,p in ipairs({a,b,c})do
   local round=v((p.x-x)/(rx*rx),.18/ry,(p.z-z)/(rz*rz)):Normalized()
   local normal=(face*.78+round*.22):Normalized()
   local height=math.max(0,math.min(1,(p.y-y)/ry))
   m:vertex(p,normal,{tint,tint*.985,tint*.95,height})
  end
  m.count=m.count+1
 end
 for j=1,#rings-1 do for i=1,n do local k=i%n+1
  local a,b,c,d=rings[j][i],rings[j+1][i],rings[j+1][k],rings[j][k]
  tri(a,b,c);tri(a,c,d)
 end end
 local top=v(x+rx*.08*sin(seed),y+ry*(1.03+.035*cos(seed)),z+rz*.07*cos(seed))
 for i=1,n do local k=i%n+1
  tri(top,rings[#rings][k],rings[#rings][i])
  tri(v(x,y-ry*.16,z),rings[1][i],rings[1][k])
 end
end
---@param root Vector3
---@param tip Vector3
local function leaf(m,root,tip,width,color)
 local delta=tip-root;local side=v(-delta.z,0,delta.x):Normalized()*width
 local mid=root+delta*.52+v(0,width*.3,0)
 m:tri(root,mid-side,tip,color);m:tri(root,tip,mid+side,color)
end
function A.Shrub(m,x,y,z,size,seed)
 -- Three overlapping crowns give bushes volume; six low leaf fans soften the
 -- outline. Only 84 opaque triangles per clump, with no alpha overdraw.
 for crown=1,3 do
  local a=crown*2.399+seed;local h=size*(.38+crown*.065)
  local color=crown==1 and {.28,.45,.24}or crown==2 and {.36,.54,.26}or {.44,.59,.27}
  -- Bury the lower pole. Above-ground pointed undersides look like floating
  -- diamonds; the extra latitude ring keeps a rounded, grounded silhouette.
  m:ellipsoid(x+cos(a)*size*.36,y+h*.38,z+sin(a)*size*.36,size*.58,h,size*.55,color,6,3)
 end
 for k=1,6 do
  local a=k*pi/3+seed;local co,si=cos(a),sin(a)
  local root=v(x+co*size*.44,y+size*.42,z+si*size*.44)
  local tip=v(x+co*size*.97,y+size*(.35+.13*sin(k+seed)),z+si*size*.97)
  leaf(m,root,tip,size*.17,k%2==0 and {.43,.59,.27}or {.33,.50,.24})
 end
end
function A.Fern(m,x,y,z,size,seed)
 local root=v(x,y+.015,z)
 for k=1,7 do
  local a=k*2*pi/7+seed;local length=size*(.75+.2*sin(k+seed))
  local tip=root+v(cos(a)*length,size*.45,sin(a)*length)
  for j=1,3 do
   local mid=root+(tip-root)*(j/4)+v(0,sin(j*pi/4)*size*.26,0)
   local side=v(-sin(a),.15,cos(a))*size*.19*(1-j*.15)
   m:tri(root+(tip-root)*((j-1)/4),mid-side,mid+v(cos(a)*size*.16,0,sin(a)*size*.16),{.32,.51,.22})
   m:tri(root+(tip-root)*((j-1)/4),mid+v(cos(a)*size*.16,0,sin(a)*size*.16),mid+side,{.42,.59,.25})
  end
 end
end
function A.Plants(m,world,zStart,zEnd,seed)
 for i=1,12 do
  local z=zStart+(i*.61803398875%1)*(zEnd-zStart)
  local d=22+(i*3.73+seed)%20
  -- Open pockets create a winding, walkable margin rather than a dense wall.
  local gap=math.abs(sin(z*.105+.5))<.22 and d<29
  if not gap then
   local x=world.Coast(z)+d
   A.Shrub(m,x,world.Height(x,z)-.03,z,.75+(i%4)*.24,i+seed)
   if i%2==0 then
    local xx,zz=x-1.0,z+.8
    A.Fern(m,xx,world.Height(xx,zz),zz,.7,i+seed)
   end
  end
 end
 for i=1,2 do
  local z=zStart+(i*.36+.1)*(zEnd-zStart);local x=world.Coast(z)+37+sin(seed+i)*2
  A.Shrub(m,x,world.Height(x,z)-.05,z,3.2+(seed%3)*.2,seed+i*7)
 end
end
return A
