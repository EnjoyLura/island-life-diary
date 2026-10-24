-- Home-only reference layout. All coordinates are logical px in the existing UI tree.
local A=require("Game.Art")
local Skin=require("Game.UISkin")
local Cache=require("urhox-libs/UI/Core/ImageCache")
local H={}
function H.Layout(app)
 local top=math.max(14,(app.hudTop or 0)-24)
 local bottom=app.h-14
 local tools=math.max(top+165,math.min(app.h*.59,app.h-274))
 return {top=top,coin={14,top,128,40},energy={292,top,144,44},gm={204,top,42,42},
  island={14,top+44,104,30},bread={340,top+49,96,30},tools=tools,
  mini={10,bottom-160,126,126},whole={22,bottom-28,106,30},
  book={286,bottom-66,76,66},bag={370,bottom-66,66,66},bottom=bottom,
  labelTop=top+100,labelBottom=bottom-94}
end
function H.DefaultZoom(h)return math.min(.68,math.max(.48,h/1370))end
function H.Obstacles(app)
 local l=H.Layout(app)
 return {{x=73,y=l.mini[2]+73,w=142,h=174},{x=418,y=l.tools+64,w=52,h=178},
  {x=362,y=l.bag[2]+33,w=160,h=82}}
end
local function add(app,id,r,props)return app:AddButton(id,r[1],r[2],r[3],r[4],props)end
local function navigation(app,id,r,text,icon,action)
 add(app,id,r,{action=action,draw=function(v,w,h,down,hover)
  A.button(v,0,0,w,h,nil,down,hover,false,"BTN-nav")
  A.icon(v,icon,w/2,24,43);A.text(v,w/2,h-13,text,16,A.ink,NVG_ALIGN_CENTER)
 end})
end
function H.Build(app)
 local l=H.Layout(app)
 app.landmarks={
  {id="forest",x=500,y=400,w=98,radius=180,text="林间采集",icon="leaf"},
  {id="coast",x=-25,y=896,w=96,radius=135,text="岸边垂钓",icon="anchor"},
  {id="shore",x=1025,y=750,w=78,radius=160,text="赶海",icon="shell"},
  {id="home",x=528,y=958,w=78,radius=160,text="营地",icon="home"},
  {id="pearls",x=190,y=1123,w=96,radius=130,text="开贝小屋",icon="shell"},
  {id="shop",x=325,y=1330,w=88,radius=130,text="杂货铺",icon="bag"},
  {id="sell",x=720,y=1330,w=88,radius=130,text="收购摊",icon="fish"},
  {id="sea",x=725,y=1885,w=104,radius=170,text="出海钓鱼",icon="boat"},
 }
 for _,p in ipairs(app.landmarks)do
  app:AddButton("landmark_"..p.id,0,0,p.w,42,{action=function()app:Landmark(p.id)end,
   draw=function(v,w,h,down)
    if not Skin.Draw(v,"PLT-bubble",0,0,w,32)then A.plate(v,0,0,w,32)end
    Skin.Draw(v,"PLT-bubble",w/2-7,28,14,14,"pointer-down")
    A.icon(v,p.icon,16,15,23);A.text(v,(w+24)/2,15+(down and 1 or 0),p.text,13,A.ink,NVG_ALIGN_CENTER)
   end})
 end
 navigation(app,"book",l.book,"图鉴","book",function()app:OpenModal("encyclopedia",{category="fish",selected=nil})end)
 navigation(app,"cargo",l.bag,"背包","bag",function()app:OpenModal("cargo")end)
 local function reset()app:ResetCamera();app:PositionLandmarks()end
 add(app,"homeMap",l.mini,{draw=function()end,action=reset})
 add(app,"wholeIsland",l.whole,{text="全岛",icon="map",size=15,action=reset})
 add(app,"islandName",l.island,{text="月牙岛  ›",icon="home",iconSize=21,size=14,action=reset})
 for i,p in ipairs({{"zoom+","plus",function()app:Zoom(1.2)end},
  {"zoom-","minus",function()app:Zoom(.83)end},{"islandReset","home",reset}})do
  local y=l.tools+(i==1 and 0 or i==2 and 62 or 106)
  add(app,p[1],{400,y,36,38},{icon=p[2],iconOnly=true,iconSize=28,action=p[3]})
 end
 add(app,"food",l.energy,{action=function()app:OpenModal("food")end,draw=function(v,w,h,down,hover)
  A.button(v,0,0,w,h,nil,down,hover)
  A.icon(v,"energy",22,22,33);A.text(v,43,12,"体力",11,A.ink)
  A.text(v,w-10,15,math.floor(app.profile.stamina).."/100",17,A.ink,NVG_ALIGN_RIGHT)
  A.bar(v,42,h-14,w-55,8,app.profile.stamina/100,{81,194,143,255})
 end})
 add(app,"bread",l.bread,{action=function()app:OpenModal("food")end,draw=function(v,w,h,down,hover)
  A.button(v,0,0,w,h,nil,down,hover)
  A.icon(v,"bread",15,14,24);A.text(v,29,14,"面包×"..app.profile.bread,12,A.ink)
  A.icon(v,"plus",w-13,14,20)
 end})
end
local function minimap(app,v,r)
 local x,y,w=r[1],r[2],r[3];local cx,cy=x+w/2,y+w/2
 A.circle(v,cx,cy,w/2-4,{24,122,163,255})
 local path="Textures/CelWorld/terrain.png";local handle=Cache.Get(path)
 if handle>0 then
  nvgBeginPath(v);nvgCircle(v,cx,cy,w/2-7)
  nvgFillPaint(v,nvgImagePattern(v,x+9,y+9,w-18,w-18,0,handle,1));nvgFill(v)
 end
 local function project(xx,yy)
  return x+9+((xx-500)*.04/54+.5)*(w-18),y+9+(.5+(yy-1000)*.026/54)*(w-18)
 end
 for _,p in ipairs(app.landmarks or{})do
  local px,py=project(p.x,p.y)
  if(px-cx)^2+(py-cy)^2<(w/2-10)^2 then A.icon(v,p.icon,px,py,p.id=="home"and 15 or 11)end
 end
 local px,py=project(app.camera.x,app.camera.y)
 local rw=math.min(w-48,450*.061/math.max(.1,app.camera.zoom)/54*(w-18))
 local rh=math.min(w-48,app.h*.061/math.max(.1,app.camera.zoom)/.783/54*(w-18))
 local left=math.max(x+24,math.min(x+w-24-rw,px-rw/2));local top=math.max(y+24,math.min(y+w-24-rh,py-rh/2))
 A.line(v,{left,top,left+rw,top,left+rw,top+rh,left,top+rh},A.cream,1.3,true)
 Skin.Draw(v,"NAV-compass",x,y,w,w)
 A.text(v,cx,y+8,"N",13,A.cream,NVG_ALIGN_CENTER)
end
function H.Draw(app,v)
 local l=H.Layout(app);local r=l.coin
 A.plate(v,r[1],r[2],r[3],r[4]);A.icon(v,"coin",r[1]+22,r[2]+19,33)
 A.text(v,r[1]+r[3]-10,r[2]+20,app.profile.coins,22,A.ink,NVG_ALIGN_RIGHT)
 minimap(app,v,l.mini)
 A.caption(v,400,l.tools+40,36,21)
 A.text(v,418,l.tools+50,string.format("%.1f×",app.camera.zoom/H.DefaultZoom(app.h)),11,A.cream,NVG_ALIGN_CENTER)
end
return H
