-- One retained water surface, based on scene-to-nanovg.md / SceneTarget.lua.
-- The normal gameplay viewport remains suspended on the illustrated home map.
local D=require("Game.HomeIslandData")
local Motion=require("Game.OceanMotion")
---@class HomeOcean
---@field scene Scene?
---@field cameraNode Node
---@field camera Camera
---@field viewport Viewport
---@field material Material
---@field texture Texture2D?
---@field surface RenderSurface?
---@field image integer?
---@field context any
---@field width integer?
---@field height integer?
---@field clock number
---@field key string?
local O={};O.__index=O
local UNIT=.02
local function axis(length)
 local a={-10000,-3000,-1200,-500}
 for n=-160,length+160,40 do a[#a+1]=n end
 a[#a+1]=length+500;a[#a+1]=length+1200;a[#a+1]=length+3000;a[#a+1]=length+10000
 return a
end
function O.new()
 local self=setmetatable({},O)
 local ok,err=pcall(function()self:Init()end)
 if not ok then self:Stop();print("[HomeOcean] sailing water unavailable: "..tostring(err));return nil end
 return self
end
function O:Init()
 self.clock=1
 self.scene=Scene();self.scene:CreateComponent("Octree")
 self.material=assert(cache:GetResource("Material","Materials/HomeOcean.xml"),"home water material unavailable")
 Motion.Bind(self.material)
 self.material:SetShaderParameter("wave_strength",Variant(Motion.Strength("sailing")))
 self.material:SetShaderParameter("water_view",Variant(Vector4(0,1,0,1)))
 self.material:SetShaderParameter("home_mode",Variant(0))
 self.material:SetShaderParameter("chart_mode",Variant(0))
 local environment=self.scene:CreateChild("HomeWaterEnvironment"):CreateComponent("Zone")
 environment.boundingBox=BoundingBox(Vector3(-1000,-1000,-1000),Vector3(1000,1000,1000))
 environment.depthFogEnable=false;environment.heightFogEnable=false
 self.cameraNode=self.scene:CreateChild("HomeWaterCamera")
 self.camera=self.cameraNode:CreateComponent("Camera")
 self.camera.orthographic=true;self.camera.autoAspectRatio=false
 self.camera.nearClip=.1;self.camera.farClip=100
 local mesh=self.scene:CreateChild("HomeWater"):CreateComponent("CustomGeometry")
 mesh:BeginGeometry(0,TRIANGLE_LIST)
 local xs,ys=axis(D.width),axis(D.height);local field={}
 for j,y in ipairs(ys)do
  field[j]={}
  for i,x in ipairs(xs)do
   local shore=D.Distance(x,y)*UNIT
   local q=math.max(0,math.min(1,shore/3.0))
   field[j][i]=q*q*(3-2*q)
  end
 end
 local function vertex(i,j)
  -- Same Y-up XZ water plane and damping UVs as OceanRenderer. Map Y maps
  -- to -Z so a downward camera with +Z up preserves the island image orientation.
  mesh:DefineVertex(Vector3(xs[i]*UNIT,0,-ys[j]*UNIT))
  mesh:DefineNormal(Vector3.UP);mesh:DefineTexCoord(Vector2(field[j][i],1))
 end
 for j=1,#ys-1 do for i=1,#xs-1 do
  vertex(i,j);vertex(i+1,j);vertex(i,j+1)
  vertex(i+1,j);vertex(i+1,j+1);vertex(i,j+1)
 end end
 mesh:Commit();mesh:SetMaterial(self.material)
 self.viewport=Viewport:new(self.scene,self.camera)
 local path=self.viewport:GetRenderPath():Clone()
 assert(path:Load(assert(cache:GetResource("XMLFile","RenderPaths/HomeOcean.xml"))))
 assert(path:Append(assert(cache:GetResource("XMLFile","EngineRes/PostProcess/GammaCorrection.xml"))))
 self.viewport:SetRenderPath(path)
end
function O:ReleaseTexture()
 if self.image and self.image>0 then nvgDeleteVideo(self.context,self.image)end
 self.image=nil;self.context=nil
 if self.surface then self.surface:SetNumViewports(0)end
 if self.texture then self.texture:Dispose()end
 self.surface=nil;self.texture=nil
end
function O:Resize(app)
 local dpr=graphics:GetDPR()
 local w=math.min(720,math.max(360,math.floor(450*app.scale*dpr+.5)))
 local h=math.floor(w*app.h/450+.5)
 if h>1280 then w=math.floor(w*1280/h+.5);h=1280 end
 if w==self.width and h==self.height then return end
 self:ReleaseTexture()
 local texture=Texture2D:new();texture:SetNumLevels(1)
 if not texture:SetSize(w,h,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET)then
  texture:Dispose();error("home ocean target allocation failed")
 end
 texture:SetFilterMode(FILTER_BILINEAR)
 self.texture=texture;self.width=w;self.height=h
 self.viewport.rect=IntRect(0,0,w,h)
 self.camera.aspectRatio=450/app.h
 self.surface=assert(texture:GetRenderSurface())
 self.surface:SetViewport(0,self.viewport);self.surface:SetUpdateMode(SURFACE_MANUALUPDATE)
 self.key=nil
end
function O:Update(app,dt)
 -- A paused modal/other activity never queues this offscreen surface.
 if app.mode~="home"or app.modal then return end
 self:Resize(app)
 self.clock=self.clock+dt
 local c=app.camera;local key=string.format("%.3f/%.3f/%.4f/%.1f",c.x,c.y,c.zoom,app.h)
 if self.clock<1/30 and key==self.key then return end
 self.clock=0;self.key=key
 self.cameraNode.position=Vector3(c.x*UNIT,40,-c.y*UNIT)
 self.cameraNode:LookAt(Vector3(c.x*UNIT,0,-c.y*UNIT),Vector3(0,0,1))
 self.camera:SetOrthoSize(Vector2(450/c.zoom*UNIT,app.h/c.zoom*UNIT))
 self.camera.aspectRatio=450/app.h
 self.material:SetShaderParameter("ocean_time",Variant(app.playtime))
 self.surface:QueueUpdate()
end
function O:Draw(v,w,h)
 if not self.texture then return false end
 if self.context and self.context~=v then
  if self.image and self.image>0 then nvgDeleteVideo(self.context,self.image)end
  self.image=nil
 end
 self.context=v
 if not self.image then self.image=nvgCreateVideo(v,self.texture)end
 if not self.image or self.image<=0 then return false end
 nvgBeginPath(v);nvgRect(v,0,0,w,h)
 nvgFillPaint(v,nvgImagePattern(v,0,0,w,h,0,self.image,1));nvgFill(v)
 return true
end
function O:Stop()
 self:ReleaseTexture();self.scene=nil
end
return O
