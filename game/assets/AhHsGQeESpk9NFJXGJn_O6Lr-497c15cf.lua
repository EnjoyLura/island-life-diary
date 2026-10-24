-- Home-only optical sizing against the selected 941x1674 reference.
local A=require("Game.Art")
local Skin=require("Game.UISkin")
local Cache=require("urhox-libs/UI/Core/ImageCache")
local UI=require("urhox-libs/UI")
local H={}
local INK={15,38,68,255}
-- Home content stays inside its plate, with separate icon/text/edge spacing.
local function label(v,x,y,value,size,color,align,maxWidth)
 if maxWidth then
  nvgFontFace(v,UI.Theme.FontFace("sans","bold"));nvgFontSize(v,size)
  local measured=nvgTextBounds(v,0,0,tostring(value))
  if measured>maxWidth then size=size*maxWidth/measured end
 end
 A.text(v,x,y,value,size,color or INK,align)
end
local function icon(v,name,x,y,w,h)
 nvgSave(v);nvgTranslate(v,x,y);nvgScale(v,1,(h or w)/w)
 A.icon(v,name,0,0,w);nvgRestore(v)
end
function H.DrawGM(v,w,h,down,hover)
 A.circle(v,w/2,h/2+2,w/2-1,{16,55,73,65})
 A.circle(v,w/2,h/2-1,w/2-2,A.cream,{21,77,102,255},1.3)
 A.circle(v,w/2,h/2-1,w/2-4,{0,0,0,0},{33,135,155,255},.8)
 icon(v,"gear",w/2,h/2-1,30,30)
end
function H.Layout(app)
 local top=math.max(18,(app.hudTop or 0)-26)
 local bottom=app.h-18
 local tools=math.max(top+165,math.min(app.h*.59,app.h-286))
 return {top=top,coin={14,top,128,48},energy={284,top,152,52},gm={204,top,44,44},
  island={14,top+54,112,34},bread={320,top+60,116,34},tools=tools,
  mini={9,bottom-176,130,130},whole={22,bottom-36,112,36},
  book={268,bottom-76,84,76},bag={364,bottom-76,74,76},bottom=bottom,
  labelTop=top+108,labelBottom=bottom-104}
end
function H.DefaultZoom(h)return math.min(.68,math.max(.48,h/1370))end
function H.Obstacles(app)
 local l=H.Layout(app)
 return {{x=74,y=l.mini[2]+76,w=144,h=182},{x=420,y=l.tools+82,w=54,h=176},
  {x=353,y=l.bag[2]+34,w=184,h=112}}
end
local function add(app,id,r,props)return app:AddButton(id,r[1],r[2],r[3],r[4],props)end
local function navigation(app,id,r,caption,iconName,action)
 add(app,id,r,{action=action,draw=function(v,w,h,down,hover)
  A.button(v,0,0,w,h,nil,down,hover,false,"BTN-nav")
  if iconName=="book"then icon(v,iconName,w/2,27,62,48)
  else icon(v,iconName,w/2,26,58,52)end
  label(v,w/2,h-15,caption,16,INK,NVG_ALIGN_CENTER)
 end})
end
function H.Build(app)
 local l=H.Layout(app)
 app.landmarks={
  {id="forest",x=500,y=400,w=100,radius=180,text="林间采集",icon="leaf"},
  {id="coast",x=-25,y=896,w=100,radius=135,text="岸边垂钓",icon="anchor"},
  {id="shore",x=1025,y=750,w=74,radius=160,text="赶海",icon="shell"},
  {id="home",x=528,y=958,w=74,radius=160,text="营地",icon="home"},
  {id="pearls",x=190,y=1123,w=100,radius=130,text="开贝小屋",icon="shell"},
  {id="shop",x=325,y=1330,w=86,radius=130,text="杂货铺",icon="bag"},
  {id="sell",x=720,y=1330,w=86,radius=130,text="收购摊",icon="fish"},
  {id="sea",x=725,y=1885,w=100,radius=170,text="出海钓鱼",icon="boat"},
 }
 for _,p in ipairs(app.landmarks)do
  p.h=42;p.bodyH=32
  app:AddButton("landmark_"..p.id,0,0,p.w,p.h,{action=function()app:Landmark(p.id)end,
   draw=function(v,w,h,down)
    if not Skin.Draw(v,"PLT-bubble",0,0,w,p.bodyH)then A.plate(v,0,0,w,p.bodyH)end
    Skin.Draw(v,"PLT-bubble",w/2-7,28,14,14,"pointer-down")
    icon(v,p.icon,18,16,18,18)
    label(v,34,16+(down and 1 or 0),p.text,12,INK,NVG_ALIGN_LEFT,w-48)
   end})
 end
 navigation(app,"book",l.book,"图鉴","book",function()app:OpenModal("encyclopedia",{category="fish",selected=nil})end)
 navigation(app,"cargo",l.bag,"背包","bag",function()app:OpenModal("cargo")end)
 local function reset()app:ResetCamera();app:PositionLandmarks()end
 add(app,"homeMap",l.mini,{draw=function()end,action=reset})
 add(app,"wholeIsland",l.whole,{action=reset,draw=function(v,w,h,down,hover)
  A.button(v,0,0,w,h,nil,down,hover);icon(v,"map",20,h/2-1,26,26)
  label(v,58,h/2-1,"全岛",15,INK,NVG_ALIGN_CENTER)
  A.line(v,{w-23,11,w-23,8,w-19,8},INK,1.5);A.line(v,{w-12,8,w-8,8,w-8,11},INK,1.5)
  A.line(v,{w-23,21,w-23,25,w-19,25},INK,1.5);A.line(v,{w-12,25,w-8,25,w-8,21},INK,1.5)
 end})
 add(app,"islandName",l.island,{action=reset,draw=function(v,w,h,down,hover)
  A.button(v,0,0,w,h,nil,down,hover);icon(v,"home",19,h/2-1,22,22)
  label(v,37,h/2-1,"月牙岛",13.5,INK,NVG_ALIGN_LEFT)
  A.icon(v,"chevron",w-14,h/2-1,12)
 end})
 for i,p in ipairs({{"zoom+","plus",function()app:Zoom(1.2)end},
  {"zoom-","minus",function()app:Zoom(.83)end},{"islandReset","home",reset}})do
  local y=l.tools+(i==1 and 0 or i==2 and 72 or 124)
  add(app,p[1],{400,y,40,40},{action=p[3],draw=function(v,w,h,down,hover)
   A.button(v,0,0,w,h,nil,down,hover,false,"BTN-square");icon(v,p[2],w/2,h/2-1,24,24)
  end})
 end
 add(app,"food",l.energy,{action=function()app:OpenModal("food")end,draw=function(v,w,h,down,hover)
  A.button(v,0,0,w,h,nil,down,hover)
  icon(v,"energy",22,25,34,34);label(v,43,18,"体力",12.5,INK)
  label(v,w-14,18,math.floor(app.profile.stamina).."/100",16,INK,NVG_ALIGN_RIGHT,56)
  A.bar(v,43,h-17,w-57,7,app.profile.stamina/100,{81,194,143,255})
 end})
 add(app,"bread",l.bread,{action=function()app:OpenModal("food")end,draw=function(v,w,h,down,hover)
  A.button(v,0,0,w,h,nil,down,hover)
  icon(v,"bread",18,16,26,26);label(v,35,16,"面包×"..app.profile.bread,12,INK,NVG_ALIGN_LEFT,w-72)
  A.circle(v,w-17,16,9,{24,139,191,255},A.cream,1.3)
  A.line(v,{w-21,16,w-13,16},A.cream,1.8);A.line(v,{w-17,12,w-17,20},A.cream,1.8)
 end})
end
local function minimap(app,v,r)
 local x,y,w=r[1],r[2],r[3];local cx,cy=x+w/2,y+w/2
 A.circle(v,cx,cy,w/2-4,{24,122,163,255})
 local path="Textures/CelWorld/terrain.png";local handle=Cache.Get(path)
 local content=w*.72
 if handle>0 then
  nvgBeginPath(v);nvgRect(v,cx-content/2,cy-content/2,content,content)
  nvgFillPaint(v,nvgImagePattern(v,cx-content/2,cy-content/2,content,content,0,handle,1));nvgFill(v)
 end
 local function project(xx,yy)
  return cx+(xx-500)*.04/54*content,cy+(yy-1000)*.026/54*content
 end
 for _,p in ipairs(app.landmarks or{})do
  local px,py=project(p.x,p.y)
  if(px-cx)^2+(py-cy)^2<(w/2-10)^2 then A.icon(v,p.icon,px,py,p.id=="home"and 15 or 11)end
 end
 local px,py=project(app.camera.x,app.camera.y)
 local rw=math.min(w-48,450*.061/math.max(.1,app.camera.zoom)/54*content)
 local rh=math.min(w-48,app.h*.061/math.max(.1,app.camera.zoom)/.783/54*content)
 local left=math.max(x+24,math.min(x+w-24-rw,px-rw/2));local top=math.max(y+24,math.min(y+w-24-rh,py-rh/2))
 A.line(v,{left,top,left+rw,top,left+rw,top+rh,left,top+rh},A.cream,1.3,true)
 Skin.Draw(v,"NAV-compass",x,y,w,w)
 label(v,cx,y+10,"N",11,A.cream,NVG_ALIGN_CENTER)
end
function H.Draw(app,v)
 local l=H.Layout(app);local r=l.coin
 A.plate(v,r[1],r[2],r[3],r[4]);icon(v,"coin",r[1]+24,r[2]+23,34,34)
 label(v,r[1]+r[3]-14,r[2]+23,app.profile.coins,22,INK,NVG_ALIGN_RIGHT,68)
 minimap(app,v,l.mini)
 Skin.Draw(v,"PLT-resource",400,l.tools+46,40,20,"dark")
 label(v,420,l.tools+55,string.format("%.1f×",app.camera.zoom/H.DefaultZoom(app.h)),10,A.cream,NVG_ALIGN_CENTER,26)
end
return H
