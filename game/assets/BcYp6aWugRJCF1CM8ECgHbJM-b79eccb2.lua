-- Retained procedural meshes. Metres, Y-up, outward triangle winding.
-- CustomGeometry follows examples/07-minecraft-voxel-world and the 3D scaffold.
---@class IslandMesh
---@field node Node
---@field geometry CustomGeometry
---@field count number
local M = {}; M.__index = M
---@return IslandMesh
function M.new(parent,name,material)
 ---@type IslandMesh
 local self=setmetatable({},M)
 self.node=parent:CreateChild(name)
 self.geometry=self.node:CreateComponent("CustomGeometry")
 self.geometry:SetNumGeometries(1);self.geometry:BeginGeometry(0,TRIANGLE_LIST)
 self.geometry:SetMaterial(material);self.count=0
 return self
end
---@param a Vector3
---@param b Vector3
---@param c Vector3
function M:tri(a,b,c,color)
 local normal=(b-a):CrossProduct(c-a):Normalized()
 for _,p in ipairs({a,b,c}) do
  self.geometry:DefineVertex(p);self.geometry:DefineNormal(normal)
  self.geometry:DefineColor(Color(color[1],color[2],color[3],color[4] or 1))
  self.geometry:DefineTexCoord(Vector2(p.x,p.z))
 end
 self.count=self.count+1
end
function M:quad(a,b,c,d,color) self:tri(a,b,c,color);self:tri(a,c,d,color) end
-- Smooth primitives keep their analytic normals; curved objects must not inherit
-- the polygon normals of terrain, roof tiles and cut timber.
---@param p Vector3
---@param normal Vector3
function M:vertex(p,normal,color)
 self.geometry:DefineVertex(p);self.geometry:DefineNormal(normal)
 self.geometry:DefineColor(Color(color[1],color[2],color[3],color[4] or 1))
 self.geometry:DefineTexCoord(Vector2(p.x,p.z))
end
function M:smoothTri(a,b,c,na,nb,nc,color)
 self:vertex(a,na,color);self:vertex(b,nb,color);self:vertex(c,nc,color);self.count=self.count+1
end
function M:ellipsoid(x,y,z,rx,ry,rz,color,n,rows)
 n=n or 16;rows=rows or 8
 local function sample(phi,theta)
  local sx,sy,sz=math.sin(phi)*math.cos(theta),math.cos(phi),math.sin(phi)*math.sin(theta)
  return Vector3(x+rx*sx,y+ry*sy,z+rz*sz),Vector3(sx/rx,sy/ry,sz/rz):Normalized()
 end
 for j=0,rows-1 do for i=0,n-1 do
  local a,na=sample(j*math.pi/rows,i*2*math.pi/n)
  local b,nb=sample((j+1)*math.pi/rows,i*2*math.pi/n)
  local c,nc=sample((j+1)*math.pi/rows,(i+1)*2*math.pi/n)
  local d,nd=sample(j*math.pi/rows,(i+1)*2*math.pi/n)
  if j>0 then self:smoothTri(a,d,c,na,nd,nc,color)end
  if j<rows-1 then self:smoothTri(a,c,b,na,nc,nb,color)end
 end end
end
---@param a Vector3
---@param b Vector3
function M:tube(a,b,r0,r1,color,n)
 n=n or 10;r1=r1 or r0
 local delta=b-a;local len=delta.length;local along=delta:Normalized()
 local side=along:CrossProduct(math.abs(along.y)>.9 and Vector3.RIGHT or Vector3.UP):Normalized()
 local up=along:CrossProduct(side):Normalized()
 for i=0,n-1 do
  local q0,q1=i*2*math.pi/n,(i+1)*2*math.pi/n
  local d0,d1=side*math.cos(q0)+up*math.sin(q0),side*math.cos(q1)+up*math.sin(q1)
  local n0=(d0+along*((r0-r1)/len)):Normalized()
  local n1=(d1+along*((r0-r1)/len)):Normalized()
  self:smoothTri(a+d0*r0,a+d1*r0,b+d1*r1,n0,n1,n1,color)
  self:smoothTri(a+d0*r0,b+d1*r1,b+d0*r1,n0,n1,n0,color)
  self:tri(a,a+d1*r0,a+d0*r0,color);self:tri(b,b+d0*r1,b+d1*r1,color)
 end
end
---@param axis Vector3|nil
function M:torus(x,y,z,radius,thickness,color,axis,n)
 n=n or 24;axis=(axis or Vector3.UP):Normalized()
 local side=axis:CrossProduct(math.abs(axis.y)>.9 and Vector3.RIGHT or Vector3.UP):Normalized()
 local up=axis:CrossProduct(side):Normalized();local centre=Vector3(x,y,z)
 local function sample(a,b)
  local radial=side*math.cos(a)+up*math.sin(a)
  local normal=radial*math.cos(b)+axis*math.sin(b)
  return centre+radial*radius+normal*thickness,normal
 end
 for i=0,n-1 do for j=0,5 do
  local a,na=sample(i*2*math.pi/n,j*math.pi/3)
  local b,nb=sample((i+1)*2*math.pi/n,j*math.pi/3)
  local c,nc=sample((i+1)*2*math.pi/n,(j+1)*math.pi/3)
  local d,nd=sample(i*2*math.pi/n,(j+1)*math.pi/3)
  self:smoothTri(a,b,c,na,nb,nc,color);self:smoothTri(a,c,d,na,nc,nd,color)
 end end
end
function M:box(x,y,z,w,h,d,color,yaw)
 local co,si=math.cos(yaw or 0),math.sin(yaw or 0)
 local function p(a,b,c) return Vector3(x+a*co+c*si,y+b,z-a*si+c*co) end
 local a,b,c,d0=p(-w/2,-h/2,-d/2),p(w/2,-h/2,-d/2),p(w/2,-h/2,d/2),p(-w/2,-h/2,d/2)
 local e,f,g,h0=p(-w/2,h/2,-d/2),p(w/2,h/2,-d/2),p(w/2,h/2,d/2),p(-w/2,h/2,d/2)
 self:quad(e,h0,g,f,color);self:quad(a,b,c,d0,color)
 self:quad(a,e,f,b,color);self:quad(b,f,g,c,color)
 self:quad(c,g,h0,d0,color);self:quad(d0,h0,e,a,color)
end
function M:cone(x,y,z,r0,r1,height,color,n)
 n=n or 9
 for i=1,n do
  local a,b=(i-1)*math.pi*2/n,i*math.pi*2/n
  local p=Vector3(x+math.cos(a)*r0,y,z+math.sin(a)*r0)
  local q=Vector3(x+math.cos(b)*r0,y,z+math.sin(b)*r0)
  local u=Vector3(x+math.cos(a)*r1,y+height,z+math.sin(a)*r1)
  local v=Vector3(x+math.cos(b)*r1,y+height,z+math.sin(b)*r1)
  self:quad(p,u,v,q,color)
  if r1>0 then self:tri(Vector3(x,y+height,z),v,u,color) end
  self:tri(Vector3(x,y,z),p,q,color)
 end
end
function M:rock(x,y,z,rx,ry,rz,color,seed)
 local n=9;local rings={};local profile={{0,.72},{.22,1},{.65,.91},{.91,.51},{1,.08}}
 for j,row in ipairs(profile)do rings[j]={}
  for i=1,n do local a=i*math.pi*2/n;local r=row[2]*(.9+.09*math.sin(i*13+(seed or 0)))
   rings[j][i]=Vector3(x+math.cos(a)*rx*r+rx*.1*row[1],y+ry*row[1],z+math.sin(a)*rz*r)
  end
 end
 for j=1,#rings-1 do for i=1,n do local k=i%n+1
  local shade=.93+.07*j/#rings
  self:quad(rings[j][i],rings[j+1][i],rings[j+1][k],rings[j][k],{color[1]*shade,color[2]*shade,color[3]*shade})
 end end
 self:tri(rings[#rings][1],rings[#rings][4],rings[#rings][7],color)
end
---@param a Vector3
---@param b Vector3
function M:beam(a,b,r,color)
 local along=(b-a):Normalized()
 local side=along:CrossProduct(math.abs(along.y)>.9 and Vector3.RIGHT or Vector3.UP):Normalized()*r
 local up=along:CrossProduct(side):Normalized()*r
 self:quad(a-side-up,a+side-up,b+side-up,b-side-up,color)
 self:quad(a+side-up,a+side+up,b+side+up,b+side-up,color)
 self:quad(a+side+up,a-side+up,b-side+up,b+side+up,color)
 self:quad(a-side+up,a-side-up,b-side-up,b-side+up,color)
end
function M:finish() self.geometry:Commit();return self.node end
return M
