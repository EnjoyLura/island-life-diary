local A=require("Game.Art")
local Skin=require("Game.UISkin")
local World=require("Game.World")
local State=require("Game.State")
local Catalog=require("Game.Catalog")
local SeaChart=require("Game.SeaChart")
local ForestWorld=require("Game.ForestWorld")
---@class IslandHUD
---@field build fun(app:IslandApp)
---@field draw fun(app:IslandApp,v:any,w:number,h:number)
---@field positionContext fun(app:IslandApp)
local Home=require("Game.HomeUI")
local H={}
-- All fixed top controls use the same offset as their painted information.
-- Bottom actions and world-anchored interaction bubbles keep their positions.
local TOP_CONTROLS={food=true,["return"]=true,fuelAd=true,hullAd=true,capacityAd=true,
 ["zoom+"]=true,["zoom-"]=true,islandReset=true}
local function button(app,id,x,y,w,h,text,icon,action,tone,sub)
 if TOP_CONTROLS[id]then y=y+(app.hudTop or 0)end
 return app:AddButton(id,x,y,w,h,{text=text,icon=icon,iconOnly=icon~=nil and w<=44 and h<=44,action=action,tone=tone,sub=sub})
end
local function staminaButton(app,food)
 local b=button(app,"food",270,21,164,51,"","energy",food)
 b.props.draw=function(v,w,h,down,hover)
  A.button(v,0,0,w,h,nil,down,hover)
  A.icon(v,"energy",23,23,29)
  A.text(v,w-13,22,math.floor(app.profile.stamina).." / 100",18,A.ink,NVG_ALIGN_RIGHT)
  A.bar(v,51,h-12,w-65,6,app.profile.stamina/100,{81,194,143,255})
 end
end
local function actionButton(app)
 local f=app.fish
 app:AddButton("cast",324,app.h-146,110,110,{
  press=function(e)app:CastPress(e)end,
  release=function()app:CastRelease(false)end,
  cancel=function()app:CastRelease(true)end,
  draw=function(v,w,h,down,hover)
   local gold=f.stage=="hooked";local y=down and 3 or 0
   if not Skin.Button(v,0,0,w,h,"gold",down,hover,false,"BTN-action")then
   A.circle(v,w/2,h/2+4,53,A.ink)
   A.circle(v,w/2,h/2+y,51,gold and {255,161,39,255} or {255,210,99,255},A.ink,3)
   A.circle(v,w/2,h/2+y,45,{0,0,0,0},{255,244,185,255},2)
   end
   A.icon(v,gold and "reel" or "rod",w/2,h*.35+y,34)
   local text=f.stage=="aim" and "松手抛出" or f.stage=="idle" and "抛竿" or f.stage=="hooked" and "按住收线" or "收竿"
   A.text(v,w/2,h*.71+y,text,17,A.ink,NVG_ALIGN_CENTER)
  end})
end
function H.build(app)
 local h=app.h
 if app.mode=="map" then SeaChart.Build(app);return end
 local cargo=function()app:OpenModal("cargo")end
 local book=function()app:OpenModal("encyclopedia",{category=app.mode=="forest"and "forest"or app.mode=="shore" and "shore" or "fish",selected=nil})end
 local food=function()app:OpenModal("food")end
 if app.mode=="home" then
  Home.Build(app)
 elseif app.mode=="sailing" then
  button(app,"return",16,102,92,36,"返航","home",function()app:OpenModal("return")end)
  button(app,"fuelAd",201,76,108,25,"补给燃料","video",function()app:OpenModal("ads")end,nil)
  button(app,"hullAd",322,76,112,25,"修理小船","video",function()app:OpenModal("ads")end,nil)
   app:AddButton("compass",14,h-147,132,132,{draw=function(v,w,hh)H.compass(app,v,w,hh)end,
    action=function()app:SetMode("map");app:Toast("鱼群位置为大致范围 · 留意礁石",3)end})
   button(app,"book",157,h-109,73,79,"图鉴","book",book)
   button(app,"cargo",239,h-109,73,79,"渔获","cooler",cargo)
   button(app,"fish",321,h-109,113,79,"开始钓鱼","rod",function()app:StartFishing()end,"gold")
 else
  staminaButton(app,food)
  button(app,"back",16,h-80,76,50,"退出","back",function()
   if app.mode=="fishing" then app:ExitFishing() else app:OpenModal("return") end
  end)
  if app.mode=="fishing" then
   button(app,"book",157,h-111,73,79,"图鉴","book",book)
   button(app,"cargo",239,h-111,73,79,"渔获","cooler",cargo);actionButton(app)
   if app.fish.stage~="aim" then
    button(app,"lookReset",16,h-133,76,35,"视角回正",nil,function()app:ResetFishingView()end)
   end
  else
   button(app,"book",106,h-80,82,50,"图鉴","book",book)
   button(app,"cargo",199,h-80,82,50,"收获",app.mode=="forest"and"basket"or"bucket",cargo)
   button(app,"shoreViewReset",292,h-80,142,50,"视角回正",nil,function()app:WalkingState().pitch=.30 end)
   app:AddButton("move",18,h-239,130,130,{draw=function()end,
    press=function(e)app:BeginShoreStick(e,"move",true)end})
   app:AddButton("shoreLook",302,h-239,130,130,{draw=function()end,
    press=function(e)app:BeginShoreStick(e,"look",true)end})
   local t=app.nearTarget
   if app.mode=="forest"then
    if t then local target=t
     button(app,"context",153,h-172,144,46,"采集 "..t.species.name,"leaf",function()app:Gather(target)end,"gold")
    end
    return
   end
   if t and not app.shore.action then
    local target=t
    button(app,"context",153,h-172,144,46,t.kind=="hole" and "撒盐引出" or t.kind=="mound" and "挖开看看" or "夹起收获",
     t.kind=="hole" and "salt" or t.kind=="mound" and "shovel" or "tongs",function()app:Interact(target)end,"gold")
    if t.kind=="hole" then button(app,"contextDig",169,h-220,112,36,"铁锹挖开","shovel",function()app:Interact(target,"dig")end) end
   end
  end
 end
 if app.mode~="home" and app.mode~="map" then
  button(app,"capacityAd",16,78,152,28,"容量 ×2","video",function()app:OpenModal("ads")end)
 end
end
function H.positionContext(app)
 if (app.mode=="shore"or app.mode=="forest")and app.scene3d then return end
 if not app.nearTarget then return end
 local x,y=app:ScreenPoint(app.nearTarget.x,app.nearTarget.y)
 local b=app.buttons.context
 if b then b:SetStyle({left=math.max(18,math.min(290,x-71))*app.scale,top=(y-77)*app.scale}) end
 local d=app.buttons.contextDig
 if d then d:SetStyle({left=math.max(18,math.min(352,x+79))*app.scale,top=(y-77)*app.scale}) end
end
function H.compass(app,v,w,h)
 A.circle(v,w/2,h/2,58,{35,129,167,255})
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
 if not Skin.Draw(v,"NAV-arrow",-10,-20,20,30)then A.poly(v,{0,-17,10,11,0,6,-10,11},A.cream,A.ink,2)end;nvgRestore(v)
 Skin.Draw(v,"NAV-compass",0,0,w,h)
 for _,d in ipairs({{"N",66,13},{"S",66,119},{"W",13,66},{"E",119,66}}) do A.text(v,d[2],d[3],d[1],12,A.cream,NVG_ALIGN_CENTER) end
 A.circle(v,18,h-15,15,A.cream,A.ink,2);A.icon(v,"compass",18,h-15,19)
end
local function capacity(app,v)
 nvgSave(v);nvgTranslate(v,0,app.hudTop or 0)
 local used,cap=State.used(app.profile),State.capacity(app.profile)
 A.plate(v,14,21,177,51);A.icon(v,app.mode=="forest"and"basket"or app.mode=="shore"and"bucket"or"cooler",39,45,29)
 A.text(v,64,38,app.mode=="forest"and "采集背篓"or app.mode=="shore" and "水桶容量" or "渔获容量",11,A.ink)
 A.text(v,174,51,used.." / "..cap,19,A.ink,NVG_ALIGN_RIGHT)
 A.bar(v,65,61,108,5,used/math.max(1,cap),used>=cap and {243,131,72,255} or {82,198,161,255})
 nvgRestore(v)
end
local function drawStick(v,j,x,y,label)
 if j.active then x,y=j.x,j.y end
 if Skin.Draw(v,label=="滑动观察"and"NAV-look"or"NAV-joystick",x-49,y-49,98,98)then
  Skin.Draw(v,"NAV-joystick",x+j.dx*30-20,y+j.dy*30-20,40,40,"knob")
  if label=="滑动观察"then Skin.Draw(v,"NAV-look",x-10,y-10,20,20,"indicator",.65)end
 else
 A.circle(v,x,y,49,{18,48,76,100},{216,251,245,150},1.5)
 A.circle(v,x,y,33,{14,51,80,50},{214,244,241,55},1)
 for i=0,3 do
  nvgSave(v);nvgTranslate(v,x,y);nvgRotate(v,i*math.pi/2)
  A.poly(v,{0,-42,-4,-36,4,-36},{230,250,239,145});nvgRestore(v)
 end
 A.circle(v,x+j.dx*30,y+j.dy*30,20,{225,244,239,215},A.cream,2)
 end
 if label then A.text(v,x,y+64,label,11,A.cream,NVG_ALIGN_CENTER)end
end
local function joystick(app,v,h)
 if app.mode=="shore"or app.mode=="forest"then
  drawStick(v,app.joy,83,h-174,"行走")
  drawStick(v,app.lookJoy,367,h-174,"滑动观察")
 elseif app.joy.active then drawStick(v,app.joy,83,h-165)end
end
function H.draw(app,v,w,h)
 if app.mode=="map" then SeaChart.Draw(app,v);return end
 local top=app.hudTop or 0
 if app.mode=="home" then
  Home.Draw(app,v)
 else
  capacity(app,v)
  if app.mode=="sailing" then
   local t=app.profile.trip
   nvgSave(v);nvgTranslate(v,0,top)
   for _,p in ipairs({{201,108,"fuel","燃料",t.fuel,{232,187,72,255}},{322,112,"hull","耐久",t.hull,{93,201,147,255}}}) do
    A.plate(v,p[1],21,p[2],51);A.icon(v,p[3],p[1]+18,40,22)
    A.text(v,p[1]+36,35,p[4],10,A.ink);A.text(v,p[1]+p[2]-10,46,math.ceil(p[5]).."%",15,A.ink,NVG_ALIGN_RIGHT)
    A.bar(v,p[1]+10,59,p[2]-20,5,p[5]/100,p[6])
   end
   nvgRestore(v)
   for _,s in ipairs(app.sharks)do local x,y=app:ScreenPoint(s.x,s.y)
   if x>-80 and x<530 and y>-80 and y<h+80 then
    if not app.scene3d then
     nvgSave(v);nvgTranslate(v,x,y);nvgRotate(v,s.heading-math.pi/2)
     World.drawFish(v,0,0,100,"shark",app.playtime,true)
     A.poly(v,{-7,0,4,-24,10,0},{49,73,91,255},A.cream,1.2);nvgRestore(v)
    end
    if math.abs(x-225)<160 and math.abs(y-h/2)<180 then A.text(v,x,y-35,"小心鲨鱼",13,A.cream,NVG_ALIGN_CENTER) end
   end
   end
   if not app.joy.active then
    A.caption(v,151,h-157,282,26)
    A.text(v,292,h-144,"拖动开船 · 双指缩放 · 靠近鱼影",11,A.cream,NVG_ALIGN_CENTER)
   end
  elseif app.mode=="fishing" then
   local f=app.fish
   local status=f.stage=="idle" and "寻找鱼影，选择落点" or f.stage=="aim" and "按住蓄力 · 松手抛竿" or f.stage=="waiting" and (f.target and ((f.waited or 0)<f.target.approach and "鱼影正在靠近…" or "鱼儿正在试探鱼饵…")or "静候游鱼经过 · 可拖动观察") or f.stage=="hooked" and "上钩了！保持合适力度" or "抛竿中…"
   A.caption(v,123,109+top,310,31);A.text(v,278,125+top,status,13,A.cream,NVG_ALIGN_CENTER)
   if f.stage=="hooked" then
    local x,y=379,h-180
    -- Full-canvas needle rotates around the same authored pivot as the arc.
    if Skin.Draw(v,"STA-tension",x-66,y-65.15,132,72.77)then
     nvgSave(v);nvgTranslate(v,x,y);nvgRotate(v,(math.max(0,math.min(1,f.power))-.5)*math.pi)
     Skin.Draw(v,"STA-tension",-66,-65.15,132,72.77,"needle");nvgRestore(v)
    else
    for i=0,39 do
     local q=i/39;local a=math.pi*1.05+q*math.pi*.9;local b=a+.055
     local color={63,188,215,255}
     if q>=.32 then color={102,210,130,255} end
     if q>.72 then color={245,135,67,255} end
     A.line(v,{x+math.cos(a)*61,y+math.sin(a)*61,x+math.cos(b)*61,y+math.sin(b)*61},color,10)
    end
    local angle=math.pi*1.05+f.power*math.pi*.9
    A.line(v,{x+math.cos(angle)*50,y+math.sin(angle)*50,x+math.cos(angle)*72,y+math.sin(angle)*72},A.cream,4)
    end
    A.caption(v,281,h-285,153,31)
    A.text(v,357,h-270,f.power>.72 and "松手缓力" or f.power<.32 and "按住加力" or "完美力度 · 溜鱼中",11,A.cream,NVG_ALIGN_CENTER)
    A.bar(v,100,172+top,250,11,f.progress,{255,202,78,255})
    A.text(v,225,195+top,"收线进度 "..math.floor(f.progress*100).."%",12,A.cream,NVG_ALIGN_CENTER)
    if f.danger>1 then A.text(v,225,221+top,"危险累积 "..string.format("%.1f",f.danger).." / 4",12,{255,223,168,255},NVG_ALIGN_CENTER) end
   elseif f.stage=="aim" then
    A.caption(v,252,h-231,182,53)
    A.text(v,343,h-214,"蓄力 "..math.floor((f.charge or 0)*100).."% · 约 "..math.floor((f.castRange or 12)+.5).." 米",11,A.cream,NVG_ALIGN_CENTER)
    A.bar(v,264,h-202,158,7,f.charge or 0,{255,202,78,255})
   elseif f.stage=="idle" then
    A.caption(v,100,h-169,320,26)
    A.text(v,260,h-156,"拖动看风景 · 长按蓄力投远 · 松手抛竿",10,A.cream,NVG_ALIGN_CENTER)
   end
  elseif app.mode=="forest"then
   nvgSave(v);nvgTranslate(v,0,top)
   A.caption(v,16,88,418,39)
   A.icon(v,"leaf",36,108,21)
   A.text(v,54,102,"月牙林 · "..ForestWorld.Area(app.forest),14,A.cream)
   A.text(v,54,117,"林径 · 密林 · 木桥 · 溪潭 · 收工带回岛上",9,{200,224,188,255})
   A.text(v,419,109,"余 "..ForestWorld.Remaining(app.forest).." 处",12,A.cream,NVG_ALIGN_RIGHT)
   nvgRestore(v)
   local target=app.nearTarget
   local habitat=target and(target.habitat=="tree"and"树上"or target.habitat=="stream"and"溪边"or target.habitat=="log"and"倒木旁"or"林下")or""
   local text=target and (target.species.name.." · "..habitat.." · 点击采集 · 体力 -1")or "左摇杆行走 · 右侧滑动观察 · 沿林径探索溪流"
   A.caption(v,50,h-285,350,28)
   A.text(v,225,h-271,text,11,A.cream,NVG_ALIGN_CENTER)
   if ForestWorld.Remaining(app.forest)==0 then
    A.caption(v,90,top+141,270,28)
    A.text(v,225,top+155,"本趟林间收获已采完 · 可以收工回家啦",11,A.cream,NVG_ALIGN_CENTER)
   end
   A.circle(v,225,h*.48,2,{255,253,226,160})
  else
   nvgSave(v);nvgTranslate(v,0,top)
   A.caption(v,221,90,213,31)
   A.icon(v,"salt",241,105,19);A.text(v,258,105,"盐 ×"..app.profile.salt.."   铁锹 "..(app.profile.shovel and "已携带" or "未携带"),11,A.cream)
   A.text(v,225,163,"月牙滩 · 退潮时光",17,A.cream,NVG_ALIGN_CENTER)
   nvgRestore(v)
   local target=app.nearTarget
   local text=target and (target.species.name.." · 点击即可收获")or "左摇杆行走 · 右侧滑动观察 · 点击前方生物收获"
   A.caption(v,70,h-285,310,28);A.text(v,225,h-271,text,11,A.cream,NVG_ALIGN_CENTER)
   A.circle(v,225,h*.48,2,{255,253,226,180})
  end
  joystick(app,v,h)
 end
end
return H
