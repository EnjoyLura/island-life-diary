-- A real sandy slope outside the painted coastline, with registered stone
-- groups on the dry strand, at the waterline and below the transparent water.
local Mesh=require("Game.Mesh")
local contour=require("Game.CoastContour")
local Shape=require("Game.IslandShape")
local C={points=contour}
function C.Depth(d)
 return Shape.Depth(d)
end
-- Closest polygon segment, used only while placing a few pebble groups.
-- This keeps stones embedded in the bank instead of floating above coves.
function C.Distance(x,z)
 local best=1e9;local inside=false
 for i,p in ipairs(contour)do
  local q=contour[i%#contour+1];local dx,dz=q[1]-p[1],q[2]-p[2]
  local t=math.max(0,math.min(1,((x-p[1])*dx+(z-p[2])*dz)/(dx*dx+dz*dz)))
  best=math.min(best,(x-p[1]-t*dx)^2+(z-p[2]-t*dz)^2)
  if (p[2]>z)~=(q[2]>z) and x<(q[1]-p[1])*(z-p[2])/(q[2]-p[2])+p[1]then inside=not inside end
 end
 return math.sqrt(best)*(inside and -1 or 1)
end
function C.Build(parent,material)
 local mesh=Mesh.new(parent,"SubmergedBeachApron",material)
 mesh.geometry.castShadows=false
 local offsets={-.55,0,1.3,2.8,4.8,7.6,11,16,24,40.6}
 -- Unwrap ALONG the actual coastline. An integer number of repeats closes
 -- the final seam; the second coordinate runs out from the strand.
 ---@type number[]
 local arc={0}
 local total=0
 for i,p in ipairs(contour)do
  local q=contour[i%#contour+1]
  local x,z=Shape.Map(p[1],p[2]);local xx,zz=Shape.Map(q[1],q[2])
  total=total+math.sqrt((xx-x)^2+(zz-z)^2);arc[i+1]=total
 end
 local repeats=math.max(1,math.floor(total/14+.5))
 local function point(i,d)
  local p=contour[(i-1)%#contour+1]
  local x,z=Shape.Map(p[1]+p[3]*d,p[2]+p[4]*d)
  return Vector3(x,-C.Depth(d),z)
 end
 ---@param a Vector3
 ---@param b Vector3
 ---@param c Vector3
 ---@param ua Vector2
 ---@param ub Vector2
 ---@param uc Vector2
 local function tri(a,b,c,ua,ub,uc)
  local normal=(b-a):CrossProduct(c-a):Normalized()
  local function vertex(p,uv)
   mesh.geometry:DefineVertex(p);mesh.geometry:DefineNormal(normal)
   mesh.geometry:DefineColor(Color(1,1,1,1));mesh.geometry:DefineTexCoord(uv)
  end
  vertex(a,ua);vertex(b,ub);vertex(c,uc);mesh.count=mesh.count+1
 end
 for i=1,#contour do for j=1,#offsets-1 do
  local a,b,c,d=point(i,offsets[j]),point(i+1,offsets[j]),point(i+1,offsets[j+1]),point(i,offsets[j+1])
  local u0,u1=arc[i]/total*repeats,arc[i+1]/total*repeats
  local v0,v1=offsets[j]/14,offsets[j+1]/14
  local ua,ub,uc,ud=Vector2(u0,v0),Vector2(u1,v0),Vector2(u1,v1),Vector2(u0,v1)
  tri(a,b,c,ua,ub,uc);tri(a,c,d,ua,uc,ud)
 end end
 mesh:finish();return mesh
end
function C.Rocks()
 local shore,underwater={},{}
 for i=1,#contour,6 do
  local p=contour[i]
  for j=1,4 do
   local offset=({-.25,1.3,3.2,5.7})[j]+math.sin(i*.67+j)*.22
   local along=math.sin(i*1.7+j)*.68
   local bx,bz=p[1]+p[3]*offset-p[4]*along,p[2]+p[4]*offset+p[3]*along
   local bottom,height
   if j==1 then bottom=-.04;height=.20+(i%5)*.035
   else
    local depth=C.Depth(C.Distance(bx,bz))
    bottom=-depth-.10
    height=math.min(.23+(i+j)%4*.07,depth-.08)
   end
   local x,z=Shape.Map(bx,bz)
   local rock={x=x,z=z,
    rx=.26+(i+j)%5*.10,rz=.24+(i+j*2)%4*.10,bottom=bottom,height=height,
    yaw=i*.71+j*.91,seed=900+i*5+j}
   if j>1 or math.sin(i*.73)>.15 then
    local list=j==1 and shore or underwater;list[#list+1]=rock
   end
  end
 end
 return shore,underwater
end
return C
