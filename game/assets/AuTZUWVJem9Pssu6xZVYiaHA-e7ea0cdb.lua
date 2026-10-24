-- Transparent land + independent animated ocean + wind-driven tree sprites.
-- UI owns the NanoVG frame and all world/HUD coordinates remain in design units.
local Cache=require("urhox-libs/UI/Core/ImageCache")
local A=require("Game.Art")
local Data=require("Game.HomeIslandData")
local Ocean=require("Game.HomeOcean")
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
-- Entrances mapped against the actual NEW image, not V45's composition.
function W.Landmarks()
 return {
  {id="forest",x=W.width*.565,y=W.height*.253,w=100,radius=130,text="林间采集",icon="leaf"},
  {id="coast",x=W.width*.116,y=W.height*.444,w=100,radius=120,text="岸边垂钓",icon="anchor"},
  {id="shore",x=W.width*.82,y=W.height*.378,w=74,radius=110,text="赶海",icon="shell"},
  {id="home",x=W.width*.53,y=W.height*.403,w=74,radius=125,text="营地",icon="home"},
  {id="pearls",x=W.width*.30,y=W.height*.487,w=100,radius=105,text="开贝小屋",icon="shell"},
  {id="shop",x=W.width*.28,y=W.height*.581,w=86,radius=110,text="杂货铺",icon="bag"},
  {id="sell",x=W.width*.68,y=W.height*.658,w=86,radius=110,text="收购摊",icon="fish"},
  {id="sea",x=W.width*.565,y=W.height*.905,w=100,radius=125,text="出海钓鱼",icon="boat"},
 }
end
function W.Image(v,x,y,w,h)
 local handle=Cache.Get(W.image)
 if handle<=0 then
  misses=misses+1
  if misses>=120 then Cache.Release(W.image);misses=0 end
  return false
 end
 misses=0
 nvgBeginPath(v);nvgRect(v,x,y,w,h)
 nvgFillPaint(v,nvgImagePattern(v,x,y,w,h,0,handle,1));nvgFill(v)
 return true
end
function W.Update(app,dt)
 if app.mode~="home"or app.modal then return end
 if not app.homeOceanAttempted and Scene then
  app.homeOceanAttempted=true;app.homeOcean=Ocean.new()
 end
 if app.homeOcean then
  local ok,err=pcall(function()app.homeOcean:Update(app,dt)end)
  if not ok then
   app.homeOcean:Stop();app.homeOcean=nil
   print("[HomeOcean] using animated 2D fallback: "..tostring(err))
  end
 end
end
function W.Stop(app)
 if app.homeOcean then app.homeOcean:Stop();app.homeOcean=nil end
end
-- Available while the render target is loading, and on unsupported backends.
-- Mirrored tiles keep all four edges continuous without modifying the PNG.
local function fallbackWater(app,v,w,h)
 A.rect(v,0,0,w,h,{7,137,202,255})
 local image=Cache.Get(Data.waterImage);if image<=0 then return end
 local z=app.camera.zoom;local size=680*z
 local ox,oy=W.ToScreen(app,-app.playtime*5,app.playtime*3)
 local ix,iy=math.floor(-ox/size),math.floor(-oy/size)
 for j=iy,iy+math.ceil(h/size)do for i=ix,ix+math.ceil(w/size)do
  local x,y=ox+i*size,oy+j*size
  nvgSave(v);nvgTranslate(v,x+(i%2==1 and size or 0),y+(j%2==1 and size or 0))
  nvgScale(v,i%2==1 and -1 or 1,j%2==1 and -1 or 1)
  nvgBeginPath(v);nvgRect(v,0,0,size+.5,size+.5)
  nvgFillPaint(v,nvgImagePattern(v,0,0,size,size,0,image,1));nvgFill(v);nvgRestore(v)
 end end
 -- A moving shore ribbon remains present in the compatibility path.
 for layer=1,3 do
  local phase=(app.playtime*.12+layer/3)%1
  nvgBeginPath(v)
  for i,p in ipairs(Data.coast)do
   local prev=Data.coast[(i-2)%#Data.coast+1];local next=Data.coast[i%#Data.coast+1]
   local dx,dy=next.x-prev.x,next.y-prev.y;local len=math.sqrt(dx*dx+dy*dy)
   local reach=8+phase*65+math.sin(i*.7+app.playtime)*5
   local px,py=W.ToScreen(app,p.x+dy/len*reach,p.y-dx/len*reach)
   if i==1 then nvgMoveTo(v,px,py)else nvgLineTo(v,px,py)end
  end
  nvgClosePath(v);nvgStrokeColor(v,nvgRGBA(219,255,255,math.floor((1-phase)*100)))
  nvgStrokeWidth(v,math.max(.7,3*z));nvgStroke(v)
 end
end
local function drawTrees(app,v,w,h)
 local image=Cache.Get(Data.treesImage);if image<=0 then return end
 local z,t=app.camera.zoom,app.playtime
 for _,tree in ipairs(Data.trees)do
  local x,y=W.ToScreen(app,tree.x,tree.y);local s=tree.size*z
  if x+s/2>0 and x-s/2<w and y>0 and y-s<h then
   A.ellipse(v,x,y-s*.025,s*.24,s*.065,{16,57,39,45})
   nvgSave(v);nvgTranslate(v,x,y)
   local sway=math.sin(t*1.25+tree.phase)*.021+math.sin(t*2.1+tree.phase*.37)*.008
   if tree.kind==2 then sway=sway*1.45 end
   nvgTransform(v,tree.mirror and -1 or 1,0,sway,1,0,0)
   local column=(tree.kind-1)%2;local row=math.floor((tree.kind-1)/2)
   nvgBeginPath(v);nvgRect(v,-s/2,-s,s,s)
   nvgFillPaint(v,nvgImagePattern(v,-s/2-column*s,-s-row*s,s*2,s*2,0,image,1));nvgFill(v)
   nvgRestore(v)
  end
 end
end
function W.MiniWater(v,x,y,r)
 local image=Cache.Get(Data.waterImage)
 nvgBeginPath(v);nvgCircle(v,x,y,r)
 if image>0 then nvgFillPaint(v,nvgImagePattern(v,x-r,y-r,r*2,r*2,0,image,1))
 else nvgFillColor(v,nvgRGBA(5,137,210,255))end
 nvgFill(v)
end
function W.Draw(app,v,w,h)
 nvgSave(v);nvgIntersectScissor(v,0,0,w,h)
 if not app.homeOcean or not app.homeOcean:Draw(v,w,h)then fallbackWater(app,v,w,h)end
 local x,y=W.ToScreen(app,0,0);local z=app.camera.zoom
 if W.Image(v,x,y,W.width*z,W.height*z)then drawTrees(app,v,w,h)end
 for _,p in ipairs(app.landmarkLabels or{})do
  if math.abs(p.x-p.lx)+math.abs(p.y-p.ly)>18 then
   A.line(v,{p.x,p.y,p.lx,p.ly},{255,247,218,155},1)
  end
 end
 nvgRestore(v)
end
return W
