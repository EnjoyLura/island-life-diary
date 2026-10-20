-- One original village, repositioned as a unit; no second hand-built copy.
-- Logical sea coordinates use .04 metres per unit.
local contour=require("Game.CoastContour")
local mountain=require("Game.MountainContour")
local Shelf=require("Game.CoastalShelf")
local Shape=require("Game.IslandShape")
local Layout=require("Game.IslandLayout")
local Mesh=require("Game.Mesh")
---@class CrescentBay
local B={metresPerUnit=.04,home={x=90,y=2070,scale=.66},
 mountain={left=1670,top=50,size=1100},chartRight=2140,
 bounds={left=-620,right=1950,top=220,bottom=2900},
 navigation={left=-650,right=1950,top=180,bottom=2900}}
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
local function v(x,y,z)return Vector3(x,y,z)end
function B.HomeFrame()
 return (B.home.x-1000)*.04,-(B.home.y-1200)*.04,B.home.scale
end
-- FromLocal accepts already-shaped geometry; World accepts art source points.
function B.FromLocal(x,z)
 local ox,oz,k=B.HomeFrame();return ox+x*k,oz+z*k
end
function B.World(x,z)return B.FromLocal(Shape.Map(x,z))end
function B.Source(x,y)
 return Shape.Unmap((x-B.home.x)*.04/B.home.scale,-(y-B.home.y)*.04/B.home.scale)
end
function B.PlaceHome(s,atHome)
 local x,z,k=B.HomeFrame();if atHome then x,z,k=0,0,1 end
 s.home.position=v(x,0,z);s.home.scale=v(k,k,k)
 s.apronMat:SetShaderParameter("shelf_frame",Variant(v(x,z,k)))
end
do
 local _,_,_,x,z=Layout.Harbour();local wx,wz=B.FromLocal(x,z)
 B.port={x=1000+wx/.04,y=1200-wz/.04}
end
local function mountainShore(w)
 local row=clamp(w,0,1)*(#mountain-1);local i=math.min(#mountain-1,math.floor(row)+1)
 return mountain[i][1]+(mountain[i+1][1]-mountain[i][1])*(row-i+1)
end
-- Keep the authored shore intact; turn its two open ends east, continuously.
-- CrescentCoast.shaderinc uses the same transform for art and water coverage.
function B.MountainUV(u,w)
 local beyond=math.max(-w,w-1,0)
 local bend=(w<0 and .72 or .18)*(1-math.exp(-beyond*beyond*3))
 return u-bend,clamp(w,0,1),bend
end
function B.MountainShore(w)
 local _,row,bend=B.MountainUV(0,w)
 return mountainShore(row)+bend
end
-- Same open shoreline as the alpha-derived water data. Land continues right.
function B.MountainDistance(u,w)
 u,w=B.MountainUV(u,w)
 local best=math.huge
 for i=1,#mountain-1 do local a,b=mountain[i],mountain[i+1]
  local dx,dz=b[1]-a[1],b[2]-a[2]
  local t=clamp(((u-a[1])*dx+(w-a[2])*dz)/(dx*dx+dz*dz),0,1)
  best=math.min(best,(u-a[1]-dx*t)^2+(w-a[2]-dz*t)^2)
 end
 return math.sqrt(best)*(u<mountainShore(w) and 1 or -1)
end
function B.Resolve(x,y)
 local sx,sz=B.Source(x,y)
 if math.abs(sx)<29 and math.abs(sz)<29 then
  local d=Shelf.Distance(sx,sz)
  if d<1.1 then
   local wx,wz=(x-1000)*.04,-(y-1200)*.04
   local best,bx,bz,nx,nz=math.huge,0,0,1,0
   for i,p in ipairs(contour)do local q=contour[i%#contour+1]
    local ax,az=B.World(p[1],p[2]);local ex,ez=B.World(q[1],q[2])
    local dx,dz=ex-ax,ez-az
    local t=clamp(((wx-ax)*dx+(wz-az)*dz)/(dx*dx+dz*dz),0,1)
    local px,pz=ax+dx*t,az+dz*t;local ds=(wx-px)^2+(wz-pz)^2
    if ds<best then
     best,bx,bz=ds,px,pz;local len=math.sqrt(dx*dx+dz*dz);nx,nz=dz/len,-dx/len
    end
   end
   local dx,dz=bx-wx,bz-wz;local len=math.sqrt(dx*dx+dz*dz)
   if len>.00001 then local sign=d<0 and 1 or -1;nx,nz=dx/len*sign,dz/len*sign end
   return 1000+(bx+nx*.95)/.04,1200-(bz+nz*.95)/.04,true
  end
 end
 local land=B.mountain;local u,w=(x-land.left)/land.size,(y-land.top)/land.size
 if u>-.1 and B.MountainDistance(u,w)<.02 then
  local safe=B.MountainShore(w)-.04
  -- On steep cliff segments a horizontal .04 step can still be very close
  -- to the neighbouring face. Clear the actual distance, not just that row.
  for _=1,8 do if B.MountainDistance(safe,w)>=.025 then break end;safe=safe-.04 end
  return land.left+safe*land.size,y,true
 end
 return x,y,false
end
function B.Build(s)
 local mat=Material:new();assert(mat:SetSurfaceShader("Shaders/BLGL/CrescentMountain.shader"))
 mat:SetSurfaceTexture("art_map",assert(cache:GetResource("Texture2D","Textures/CelWorld/mountain-coast-v17.png")))
 B.Bind(mat)
 local land=B.mountain
 local ox,oz=(land.left-1000)*.04,-(land.top-1200)*.04;local size=land.size*.04
 local ground=Mesh.new(s.sea,"DistantMountainCoast",mat)
 -- The continent and its sand now cover the same extent as the ocean. No
 -- finite square edge can enter either the sailing or the chart viewport.
 local extent=720
 local points={v(ox,.14,extent),v(720,.14,extent),v(720,.14,-extent),v(ox,.14,-extent)}
 local uv={{0,0},{1,0},{1,1},{0,1}}
 for _,i in ipairs({1,2,3,1,3,4})do
  ground.geometry:DefineVertex(points[i]);ground.geometry:DefineNormal(Vector3.UP)
  ground.geometry:DefineTexCoord(Vector2(uv[i][1],uv[i][2]));ground.geometry:DefineColor(Color(0,1,1,0))
 end
 ground.count=2;ground:finish();ground.geometry.castShadows=false
 local bank=Mesh.new(s.sea,"MountainSubmergedCoast",s.bedMat)
 local function point(w,offset)
  local u=B.MountainShore(w)-offset/size
  local d=math.max(0,B.MountainDistance(u,w)*size)
  return v(ox+u*size,-Shelf.Depth(d),oz-w*size)
 end
 local rows={};local north,south=(oz-extent)/size,(oz+extent)/size
 for i=8,1,-1 do rows[#rows+1]=-2+(north+2)*(i/8) end
 for i=24,1,-1 do rows[#rows+1]=-2*(i/24)^2 end
 for _,p in ipairs(mountain)do rows[#rows+1]=p[2]end
 for i=1,24 do rows[#rows+1]=1+2*(i/24)^2 end
 for i=1,8 do rows[#rows+1]=3+(south-3)*(i/8) end
 local offsets={-.25,0,1,3,8,16,32,80}
 for j=1,#rows-1 do for i=1,#offsets-1 do
  local a,b=rows[j],rows[j+1];local inner,outer=offsets[i],offsets[i+1]
  bank:quad(point(a,inner),point(b,inner),point(b,outer),point(a,outer),{1,1,1})
 end end
 bank:finish();bank.geometry.castShadows=false
end
function B.Bind(material)
 local x,z,k=B.HomeFrame();material:SetShaderParameter("bay_home",Variant(v(x,z,k)))
 local land=B.mountain
 material:SetShaderParameter("mountain_frame",Variant(Vector4((land.left-1000)*.04,-(land.top-1200)*.04,land.size*.04,land.size*.04)))
 material:SetSurfaceTexture("mountain_data",assert(cache:GetResource("Texture2D","Textures/CelWorld/mountain-coast-data.png")))
end
return B
