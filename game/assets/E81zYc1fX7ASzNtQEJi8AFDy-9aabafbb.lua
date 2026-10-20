-- Independent 3D resolution; UI/input keep the original viewport and DPR.
-- Based on engine-docs/recipes/scene-to-nanovg.md. One retained RT/image.
---@class CrescentSceneTarget
---@field requestedScale number
---@field scale number
---@field active boolean
---@field image integer?
---@field imageContext any
---@field failure string?
---@field left number?
---@field top number?
---@field right number?
---@field bottom number?
---@field width number?
---@field height number?
---@field displayWidth number?
---@field displayHeight number?
---@field viewport Viewport
---@field texture Texture2D?
---@field surface RenderSurface?
local T={};T.__index=T
---@param viewport Viewport
---@param scale number
---@return CrescentSceneTarget
function T.new(viewport,scale)
 local self=setmetatable({viewport=viewport,requestedScale=scale,scale=scale,active=true},T)
 -- Water needs a readable opaque depth attachment as well as scene colour.
 -- Use the same explicit path at native/offscreen sizes. The CEMap screenread
 -- pass owns its screen/depth copies; no second camera or depth geometry pass.
 local path=viewport:GetRenderPath():Clone()
 assert(path:Load(assert(cache:GetResource("XMLFile","RenderPaths/CrescentForward.xml"))))
 assert(path:Append(assert(cache:GetResource("XMLFile","EngineRes/PostProcess/GammaCorrection.xml"))))
 for i=0,path:GetNumCommands()-1 do
  local command=path:GetCommand(i)
  if command.type==CMD_CLEAR then
   command.useFogColor=false;command.clearColor=Color(0,0,0,1)
  end
  path:SetCommand(i,command)
 end
 viewport:SetRenderPath(path)
 renderer:SetViewport(0,scale==1 and viewport or nil)
 return self
end
function T:ReleaseImage()
 if self.image and self.image~=0 then nvgDeleteVideo(self.imageContext,self.image)end
 self.image=nil;self.imageContext=nil
end
function T:ReleaseTexture()
 self:ReleaseImage()
 if self.surface then self.surface:SetNumViewports(0)end
 if self.texture then self.texture:Dispose()end
 self.surface=nil;self.texture=nil
end
function T:UseNative(reason)
 self:ReleaseTexture()
 self.scale=1;self.failure=tostring(reason)
 self.width,self.height=self.displayWidth,self.displayHeight
 if self.left then self.viewport.rect=IntRect(self.left,self.top,self.right,self.bottom)end
 if self.active then renderer:SetViewport(0,self.viewport)end
 print("[CrescentRender] offscreen-fallback: "..self.failure)
end
function T:Resize(left,top,right,bottom)
 self.left,self.top,self.right,self.bottom=left,top,right,bottom
 self.displayWidth=math.max(1,right-left);self.displayHeight=math.max(1,bottom-top)
 local width=math.max(1,math.floor(self.displayWidth*self.scale+.5))
 local height=math.max(1,math.floor(self.displayHeight*self.scale+.5))
 if self.scale==1 then
  self.width,self.height=width,height
  self.viewport.rect=IntRect(left,top,right,bottom)
  return
 end
 if self.texture and self.width==width and self.height==height then return end
 -- Release the old NanoVG image before replacing its underlying texture.
 self:ReleaseTexture()
 local texture=Texture2D:new()
 local ok,err=pcall(function()
  texture:SetNumLevels(1)
  assert(texture:SetSize(width,height,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),"render target allocation failed")
  texture:SetFilterMode(FILTER_BILINEAR)
 end)
 if not ok then
  texture:Dispose();self:UseNative(err)
  self.width,self.height=self.displayWidth,self.displayHeight
  return
 end
 self.texture=texture;self.width,self.height=width,height
 self.viewport.rect=IntRect(0,0,width,height)
 self.surface=assert(texture:GetRenderSurface(),"render surface missing")
 self.surface:SetViewport(0,self.viewport)
 self.surface:SetUpdateMode(SURFACE_MANUALUPDATE)
 self:Queue()
 print(string.format("[CrescentRender] 3D=%dx%d display=%dx%d scale=%.2f",width,height,self.displayWidth,self.displayHeight,self.scale))
end
function T:SetActive(active)
 if self.active==active then return end
 self.active=active
 if self.scale==1 then renderer:SetViewport(0,active and self.viewport or nil)
 elseif active then self:Queue()end
end
function T:Queue()
 if self.active and self.surface then self.surface:QueueUpdate()end
end
function T:Draw(vg,w,h)
 if not self.active or not self.texture or self.scale==1 then return end
 if self.imageContext and self.imageContext~=vg then self:ReleaseImage()end
 if not self.image then
  self.imageContext=vg;self.image=nvgCreateVideo(vg,self.texture)
  if not self.image or self.image==0 then self:UseNative("NanoVG texture import failed");return end
 end
 nvgSave(vg);nvgIntersectScissor(vg,0,0,w,h)
 nvgBeginPath(vg);nvgRect(vg,0,0,w,h)
 nvgFillPaint(vg,nvgImagePattern(vg,0,0,w,h,0,self.image,1))
 nvgFill(vg);nvgRestore(vg)
end
function T:Info()
 return {requestedScale=self.requestedScale,scale=self.scale,
  width=self.width or 0,height=self.height or 0,
  displayWidth=self.displayWidth or 0,displayHeight=self.displayHeight or 0,
  mode=self.scale==1 and "native" or "offscreen",fallback=self.failure}
end
function T:Stop()
 self.active=false;self:ReleaseTexture();renderer:SetViewport(0,nil)
end
return T
