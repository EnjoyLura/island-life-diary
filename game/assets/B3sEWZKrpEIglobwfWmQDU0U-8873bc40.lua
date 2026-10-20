local A=require("Game.Art")
local World=require("Game.World")
local State=require("Game.State")
local Catalog=require("Game.Catalog")
local SeaChart=require("Game.SeaChart")
local H={}
-- All fixed top controls use the same offset as their painted information.
-- Bottom actions and world-anchored interaction bubbles keep their positions.
local TOP_CONTROLS={food=true,["return"]=true,fuelAd=true,hullAd=true,capacityAd=true,
 ["zoom+"]=true,["zoom-"]=true,islandReset=true}
local function button(app,id,x,y,w,h,text,icon,action,tone,sub)
 if TOP_CONTROLS[id]then y=y+(app.hudTop or 0)end
 return app:AddButton(id,x,y,w,h,{text=text,icon=icon,action=action,tone=tone,sub=sub})
end
local function actionButton(app)
 local f=app.fish
 app:AddButton("cast",324,app.h-146,110,110,{
  press=function(e)app:CastPress(e)end,
  release=function()app:CastRelease(false)end,
  cancel=function()app:CastRelease(true)end,
  draw=function(v,w,h,down)
   local gold=f.stage=="hooked";local y=down and 3 or 0
   A.circle(v,w/2,h/2+4,53,A.ink)
   A.circle(v,w/2,h/2+y,51,gold and {255,161,39,255} or {255,210,99,255},A.ink,3)
   A.circle(v,w/2,h/2+y,45,{0,0,0,0},{255,244,185,255},2)
   A.icon(v,gold and "fish" or "rod",w/2,h*.35+y,34)
   local text=(f.stage=="idle" or f.stage=="aim") and "抛竿" or f.stage=="hooked" and "按住收线" or "收竿"
   A.text(v,w/2,h*.71+y,text,17,A.ink,NVG_ALIGN_CENTER)
  end})
end
function H.build(app)
 local h=app.h
 if app.mode=="map" then SeaChart.Build(app);return end
 local cargo=function()app:OpenModal("cargo")end
 local book=function()app:OpenModal("encyclopedia",{category=app.mode=="shore" and "shore" or "fish",selected=nil})end
 local food=function()app:OpenModal("food")end
 if app.mode=="home" then
  app.landmarks={
   {id="forest",x=500,y=400,w=90,radius=180,text="林间小径",icon="lock"},
   {id="coast",x=-25,y=896,w=94,radius=135,text="岸边垂钓",icon="rod"},
   {id="shore",x=1025,y=750,w=86,radius=160,text="去赶海",icon="bucket"},
   {id="home",x=528,y=958,w=70,radius=160,text="小屋",icon="home"},
   {id="pearls",x=190,y=1123,w=80,radius=130,text="开贝小铺",icon="lock"},
   {id="shop",x=325,y=1330,w=76,radius=130,text="杂货铺",icon="bag"},
   {id="sell",x=720,y=1330,w=94,radius=130,text="收购摊",icon="coin"},
   {id="sea",x=725,y=1885,w=116,radius=170,text="开船出海",icon="boat"},
  }
  if not app.scene3d then
   -- The legacy vector fallback uses its original 2D map coordinates.
   app.landmarks[1].y=270;app.landmarks[2].x=170;app.landmarks[2].y=520
   app.landmarks[3].x=795;app.landmarks[3].y=700
   app.landmarks[8].x=650;app.landmarks[8].y=1710
  end
  for _,v in ipairs(app.landmarks) do
   local p=v
   if app.scene3d then
    p.w=p.id=="sea" and 90 or math.min(p.w,78)
    app:AddButton("landmark_"..p.id,0,0,p.w,40,{action=function()app:Landmark(p.id)end,
     draw=function(vg,w,hh,down)
      A.rect(vg,0,8,w,25,p.id=="sea" and A.gold or {255,248,222,235},7,A.ink,1.3)
      A.icon(vg,p.icon,13,20,17);A.text(vg,w*.60,20,p.text,11,A.ink,NVG_ALIGN_CENTER)
     end})
   else button(app,"landmark_"..p.id,0,0,p.w,36,p.text,p.icon,function()app:Landmark(p.id)end,p.id=="sea" and "gold" or nil)end
  end
  button(app,"book",20,h-103,82,77,"图鉴","book",book)
  button(app,"cargo",115,h-103,82,77,"收获","bag",cargo)
  button(app,"shop",210,h-103,82,77,"杂货铺","gear",function()app:OpenModal("shop")end)
  button(app,"help",305,h-103,125,77,"玩法说明","compass",function()app:OpenModal("help")end)
  button(app,"zoom+",398,148,36,36,"+",nil,function()app:Zoom(1.2)end)
  button(app,"zoom-",398,192,36,36,"−",nil,function()app:Zoom(.83)end)
  if app.scene3d then
   button(app,"islandReset",398,237,36,36,"全岛",nil,function()app:ResetCamera();app:PositionLandmarks()end)
  end
  button(app,"food",270,21,164,51,function()return math.floor(app.profile.stamina).." / 100"end,"energy",food,"dark")
 elseif app.mode=="sailing" then
  button(app,"return",16,102,92,36,"返航","home",function()app:OpenModal("return")end)
  button(app,"fuelAd",201,76,108,25,"补给燃料","video",function()app:OpenModal("ads")end,nil)
  button(app,"hullAd",322,76,112,25,"修理小船","video",function()app:OpenModal("ads")end,nil)
   app:AddButton("compass",14,h-147,132,132,{draw=function(v,w,hh)H.compass(app,v,w,hh)end,
    action=function()app:SetMode("map");app:Toast("鱼群位置为大致范围 · 留意礁石",3)end})
   button(app,"book",157,h-109,73,79,"图鉴","book",book)
   button(app,"cargo",239,h-109,73,79,"渔获","bag",cargo)
   button(app,"fish",321,h-109,113,79,"开始钓鱼","rod",function()app:StartFishing()end,"gold")
 else
  button(app,"food",270,21,164,51,function()return math.floor(app.profile.stamina).." / 100"end,"energy",food,"dark")
  button(app,"back",16,h-80,76,50,"退出","back",function()
   if app.mode=="fishing" then app:ExitFishing() else app:OpenModal("return") end
  end)
  if app.mode=="fishing" then
   button(app,"book",157,h-111,73,79,"图鉴","book",book)
   button(app,"cargo",239,h-111,73,79,"渔获","bag",cargo);actionButton(app)
  else
   button(app,"book",265,h-111,77,79,"图鉴","book",book)
   button(app,"cargo",353,h-111,81,79,"收获","bucket",cargo)
   -- The joystick has its own hit target, so it never needs an avatar model.
   app:AddButton("move",18,h-230,130,130,{draw=function()end,
    press=function(e)local x,y=app:Local(e);app.joy={active=true,x=83,y=h-165,dx=0,dy=0,pointer=e.pointerId};app.pointers[e.pointerId]={x=x,y=y,lastX=x,lastY=y,startX=x,startY=y,time=app.time}end})
   local t=app.nearTarget
   if t and not app.shore.action then
    local target=t
    button(app,"context",150,h*.45,142,46,t.kind=="hole" and "撒盐引出" or t.kind=="mound" and "挖开看看" or "夹起收获",
     t.kind=="hole" and "salt" or t.kind=="mound" and "shovel" or "bucket",function()app:Interact(target)end,"gold")
    if t.kind=="hole" then button(app,"contextDig",300,h*.45,80,46,"挖开","shovel",function()app:Interact(target,"dig")end) end
   end
  end
 end
 if app.mode~="home" and app.mode~="map" then
  button(app,"capacityAd",16,78,152,28,"容量 ×2","video",function()app:OpenModal("ads")end)
 end
end
function H.positionContext(app)
 if not app.nearTarget then return end
 local x,y=app:ScreenPoint(app.nearTarget.x,app.nearTarget.y)
 local b=app.buttons.context
 if b then b:SetStyle({left=math.max(18,math.min(290,x-71))*app.scale,top=(y-77)*app.scale}) end
 local d=app.buttons.contextDig
 if d then d:SetStyle({left=math.max(18,math.min(352,x+79))*app.scale,top=(y-77)*app.scale}) end
end
function H.compass(app,v,w,h)
 A.circle(v,w/2,h/2+3,64,A.ink);A.circle(v,w/2,h/2,62,{221,174,87,255},A.ink,2)
 A.circle(v,w/2,h/2,57,{35,129,167,255},A.cream,2)
 nvgSave(v);nvgIntersectScissor(v,13,13,w-26,h-26)
 if not app.scene3d then World.image(v,"image/crescent/sea.jpg",13,13,w-26,h-26)end
 for _,r in ipairs(app.reefs)do
  local x=w/2+(r.x-app.boat.x)*.1;local y=h/2+(r.y-app.boat.y)*.1
  if (x-w/2)^2+(y-h/2)^2<46^2 then A.ellipse(v,x,y,r.radius*.045,r.radius*.035,{137,158,142,255})end
 end
 for _,s in ipairs(app.fishSchools) do
  local x=w/2+(s.x-app.boat.x)*.1;local y=h/2+(s.y-app.boat.y)*.1
  if (x-w/2)^2+(y-h/2)^2<45^2 then A.ellipse(v,x,y,5,3,{24,64,93,190}) end
 end
 nvgRestore(v)
 nvgSave(v);nvgTranslate(v,w/2,h/2);nvgRotate(v,app.boat.heading)
 A.poly(v,{0,-17,10,11,0,6,-10,11},A.cream,A.ink,2);nvgRestore(v)
 for _,d in ipairs({{"N",66,13},{"S",66,119},{"W",13,66},{"E",119,66}}) do A.text(v,d[2],d[3],d[1],12,A.cream,NVG_ALIGN_CENTER) end
 A.circle(v,18,h-15,15,A.cream,A.ink,2);A.icon(v,"compass",18,h-15,19)
end
local function capacity(app,v)
 nvgSave(v);nvgTranslate(v,0,app.hudTop or 0)
 local used,cap=State.used(app.profile),State.capacity(app.profile)
 A.plate(v,14,21,177,51,"dark");A.icon(v,app.mode=="shore" and "bucket" or "bag",39,45,29)
 A.text(v,64,38,app.mode=="shore" and "水桶容量" or "渔获容量",11,{199,227,225,255})
 A.text(v,174,51,used.." / "..cap,19,A.cream,NVG_ALIGN_RIGHT)
 A.bar(v,65,61,108,5,used/math.max(1,cap),used>=cap and {243,131,72,255} or {82,198,161,255})
 nvgRestore(v)
end
local function joystick(app,v,h)
 local j=app.joy
 if not j.active and app.mode~="shore" then return end
 local x,y=j.active and j.x or 83,j.active and j.y or h-165
 A.circle(v,x,y,49,{18,48,76,100},{216,251,245,150},1.5)
 A.circle(v,x,y,33,{14,51,80,50},{214,244,241,55},1)
 for i=0,3 do
  nvgSave(v);nvgTranslate(v,x,y);nvgRotate(v,i*math.pi/2)
  A.poly(v,{0,-42,-4,-36,4,-36},{230,250,239,145});nvgRestore(v)
 end
 A.circle(v,x+j.dx*30,y+j.dy*30,20,{225,244,239,215},A.cream,2)
end
function H.draw(app,v,w,h)
 if app.mode=="map" then SeaChart.Draw(app,v);return end
 local top=app.hudTop or 0
 if app.mode=="home" then
  nvgSave(v);nvgTranslate(v,0,top)
  A.plate(v,14,21,147,51,"dark");A.icon(v,"coin",39,45,31)
  A.text(v,143,46,app.profile.coins,21,A.cream,NVG_ALIGN_RIGHT)
  A.plate(v,14,86,215,32,"dark");A.text(v,27,101,"月牙岛",17,A.cream)
  A.text(v,216,102,"海风晴好 · 随心出发",10,{188,230,226,255},NVG_ALIGN_RIGHT)
  nvgRestore(v)
  A.rect(v,66,h-143,318,26,{18,46,66,180},13)
  A.text(v,225,h-130,"拖动环顾小岛  ·  双指缩放  ·  点地标进入",11,A.cream,NVG_ALIGN_CENTER)
 else
  capacity(app,v)
  if app.mode=="sailing" then
   local t=app.profile.trip
   nvgSave(v);nvgTranslate(v,0,top)
   for _,p in ipairs({{201,108,"fuel","燃料",t.fuel,{232,187,72,255}},{322,112,"hull","耐久",t.hull,{93,201,147,255}}}) do
    A.plate(v,p[1],21,p[2],51,"dark");A.icon(v,p[3],p[1]+18,40,22)
    A.text(v,p[1]+36,35,p[4],10,{199,227,225,255});A.text(v,p[1]+p[2]-10,46,math.ceil(p[5]).."%",15,A.cream,NVG_ALIGN_RIGHT)
    A.bar(v,p[1]+10,59,p[2]-20,5,p[5]/100,p[6])
   end
   nvgRestore(v)
   local s=app.shark;local x,y=app:ScreenPoint(s.x,s.y)
   if x>-80 and x<530 and y>-80 and y<h+80 then
    if not app.scene3d then
     nvgSave(v);nvgTranslate(v,x,y);nvgRotate(v,s.phase)
     World.drawFish(v,0,0,100,"shark",app.playtime,true)
     A.poly(v,{-7,0,4,-24,10,0},{49,73,91,255},A.cream,1.2);nvgRestore(v)
    end
    if math.abs(x-225)<160 and math.abs(y-h/2)<180 then A.text(v,x,y-35,"小心鲨鱼",13,A.cream,NVG_ALIGN_CENTER) end
   end
   if not app.joy.active then
    A.rect(v,151,h-157,282,26,{14,51,72,170},13)
    A.text(v,292,h-144,"拖动开船 · 双指缩放 · 靠近鱼影",11,A.cream,NVG_ALIGN_CENTER)
   end
  elseif app.mode=="fishing" then
   local f=app.fish
   local status=f.stage=="idle" and "寻找鱼影，选择落点" or f.stage=="aim" and "松手抛竿" or f.stage=="waiting" and "静候咬钩…" or f.stage=="hooked" and "上钩了！保持合适力度" or "抛竿中…"
   A.rect(v,123,109+top,310,31,{17,61,81,175},15);A.text(v,278,125+top,status,13,A.cream,NVG_ALIGN_CENTER)
   if f.stage=="hooked" then
    local x,y=379,h-180
    -- Arc at the reel: cyan slack, green safe band, coral high tension.
    for i=0,39 do
     local q=i/39;local a=math.pi*1.05+q*math.pi*.9;local b=a+.055
     local color={63,188,215,255}
     if q>=.32 then color={102,210,130,255} end
     if q>.72 then color={245,135,67,255} end
     A.line(v,{x+math.cos(a)*61,y+math.sin(a)*61,x+math.cos(b)*61,y+math.sin(b)*61},color,10)
    end
    local angle=math.pi*1.05+f.power*math.pi*.9
    A.line(v,{x+math.cos(angle)*50,y+math.sin(angle)*50,x+math.cos(angle)*72,y+math.sin(angle)*72},A.cream,4)
    A.rect(v,281,h-285,153,31,{22,53,70,230},12)
    A.text(v,357,h-270,f.power>.72 and "松手缓力" or f.power<.32 and "按住加力" or "完美力度 · 溜鱼中",11,A.cream,NVG_ALIGN_CENTER)
    A.bar(v,100,172+top,250,11,f.progress,{255,202,78,255})
    A.text(v,225,195+top,"收线进度 "..math.floor(f.progress*100).."%",12,A.cream,NVG_ALIGN_CENTER)
    if f.danger>1 then A.text(v,225,221+top,"危险累积 "..string.format("%.1f",f.danger).." / 4",12,{255,223,168,255},NVG_ALIGN_CENTER) end
   elseif f.stage=="idle" then
    A.rect(v,100,h-169,320,26,{17,55,72,160},13)
    A.text(v,260,h-156,"拖动看风景 · 点按抛竿 · 长按拖动瞄准",10,A.cream,NVG_ALIGN_CENTER)
   end
  else
   nvgSave(v);nvgTranslate(v,0,top)
   A.rect(v,221,90,213,31,{27,64,72,180},15)
   A.icon(v,"salt",241,105,19);A.text(v,258,105,"盐 ×"..app.profile.salt.."   铁锹 "..(app.profile.shovel and "已携带" or "未携带"),11,A.cream)
   A.text(v,225,163,"月牙滩 · 退潮时光",17,A.cream,NVG_ALIGN_CENTER)
   nvgRestore(v)
   if not app.nearTarget then
    A.rect(v,172,h-161,262,26,{51,63,59,170},13);A.text(v,303,h-148,"移动探索 · 靠近后点击气泡拾取",10,A.cream,NVG_ALIGN_CENTER)
   end
  end
  joystick(app,v,h)
 end
end
return H
