-- Authored cel art in retained world space. Ground, buildings and wind meshes
-- share one fixed orthographic camera; zoom/pan never rasterise the whole scene.
local Mesh=require("Game.Mesh")
local Shape=require("Game.IslandShape")
local Layout=require("Game.IslandLayout")
local L={}
local function v(x,y,z)return Vector3(x,y,z)end
local up=v(0,70,88):Normalized()
local normal=v(0,88,-70):Normalized()
local function material(path,texture)
 local m=Material:new();assert(m:SetSurfaceShader(path),"Cel island shader failed: "..path)
 local image=cache:GetResource("Texture2D",texture);assert(image,"Missing cel island texture: "..texture)
 m:SetSurfaceTexture("art_map",image);return m
end
local function vertex(mesh,p,u,vv,phase,weight,n)
 mesh.geometry:DefineVertex(p);mesh.geometry:DefineNormal(n or normal)
 mesh.geometry:DefineTexCoord(Vector2(u,vv));mesh.geometry:DefineColor(Color(phase or 0,1,1,weight or 0))
end
-- Atlas cells retain transparent margins to avoid filtering neighbour sprites.
function L.Sprite(mesh,cell,x,z,width,height,seed)
 x,z=Shape.Map(x,z)
 local col=(cell-1)%2;local row=math.floor((cell-1)/2)
 local origin=v(x,.13,z)-up*(height*.055)
 local columns,rows=4,6
 for yy=0,rows-1 do for xx=0,columns-1 do
  local function point(i,j)
   local u,t=i/columns,j/rows
   return {p=origin+v((u-.5)*width,0,0)+up*(t*height),u=(col+u)*.5,v=(row+1-t)*.5,w=math.max(0,(t-.18)/.82)^2}
  end
  local a,b,c,d=point(xx,yy),point(xx,yy+1),point(xx+1,yy+1),point(xx+1,yy)
  for _,p in ipairs({a,b,c,a,c,d})do vertex(mesh,p.p,p.u,p.v,((seed or 0)*.071)%1,p.w)end
  mesh.count=mesh.count+2
 end end
end
function L.Build(s)
 s.islandGroundMat=material("Shaders/BLGL/CrescentIslandGround.shader","Textures/CelWorld/terrain.png")
 local coast=cache:GetResource("Texture2D","Textures/CelWorld/coast-data.png");assert(coast,"Missing coast distance data")
 s.islandGroundMat:SetSurfaceTexture("coast_data",coast)
 if not s.waterRegions then s.waterMat:SetSurfaceTexture("coast_data",coast)end
 s.apronMat:SetSurfaceTexture("coast_data",coast)
 local ground=Mesh.new(s.home,"PaintedIslandTerrain",s.islandGroundMat)
 -- Bend the authored pixels and shoreline together, with real mesh bounds.
 local steps=32
 for iz=0,steps-1 do for ix=0,steps-1 do
  local function point(i,j)
   local u,w=i/steps,j/steps
   local x,z=Shape.Map((u-.5)*54,(w-.5)*54)
   return {v(x,.12,z),u,1-w}
  end
  local a,b,c,d=point(ix,iz),point(ix,iz+1),point(ix+1,iz+1),point(ix+1,iz)
  for _,p in ipairs({a,b,c,a,c,d})do vertex(ground,p[1],p[2],p[3],0,0,Vector3.UP)end
 end end
 ground.count=steps*steps*2;ground:finish()
 s.islandBuildingMat=material("Shaders/BLGL/CrescentSprite.shader","Textures/CelWorld/buildings.png")
 s.islandWindMat=material("Shaders/BLGL/CrescentSprite.shader","Textures/CelWorld/vegetation.png")
 s.islandWindMat:SetShaderParameter("wind_strength",Variant(.16))
 local houses=Mesh.new(s.home,"IllustratedVillageBuildings",s.islandBuildingMat)
 for _,b in ipairs(Layout.buildings)do L.Sprite(houses,b.cell,b.x,b.z,b.size,b.size,0)end
 houses:finish()
 local trees=Mesh.new(s.home,"WindBentLeafCanopies",s.islandWindMat)
 -- Deliberate groves, keeping paths and building clearings open.
 local groves={{-17,7},{-11,11},{-7,16},{0,17},{7,16},{13,12},{17,6},{17,-2},{16,-12},
  {-18,-5},{-16,-12},{-10,-15},{-2,-16},{5,-16},{-6,4},{8,6}}
 for i,p in ipairs(groves)do
  for j=1,2 do local x,z=p[1]+(j-1)*2.1,p[2]+(j-1)*1.1
   local cell=i%4==0 and 2 or i%5==0 and 3 or 1
   local size=cell==2 and 7.8 or 5.6+(i%3)*.5
   L.Sprite(trees,cell,x,z,size,size,i*2+j)
  end
 end
 trees:finish()
 s.homeMedium=s.home:CreateChild("FloweringUndergrowth")
 local bushes=Mesh.new(s.homeMedium,"FernAndFlowerBeds",s.islandWindMat)
 for i=1,32 do local a=i*2.399;local r=14+i%6
  L.Sprite(bushes,4,math.cos(a)*r,math.sin(a)*r,2.5+i%3*.3,2.5+i%3*.3,i+40)
 end
 bushes:finish()
 s.homeDetails=s.home:CreateChild("HarbourDetails")
 local harbour=s.home:CreateChild("MappedHarbour")
 local hx,hz,yaw=Layout.Harbour()
 harbour.position=v(hx,0,hz)
 harbour.rotation=Quaternion(0,math.deg(yaw),0)
 local dock=s:NewMesh(harbour,"WoodenJetty",false)
 for i=0,17 do dock:box(0,.22,-i*.48,2.6,.18,.44,{.69+(i%2)*.06,.46,.25})end
 for i=0,5 do for _,x in ipairs({-1.4,1.4})do
  dock:box(x,.05,-i*1.6,.15,1.7,.15,{.43,.28,.15})
  dock:torus(x,.82,-i*1.6,.10,.025,{.91,.84,.63},nil,10)
 end end
 dock:finish()
 local bx,bz=Shape.Map(12,-24);s.mooredAnchor={x=bx,z=bz}
 s.moored=s:Boat(s.home,"MooredBoat");s.moored.position=v(bx,.25,bz)
 s.moored.rotation=Quaternion(0,15,0)
end
return L
