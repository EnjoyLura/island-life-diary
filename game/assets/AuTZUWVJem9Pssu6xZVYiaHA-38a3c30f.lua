-- One continuous illustrated map. Coordinates are shared by art, labels,
-- gestures and minimap; the existing 3D activities keep their own worlds.
local Cache=require("urhox-libs/UI/Core/ImageCache")
local A=require("Game.Art")
local W={width=1000,height=8000/3,image="image/HomeIslandV45/island-long.png"}
local misses=0
local function clamp(n,a,b)return math.max(a,math.min(b,n))end
function W.DefaultZoom(h)return math.max(.45,math.min(.52,h/1800))end
function W.DefaultCamera(h)
 local z=W.DefaultZoom(h)
 return {x=500,y=W.height-55-h/(2*z),zoom=z}
end
function W.ToScreen(app,x,y)
 local c=app.camera
 return 225+(x-c.x)*c.zoom,app.h/2+(y-c.y)*c.zoom
end
function W.Clamp(app)
 local c=app.camera;local hx,hy=225/c.zoom,app.h/(2*c.zoom)
 c.x=hx>=W.width/2 and W.width/2 or clamp(c.x,hx,W.width-hx)
 c.y=hy>=W.height/2 and W.height/2 or clamp(c.y,hy,W.height-hy)
end
function W.Pan(app,dx,dy)
 local c=app.camera;c.x=c.x-dx/c.zoom;c.y=c.y-dy/c.zoom;W.Clamp(app)
end
function W.MinZoom(app)return math.min(430/W.width,(app.h-160)/W.height)end
function W.Overview(app)
 app.camera={x=W.width/2,y=W.height/2,zoom=W.MinZoom(app)}
end
-- Positions recorded from the actual 768x2048 artwork, not the prompt.
function W.Landmarks()
 return {
  {id="forest",x=550,y=735,w=100,radius=130,text="林间采集",icon="leaf"},
  {id="coast",x=203,y=966,w=100,radius=120,text="岸边垂钓",icon="anchor"},
  {id="shore",x=784,y=1105,w=74,radius=110,text="赶海",icon="shell"},
  {id="home",x=581,y=1530,w=74,radius=125,text="营地",icon="home"},
  {id="pearls",x=281,y=1607,w=100,radius=105,text="开贝小屋",icon="shell"},
  {id="shop",x=394,y=1830,w=86,radius=110,text="杂货铺",icon="bag"},
  {id="sell",x=695,y=1840,w=86,radius=110,text="收购摊",icon="fish"},
  {id="sea",x=675,y=2350,w=100,radius=125,text="出海钓鱼",icon="boat"},
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
local glints={{70,245},{900,170},{954,425},{51,590},{930,800},{56,1120},
 {936,1275},{74,1500},{944,1640},{55,1830},{931,2100},{885,2470},
 {125,2495},{370,2585},{48,2230},{725,95},{55,65},{947,2340},
 {78,940},{901,1040},{118,1360},{900,1900},{340,2430},{837,2270}}
function W.Draw(app,v,w,h)
 A.rect(v,0,0,w,h,{5,137,210,255})
 nvgSave(v);nvgIntersectScissor(v,0,0,w,h)
 local x,y=W.ToScreen(app,0,0);local z=app.camera.zoom
 local loaded=W.Image(v,x,y,W.width*z,W.height*z)
 if loaded then
  -- Small world-anchored water glints breathe over the painted surf. No
  -- extra camera, render target, particles, full-screen shader or art copies.
  for i,p in ipairs(glints)do
   local px,py=W.ToScreen(app,p[1],p[2])
   if px>8 and px<w-8 and py>5 and py<h-5 then
    local beat=math.max(0,math.sin(app.playtime*1.15+i*1.73))^4
    if beat>.05 then
     local r=(10+i%3*3)*z
     nvgBeginPath(v);nvgMoveTo(v,px-r,py)
     nvgBezierTo(v,px-r*.35,py+3*z,px+r*.35,py+3*z,px+r,py)
     nvgStrokeColor(v,A.color({231,255,255,math.floor(beat*110)}))
     nvgStrokeWidth(v,math.max(.6,z*1.5));nvgStroke(v)
    end
   end
  end
 end
 for _,p in ipairs(app.landmarkLabels or{})do
  if math.abs(p.x-p.lx)+math.abs(p.y-p.ly)>18 then
   A.line(v,{p.x,p.y,p.lx,p.ly},{255,247,218,155},1)
  end
 end
 nvgRestore(v)
end
return W
