-- Indexed, spatially culled water. Shallow/deep cells share exact vertices;
-- geometry never overlaps and opaque water can reject hidden seabed pixels.
local Motion=require("Game.OceanMotion")
local Field=require("Game.OceanField")
local R={};R.__index=R
function R.Region(mode,zoom)
 if mode=="home"then return "home"end
 if mode=="fishing"or mode=="shore"then return "fishing"end
 return mode=="map"and zoom<.12 and "chart"or "sailing"
end
function R.Plan(mode)
 local axis=Motion.GridAxis(mode);local n=#axis
 local points,groups={},{}
 for j,z in ipairs(axis)do for i,x in ipairs(axis)do
  local coast,depth=Field.Sample(x,z,mode)
  local far=math.max(0,math.min(1,(600-math.max(math.abs(x),math.abs(z)))/376))
  points[#points+1]={x=x,z=z,damping=Field.Damping(x,z,mode),far=far,depth=depth,coast=coast}
 end end
 for j=1,n-1 do for i=1,n-1 do
  local ia=(j-1)*n+i;local ib=j*n+i;local ic=ib+1;local id=ia+1
  local a,b,c,d=points[ia],points[ib],points[ic],points[id]
  local _,middle=Field.Sample((a.x+c.x)*.5,(a.z+c.z)*.5,mode)
  local deep=math.min(a.depth,b.depth,c.depth,d.depth,middle)>24
   and math.min(a.coast,b.coast,c.coast,d.coast)>6
  -- Real underwater fish/coral stay underneath a transparent fishing window.
  if mode=="fishing" and math.min(math.abs(a.x),math.abs(c.x))<60
   and math.min(math.abs(a.z),math.abs(c.z))<60 then deep=false end
  local gx,gz=math.floor((i-1)/24),math.floor((j-1)/24)
  local key=gx..":"..gz..(deep and ":deep" or ":shallow")
  local group=groups[key]
  if not group then group={deep=deep,indices={},xmin=a.x,xmax=c.x,zmin=a.z,zmax=c.z};groups[key]=group end
  group.xmin=math.min(group.xmin,a.x);group.xmax=math.max(group.xmax,c.x)
  group.zmin=math.min(group.zmin,a.z);group.zmax=math.max(group.zmax,c.z)
  -- Increasing z rows: a,b,c and a,c,d face UP.
  local indices=group.indices
  for _,index in ipairs({ia-1,ib-1,ic-1,ia-1,ic-1,id-1})do indices[#indices+1]=index end
 end end
 return points,groups
end
function R.Build(parent,mode,shallow,deep)
 local root=parent:CreateChild("PartitionedOcean_"..mode)
 local points,groups=R.Plan(mode)
 local vb=VertexBuffer:new();vb.shadowed=true
 vb:SetSize(#points,{VertexElement(TYPE_VECTOR3,SEM_POSITION),VertexElement(TYPE_VECTOR3,SEM_NORMAL),VertexElement(TYPE_VECTOR2,SEM_TEXCOORD,0)})
 local vertices=VectorBuffer()
 for _,p in ipairs(points)do
  vertices:WriteVector3(Vector3(p.x,0,p.z));vertices:WriteVector3(Vector3.UP)
  vertices:WriteVector2(Vector2(p.damping,p.far))
 end
 vb:SetData(vertices)
 ---@type (VertexBuffer|IndexBuffer|Geometry|Model)[]
 local refs={vb};local triangles=0;local chunks=0
 for key,group in pairs(groups)do
  local ib=IndexBuffer:new();ib.shadowed=true;ib:SetSize(#group.indices,false)
  local indices=VectorBuffer();for _,index in ipairs(group.indices)do indices:WriteUShort(index)end
  ib:SetData(indices)
  local geometry=Geometry:new();geometry:SetVertexBuffer(0,vb);geometry:SetIndexBuffer(ib)
  geometry:SetDrawRange(TRIANGLE_LIST,0,#group.indices)
  local model=Model:new();model.numGeometries=1;model:SetGeometry(0,0,geometry)
  model.boundingBox=BoundingBox(Vector3(group.xmin-.5,-1,group.zmin-.5),Vector3(group.xmax+.5,1,group.zmax+.5))
  local node=root:CreateChild(key);local drawable=node:CreateComponent("StaticModel")
  drawable.model=model;drawable.material=group.deep and deep or shallow;drawable.castShadows=false
  refs[#refs+1]=model;refs[#refs+1]=ib;refs[#refs+1]=geometry
  triangles=triangles+#group.indices/3;chunks=chunks+1
 end
 return {root=root,refs=refs,vertices=#points,triangles=triangles,chunks=chunks}
end
return R
