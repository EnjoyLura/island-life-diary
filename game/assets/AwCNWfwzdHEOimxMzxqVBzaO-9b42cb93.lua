-- Woodland art built once into spatial batches. No per-leaf nodes, alpha
-- cards, shadow maps, or per-frame CPU mesh deformation.
local W=require("Game.ForestWorld")
local Plants=require("Game.ShoreArt")
local A={}
local sin,cos,pi=math.sin,math.cos,math.pi
local function v(x,y,z)return Vector3(x,y,z)end
local function tint(c,k)return {c[1]*k,c[2]*k,c[3]*k}end
local function smooth(a,b,x)local t=math.max(0,math.min(1,(x-a)/(b-a)));return t*t*(3-2*t)end
-- Open-ended tapered limbs save the invisible cap triangles at branch joins.
---@param a Vector3
---@param b Vector3
function A.Limb(m,a,b,r0,r1,color,n)
 n=n or 7;local delta=b-a;local along=delta:Normalized()
 local side=along:CrossProduct(math.abs(along.y)>.9 and Vector3.RIGHT or Vector3.UP):Normalized()
 local up=along:CrossProduct(side):Normalized()
 for i=0,n-1 do
  local a0,a1=i*2*pi/n,(i+1)*2*pi/n
  local d0=side*cos(a0)+up*sin(a0);local d1=side*cos(a1)+up*sin(a1)
  local n0=(d0+along*((r0-r1)/delta.length)):Normalized()
  local n1=(d1+along*((r0-r1)/delta.length)):Normalized()
  m:smoothTri(a+d0*r0,a+d1*r0,b+d1*r1,n0,n1,n1,color)
  m:smoothTri(a+d0*r0,b+d1*r1,b+d0*r1,n0,n1,n0,color)
 end
end
---@param root Vector3
---@param tip Vector3
local function leaf(m,root,tip,width,color)
 local d=tip-root;local side=v(-d.z,0,d.x):Normalized()*width
 local mid=root+d*.49+v(0,width*.33,0)
 m:tri(root,mid-side,tip,tint(color,.90));m:tri(root,tip,mid+side,color)
end
-- Irregular, smoothly lit lobes with a lighter upper surface and leaf tips
-- along the silhouette, replacing the flat regular green polyhedra.
function A.Crown(m,x,y,z,rx,ry,rz,seed,detailed,color)
 local n,rows=detailed and 8 or 6,detailed and 4 or 3
 local function sample(j,i)
  local phi,angle=j*pi/rows,i*2*pi/n
  local sx,sy,sz=sin(phi)*cos(angle),cos(phi),sin(phi)*sin(angle)
  local ripple=1+.11*sin(i*2.7+seed)+.065*sin(j*3.1+i+seed*.7)
  local p=v(x+sx*rx*ripple,y+sy*ry*(1+.06*sin(i+seed)),z+sz*rz*ripple)
  local normal=v(sx/rx,sy/ry,sz/rz):Normalized()
  return p,normal,tint(color,.76+.23*(sy*.5+.5)+.06*sin(i*1.7+seed))
 end
 local function tri(a,b,c,na,nb,nc,ca,cb,cc)
  m:vertex(a,na,ca);m:vertex(b,nb,cb);m:vertex(c,nc,cc);m.count=m.count+1
 end
 for j=0,rows-1 do for i=0,n-1 do
  local a,na,ca=sample(j,i);local b,nb,cb=sample(j+1,i)
  local c,nc,cc=sample(j+1,i+1);local d,nd,cd=sample(j,i+1)
  if j>0 then tri(a,d,c,na,nd,nc,ca,cd,cc)end
  if j<rows-1 then tri(a,c,b,na,nc,nb,ca,cc,cb)end
 end end
 if detailed then for i=1,6 do
  local angle=i*2*pi/6+seed;local co,si=cos(angle),sin(angle)
  local root=v(x+co*rx*.88,y+sin(i+seed)*ry*.20,z+si*rz*.88)
  leaf(m,root,root+v(co*rx*.30,-.09,si*rz*.30),.23,color)
 end end
end
function A.Tree(trunks,leaves,t)
 local x,z,seed=t.x,t.z,t.seed;local y=W.GroundHeight(x,z)
 local scale=t.ancient and 1.45 or 1;local h=(6.7+seed%6*.44)*scale
 local lean=sin(seed*2.1)*.55;local bark=t.kind=="birch"and{.67,.65,.53}or{.37+seed%3*.018,.275,.17}
 local p0=v(x,y-.12,z);local p1=v(x+lean*.25,y+h*.30,z+.08)
 local p2=v(x+lean*.70,y+h*.61,z+.17);local p3=v(x+lean,y+h*.88,z+.28)
 local r=t.r*scale
 A.Limb(trunks,p0,p1,r*1.30,r*.76,bark,8)
 A.Limb(trunks,p1,p2,r*.76,r*.51,bark,7)
 A.Limb(trunks,p2,p3,r*.51,.065*scale,bark,6)
 if t.detail then
  for j=1,5 do local angle=j*2*pi/5+seed
   local rx,rz=x+cos(angle)*r*3,z+sin(angle)*r*3
   A.Limb(trunks,v(x,y+.45,z),v(rx,W.GroundHeight(rx,rz)+.025,rz),r*.48,.028,bark,5)
  end
 end
 if t.kind=="pine"then
  for j=1,4 do
   local size=(3.2-j*.43)*scale
   A.Crown(leaves,x+lean*j*.2,y+h*(.38+j*.115),z,size,1.45*scale,size,seed+j,t.detail,{.23+j*.025,.39+j*.025,.22})
  end
 else
  local color=t.kind=="birch"and{.43,.59,.25}or{.32+seed%3*.025,.49+seed%4*.018,.22}
  for j=1,3 do
   local angle=j*2.1+seed;local co,si=cos(angle),sin(angle)
   local tip=v(x+lean+co*1.8*scale,y+h*(.76+j*.035),z+si*1.8*scale)
   A.Limb(trunks,p2,tip,r*.40,.055*scale,bark,5)
   if t.detail then
    A.Limb(trunks,tip,tip+v(co*.85,.45,si*.85),.06,.018,bark,4)
   end
   A.Crown(leaves,tip.x,tip.y+.4,tip.z,2.25*scale,1.65*scale,2.15*scale,seed+j,t.detail,tint(color,.93+j*.035))
  end
  A.Crown(leaves,p3.x,y+h+1.0*scale,p3.z,2.45*scale,1.9*scale,2.35*scale,seed+5,t.detail,tint(color,1.08))
 end
 -- Moss at the roots, knots and a few climbing leaves stay in the trunk batch.
 if t.detail then
  for j=1,3 do local angle=seed+j*1.7
   local xx,zz=x+cos(angle)*r*.95,z+sin(angle)*r*.95
   trunks:ellipsoid(xx,y+.15,zz,r*.55,.22,r*.50,{.27,.38,.19},5,2)
  end
  if seed%4==0 then for j=1,5 do
   local yy=.45+j*.25;local root=v(x+r*.95,y+yy,z)
   leaf(leaves,root,root+v(.32,.14,.13*sin(j)),.12,{.38,.54,.23})
  end end
 end
end
function A.Ground(m,x0,z0)
 local samples={}
 local function sample(x,z)
  local key=x..":"..z
  if samples[key]then return samples[key]end
  local y=W.GroundHeight(x,z)
  local nx,ny,nz=W.Normal(x,z);local path=1-smooth(.65,2.8,W.PathDistance(x,z))
  local shade=W.Shade(x,z);local bank=1-smooth(W.StreamWidth(z),W.StreamWidth(z)+3.8,math.abs(x-W.Stream(z)))
  local grass={.30,.425,.205};local earth={.60,.49,.31}
  local c={}
  for k=1,3 do c[k]=(grass[k]*(1-path)+earth[k]*path)*shade*(1-bank*.17)end
  local result={p=v(x,y,z),n=v(nx,ny,nz),c=c};samples[key]=result;return result
 end
 local function tri(a,b,c)
  for _,s in ipairs({a,b,c})do m:vertex(s.p,s.n,s.c)end;m.count=m.count+1
 end
 local function quad(x,z,size)
  local a,b,c,d=sample(x,z),sample(x,z+size),sample(x+size,z+size),sample(x+size,z)
  tri(a,b,c);tri(a,c,d)
 end
 local function fine(x,z)return math.abs(x-W.Stream(z))<W.StreamWidth(z)+2.7 end
 for z=z0,z0+22,2 do for x=x0,x0+22,2 do
  if fine(x+1,z+1)then
   for dz=0,1 do for dx=0,1 do quad(x+dx,z+dz,1)end end
  else
   -- Coarse neighbours share every edge midpoint with the refined 1m bank
   -- cells, including across chunk boundaries: no T-junction cracks.
   local west,north,east,south=fine(x-1,z+1),fine(x+1,z+3),fine(x+3,z+1),fine(x+1,z-1)
   if west or north or east or south then
    local ring={sample(x,z)}
    if west then ring[#ring+1]=sample(x,z+1)end
    ring[#ring+1]=sample(x,z+2)
    if north then ring[#ring+1]=sample(x+1,z+2)end
    ring[#ring+1]=sample(x+2,z+2)
    if east then ring[#ring+1]=sample(x+2,z+1)end
    ring[#ring+1]=sample(x+2,z)
    if south then ring[#ring+1]=sample(x+1,z)end
    local mid=sample(x+1,z+1)
    for i,a in ipairs(ring)do tri(mid,a,ring[i%#ring+1])end
   else quad(x,z,2)end
  end
 end end
end
function A.Understory(m,x0,z0,seed)
 for i=1,24 do
  local x=x0+(i*.61803398875%1)*24;local z=z0+((i*.381966+seed*.177)%1)*24
  local d=W.PathDistance(x,z);local wet=math.abs(x-W.Stream(z))<W.StreamWidth(z)+1.1
  if d>2.8 and not wet then
   local y=W.GroundHeight(x,z)
   if i%3==0 then Plants.Shrub(m,x,y-.04,z,.7+(i%4)*.23,seed+i)
   elseif i%2==0 then Plants.Fern(m,x,y,z,.7+i%3*.12,seed+i)
   else for k=1,3 do local a=k*2.4+seed
    leaf(m,v(x,y,z),v(x+cos(a)*.40,y+.36,z+sin(a)*.40),.11,{.34,.46,.19})
   end end
  end
 end
 for i=1,32 do
  local x=x0+((i*3.73+seed)%24);local z=z0+((i*1.37+seed*.3)%24)
  if math.abs(x-W.Stream(z))>W.StreamWidth(z)+.6 then
   local y=W.GroundHeight(x,z)+.018
   leaf(m,v(x-.09,y,z),v(x+.09,y+.012,z+.16),.06,i%3==0 and{.60,.43,.22}or{.42,.48,.21})
   if i%9==0 and W.PathDistance(x,z)>2.1 then
    m:quad(v(x-.07,y+.18,z),v(x,y+.18,z+.07),v(x+.07,y+.18,z),v(x,y+.18,z-.07),{.89,.79,.46})
   end
  end
 end
end
function A.Log(m,x,z,length,angle)
 local y=W.GroundHeight(x,z);local d=v(cos(angle),0,sin(angle))
 local a=v(x,y+.22,z)-d*(length*.5);local b=a+d*length
 m:tube(a,b,.24,.21,{.34,.25,.16},9)
 -- A visible light cut end and darker heartwood ring.
 local up=v(0,.17,0);local side=d:CrossProduct(Vector3.UP):Normalized()*.17
 local endp=b+d*.006
 for i=1,9 do local aa,bb=(i-1)*2*pi/9,i*2*pi/9
  m:tri(endp,endp+up*cos(aa)+side*sin(aa),endp+up*cos(bb)+side*sin(bb),{.67,.51,.29})
 end
 Plants.Fern(m,x+.6,y,z-.5,.63,angle)
end
function A.Bridge(m,z)
 local x=W.Stream(z);local half=W.StreamWidth(z)+3.8
 for xx=-half,half,.34 do
  m:box(x+xx,W.Height(x+xx,z)-.075,z,.31,.14,2.35,{.58+.05*sin(xx*3),.405,.23})
 end
 for side=-1,1,2 do
  local zz=z+side*1.15
  for dx=-1,1,2 do local px=x+dx*(W.StreamWidth(z)+.9);local y=W.Height(px,z)
   m:box(px,y+.48,zz,.10,.96,.10,{.37,.27,.16})
  end
  local yy=W.WaterHeight(z)+1.45
  A.Limb(m,v(x-W.StreamWidth(z)-.9,yy,zz),v(x,yy-.16,zz),.025,.025,{.63,.52,.31},5)
  A.Limb(m,v(x,yy-.16,zz),v(x+W.StreamWidth(z)+.9,yy,zz),.025,.025,{.63,.52,.31},5)
 end
end
return A
