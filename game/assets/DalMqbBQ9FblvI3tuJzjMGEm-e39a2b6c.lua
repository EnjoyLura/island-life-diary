-- Public-browser state bridge. The native clear-only view preserves UI alpha.
local Settings=require("Game.RenderSettings")
local B={enabled=Settings.homeThree,active=false,clock=1}
function B.Init()
 if B.scene then return end
 B.scene=Scene();B.scene:CreateComponent("Octree")
 B.camera=B.scene:CreateChild("HomeCompositeClear"):CreateComponent("Camera")
 B.viewport=Viewport:new(B.scene,B.camera)
 local path=B.viewport:GetRenderPath():Clone()
 assert(path:Load(assert(cache:GetResource("XMLFile","RenderPaths/HomeTransparent.xml"))))
 B.viewport:SetRenderPath(path)
end
function B.Update(app,dt)
 if not B.enabled then return end
 local active=app.mode=="home"and not app.modal
 if not active then
  if B.active then
   print('[CrescentHomeOcean]{"active":false}')
   -- Activity scenes have already restored their viewport; do not remove it.
   if app.modal then renderer:SetViewport(0,nil)end
  end
  B.active=false;B.key=nil;return
 end
 B.Init()
 -- Called after Scene3D:Update, which suspends the activity view on entry.
 renderer:SetViewport(0,B.viewport)
 B.clock=B.clock+dt
 local c=app.camera
 local key=string.format("%.3f/%.3f/%.5f/%.3f/%.3f/%.3f/%.3f",c.x,c.y,c.zoom,app.h,app.x,app.y,app.scale)
 if B.active and key==B.key and B.clock<1/30 then return end
 B.clock=0;B.key=key;B.active=true
 print("[CrescentHomeOcean]"..cjson.encode({active=true,cx=c.x,cy=c.y,zoom=c.zoom,
  height=app.h,time=app.playtime,left=app.x,top=app.y,scale=app.scale}))
end
function B.Stop()
 if B.active then print('[CrescentHomeOcean]{"active":false}')end
 B.active=false;B.scene=nil;B.camera=nil;B.viewport=nil;B.key=nil
end
return B
