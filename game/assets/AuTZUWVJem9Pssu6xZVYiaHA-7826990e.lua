-- Transparent land + independent animated ocean + wind-driven tree sprites.
-- UI owns the NanoVG frame and all world/HUD coordinates remain in design units.
local Cache=require("urhox-libs/UI/Core/ImageCache")
local A=require("Game.Art")
local Data=require("Game.HomeIslandData")
local Ocean=require("Game.HomeOcean")
local IslandScene=require("Game.HomeIslandScene")
local W={width=Data.width,height=Data.height,image=Data.image}
local misses=0
local function clamp(n,a,b)return math.max(a,math.min(b,n))end
function W.DefaultZoom(h)return math.max(.4,math.min(.48,h/2300))end
function W.DefaultCamera(h)
 local z=W.DefaultZoom(h)
 return {x=W.width*.52,y=W.height-140-h/(2*z),zoom=z}
end
function W.ToScreen(app,x,y)
 local c=app.camera
 return 225+(x-c.x)*c.zoom,app.h/2+(y-c.y)*c.zoom
end
function W.Clamp(app)
 local c=app.camera;local hx,hy=225/c.zoom,app.h/(2*c.zoom)
 local margin=180
 c.x=hx>=(W.width+margin*2)/2 and W.width/2 or clamp(c.x,hx-margin,W.width+margin-hx)
 c.y=hy>=(W.height+margin*2)/2 and W.height/2 or clamp(c.y,hy-margin,W.height+margin-hy)
end
function W.Pan(app,dx,dy)
 local c=app.camera;c.x=c.x-dx/c.zoom;c.y=c.y-dy/c.zoom;W.Clamp(app)
end
function W.MinZoom(app)return math.min(430/W.width,(app.h-160)/W.height)end
function W.Overview(app)
 app.camera={x=W.width/2,y=W.height/2,zoom=W.MinZoom(app)}
end
-- Entrances are rooted in the independently placed village and forest clearing.
function W.Landmarks()
 local styles={forest={"林间采集","leaf",100,130},coast={"岸边垂钓","anchor",100,120},
  shore={"赶海","shell",74,110},home={"营地","home",74,125},pearls={"开贝小屋","shell",100,105},
  shop={"杂货铺","bag",86,110},sell={"收购摊","fish",86,110},sea={"出海钓鱼","boat",100,125}}
 local result={}
 for _,p in ipairs(Data.landmarks)do
  local s=styles[p.id]
  result[#result+1]={id=p.id,x=p.x,y=p.y,w=s[3],radius=s[4],text=s[1],icon=s[2]}
 end
 return result
end
function W.Image(v,x,y,w,h)
 local north,south=Cache.Get(Data.northImage),Cache.Get(Data.southImage)
 if north<=0 or south<=0 then
  misses=misses+1
  if misses>=120 then Cache.Release(Data.northImage);Cache.Release(Data.southImage);misses=0 end
  return false
 end
 misses=0
 local scale=h/Data.height;local tile=Data.tileHeight*scale
 local seam=y+(Data.blendStart+Data.blendEnd)*.5*scale
 -- Low-cost minimap/fallback; full-resolution renderer crossfades the overlap.
 nvgSave(v);nvgIntersectScissor(v,x,y,w,seam-y)
 nvgBeginPath(v);nvgRect(v,x,y,w,tile)
 nvgFillPaint(v,nvgImagePattern(v,x,y,w,tile,0,north,1));nvgFill(v);nvgRestore(v)
 local sy=y+(Data.height-Data.tileHeight)*scale
 nvgSave(v);nvgIntersectScissor(v,x,seam,w,y+h-seam)
 nvgBeginPath(v);nvgRect(v,x,sy,w,tile)
 nvgFillPaint(v,nvgImagePattern(v,x,sy,w,tile,0,south,1));nvgFill(v);nvgRestore(v)
 return true
end
function W.Update(app,dt)
 if app.mode~="home"or app.modal then return end
 if not app.homeIslandAttempted and Scene then
  app.homeIslandAttempted=true;app.homeIslandScene=IslandScene.new()
 end
 if app.homeIslandScene then
  local ok,err=pcall(function()app.homeIslandScene:Update(app,dt)end)
  if not ok then
   app.homeIslandScene:Stop();app.homeIslandScene=nil
   print("[HomeIsland] retained renderer unavailable: "..tostring(err))
  end
 end
 if not app.homeOceanAttempted and Scene then
  app.homeOceanAttempted=true;app.homeOcean=Ocean.new()
 end
 if app.homeOcean then
  local ok,err=pcall(function()app.homeOcean:Update(app,dt)end)
  if not ok then
   app.homeOcean:Stop();app.homeOcean=nil
   print("[HomeOcean] sailing water unavailable: "..tostring(err))
  end
 end
end
function W.Stop(app)
 if app.homeIslandScene then app.homeIslandScene:Stop();app.homeIslandScene=nil end
 if app.homeOcean then app.homeOcean:Stop();app.homeOcean=nil end
end
-- Match the sailing shader's scatter colour while its retained target is loading.
local function fallbackWater(app,v,w,h)
 A.rect(v,0,0,w,h,{17,123,193,255})
end
local function drawSprites(app,v,w,h)
 local z,t=app.camera.zoom,app.playtime
 for _,tree in ipairs(Data.sprites)do
  local image=Cache.Get(tree.atlas=="tree"and Data.treesImage or Data.buildingsImage)
  local x,y=W.ToScreen(app,tree.x,tree.y);local s=tree.size*z
  if image>0 and x+s/2>0 and x-s/2<w and y>0 and y-s<h then
   A.ellipse(v,x,y-s*.025,s*.24,s*.065,{16,57,39,45})
   nvgSave(v);nvgTranslate(v,x,y)
   local sway=tree.atlas=="tree"and(math.sin(t*1.25+tree.phase)*.021+math.sin(t*2.9+tree.phase)*.005)or 0
   if tree.kind==2 then sway=sway*1.45 end
   nvgTransform(v,tree.mirror and -1 or 1,0,sway,1,0,0)
   local column=(tree.kind-1)%2;local row=math.floor((tree.kind-1)/2)
   nvgBeginPath(v);nvgRect(v,-s/2,-s*.9453125,s,s)
   nvgFillPaint(v,nvgImagePattern(v,-s/2-column*s,-s*.9453125-row*s,s*2,s*2,0,image,1));nvgFill(v)
   nvgRestore(v)
  end
 end
end
function W.MiniLand(v,x,y,w,h)
 if not W.Image(v,x,y,w,h)then return end
 local z=w/W.width
 for _,s in ipairs(Data.sprites)do
  local image=Cache.Get(s.atlas=="tree"and Data.treesImage or Data.buildingsImage)
  if image>0 and s.size*z>3 then
   local size=s.size*z;local xx,yy=x+s.x*z-size/2,y+s.y*z-size*.9453125
   local col,row=(s.kind-1)%2,math.floor((s.kind-1)/2)
   nvgBeginPath(v);nvgRect(v,xx,yy,size,size)
   nvgFillPaint(v,nvgImagePattern(v,xx-col*size,yy-row*size,size*2,size*2,0,image,1));nvgFill(v)
  end
 end
end
function W.MiniWater(v,x,y,r)
 nvgBeginPath(v);nvgCircle(v,x,y,r)
 nvgFillPaint(v,nvgLinearGradient(v,x-r,y-r,x+r,y+r,nvgRGBA(21,191,208,255),nvgRGBA(3,88,151,255)))
 nvgFill(v)
end
function W.Draw(app,v,w,h)
 nvgSave(v);nvgIntersectScissor(v,0,0,w,h)
 if not app.homeOcean or not app.homeOcean:Draw(v,w,h)then fallbackWater(app,v,w,h)end
 if not app.homeIslandScene or not app.homeIslandScene:Draw(v,w,h)then
  local x,y=W.ToScreen(app,0,0);local z=app.camera.zoom
  if W.Image(v,x,y,W.width*z,W.height*z)then drawSprites(app,v,w,h)end
 end
 for _,p in ipairs(app.landmarkLabels or{})do
  if math.abs(p.x-p.lx)+math.abs(p.y-p.ly)>18 then
   A.line(v,{p.x,p.y,p.lx,p.ly},{255,247,218,155},1)
  end
 end
 nvgRestore(v)
end
return W
