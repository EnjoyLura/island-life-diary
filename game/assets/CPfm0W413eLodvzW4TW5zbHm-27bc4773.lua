-- Navigation page, layered over a north-up view of the REAL sailing world.
-- No second NVG frame, simulated fish locations or decorative fake distances.
local A=require("Game.Art")
local Skin=require("Game.UISkin")
local State=require("Game.State")
local Bay=require("Game.Bay")
---@class CrescentSeaChart
local M={}
local INK,CREAM=A.ink,A.cream
local CYAN={123,240,250,245};local GOLD={255,206,78,250}
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
function M.Layout(app)
 local top=app.hudTop or 0
 return {top=top,left=14,right=436,mapTop=top+136,mapBottom=app.h-115,
  footer=app.h-67,legend=app.h-119,tools=app.h-326}
end
function M.Project(app,x,y)
 return 225+(x-app.camera.x)*app.camera.zoom,app.h/2+(y-app.camera.y)*app.camera.zoom
end
function M.Offset(app)
 local l=M.Layout(app);return (l.mapTop+l.mapBottom)/2-app.h/2
end
function M.MinZoom(app)return math.max(Bay.chartMinZoom,app.h*Bay.metresPerUnit/1200)end
function M.Fit(app)
 local l=M.Layout(app);local b=Bay.bounds
 local z=math.min(402/(b.right-b.left),(l.mapBottom-l.mapTop)/(b.bottom-b.top))
 z=clamp(z,M.MinZoom(app),.32)
 return {x=math.min((b.left+b.right)/2,Bay.chartRight-225/z),y=(b.top+b.bottom)/2-M.Offset(app)/z,zoom=z}
end
function M.Locate(app)
 app.camera.zoom=math.max(.27,app.camera.zoom)
 app.camera.x=app.boat.x;app.camera.y=app.boat.y-M.Offset(app)/app.camera.zoom
 app:ClampCamera()
end
function M.Scale(app)
 local metresPerPixel=Bay.metresPerUnit/app.camera.zoom
 local limit=76*metresPerPixel;local metres=1
 for _,n in ipairs({1,2,5,10,20,50,100,200,500})do if n<=limit then metres=n end end
 return metres,metres/metresPerPixel
end
local function arrow(v,x,y,heading,size,color)
 nvgSave(v);nvgTranslate(v,x,y);nvgRotate(v,heading)
 if not Skin.Draw(v,"NAV-arrow",-size*.67,-size*1.33,size*1.34,size*2)then A.poly(v,{0,-size,size*.62,size*.68,0,size*.30,-size*.62,size*.68},color or CREAM,INK,2)end
 nvgRestore(v)
end
local function rock(v,x,y,size)
 A.poly(v,{x-size,y+size*.5,x-size*.65,y-size*.45,x-size*.10,y-size,
  x+size*.45,y-size*.65,x+size,y+size*.4,x+size*.35,y+size*.75},{148,159,161,255},INK,1.5)
 A.poly(v,{x-size*.65,y-size*.45,x-size*.1,y-size,x+size*.45,y-size*.65,x+size*.1,y}, {224,219,194,255})
end
local function label(v,x,y,text,tone)
 local width=utf8.len(text)*12+18
 if not Skin.Draw(v,"PLT-bubble",x-width/2,y-13,width,27)then A.rect(v,x-width/2,y-12,width,24,CREAM,5)end
 A.text(v,x,y,text,12,INK,NVG_ALIGN_CENTER)
end
local function ring(v,app,x,y,rx,ry,color,fill)
 local sx,sy=M.Project(app,x,y);local z=app.camera.zoom
 local l=M.Layout(app)
 if sx+rx*z<0 or sx-rx*z>450 or sy+ry*z<l.mapTop or sy-ry*z>l.mapBottom then return end
 if fill then A.ellipse(v,sx,sy,rx*z,ry*z,fill)end
 if Skin.Draw(v,"NAV-zone",sx-rx*z,sy-ry*z,rx*z*2,ry*z*2,color==GOLD and"danger"or"default")then return end
 for i=0,23 do local a=i*math.pi/12;local b=a+.14
  A.line(v,{sx+math.cos(a)*rx*z,sy+math.sin(a)*ry*z,sx+math.cos(b)*rx*z,sy+math.sin(b)*ry*z},color,1.6)
 end
end
function M.Build(app)
 local l=M.Layout(app)
 app:AddButton("back",14,l.footer,104,49,{text="返回",icon="back",action=function()app:SetMode("sailing")end})
 local controls={{"zoom+",l.tools,"+",function()app:Zoom(1.2)end},
  {"zoom-",l.tools+49,"−",function()app:Zoom(.83)end},
  {"locate",l.tools+100,"定位",function()M.Locate(app)end}}
 for _,entry in ipairs(controls)do local e=entry
  app:AddButton(e[1],392,e[2],44,e[1]=="locate" and 59 or 44,{text=e[3],
   draw=function(v,w,h,down)
    A.button(v,0,0,w,h,nil,down,false,false,"BTN-square")
    if e[1]=="locate" then
     A.icon(v,"locate",w/2,21,26)
     A.text(v,w/2,45,"定位",11,INK,NVG_ALIGN_CENTER)
    else A.icon(v,e[1]=="zoom+"and"plus"or"minus",w/2,h/2-2,27)end
   end,action=e[4]})
 end
end
local function status(app,v,l)
 A.plate(v,49,l.top+10,352,44)
 A.text(v,225,l.top+31,"月牙湾 · 海域地图",25,INK,NVG_ALIGN_CENTER)
 A.plate(v,14,l.top+61,422,57)
 local trip=app.profile.trip
 local values={{"cooler","渔获",State.used(app.profile).."/"..State.capacity(app.profile),State.used(app.profile)/math.max(1,State.capacity(app.profile)),{65,171,223,255}},
  {"fuel","燃料",math.ceil(trip and trip.fuel or 0).."%",(trip and trip.fuel or 0)/100,{245,155,63,255}},
  {"hull","耐久",math.ceil(trip and trip.hull or 0).."%",(trip and trip.hull or 0)/100,{75,193,125,255}}}
 for i,p in ipairs(values)do local x=23+(i-1)*139
  if i>1 then A.line(v,{x-5,l.top+69,x-5,l.top+108},{153,134,94,255},1)end
  A.icon(v,p[1],x+14,l.top+87,31)
  A.text(v,x+35,l.top+78,p[2],11,INK)
  A.text(v,x+119,l.top+78,p[3],14,INK,NVG_ALIGN_RIGHT)
  A.bar(v,x+35,l.top+92,84,10,p[4],p[5])
 end
end
function M.Draw(app,v)
 local l=M.Layout(app)
 nvgSave(v);nvgIntersectScissor(v,0,l.mapTop,450,math.max(1,l.mapBottom-l.mapTop))
 if app.camera.zoom<=.085 then
  for _,region in ipairs(Bay.regions.all)do
   local x,y=M.Project(app,(region.left+region.right)/2,region.top+550)
   if x>70 and x<365 and y>l.mapTop+24 and y<l.mapBottom-24 then
    label(v,x,y,region.name..(region.developed and ""or" · 待开放"),region.developed and {19,89,127,239}or{70,86,100,224})
   end
  end
 end
 for _,s in ipairs(app.fishSchools)do
  ring(v,app,s.x,s.y,145,108,CYAN,{55,195,217,26})
  local x,y=M.Project(app,s.x,s.y)
  if x>25 and x<367 and y>l.mapTop+24 and y<l.mapBottom-24 then
   nvgSave(v);nvgTranslate(v,x,y)
   for j=1,3 do
    local xx,yy=(j-2)*16,(j%2)*12-6
    A.ellipse(v,xx,yy,8,4,{12,67,101,230})
    A.poly(v,{xx+6,yy,xx+13,yy-4,xx+13,yy+4},{12,67,101,230})
   end
   nvgRestore(v)
   if s==app.fishSchools[1] then label(v,x,y-108*app.camera.zoom-15,"鱼群范围")end
  end
 end
 -- Identify the real northern and central reef groups, without inventing a chain.
 for _,i in ipairs({1,6})do local r=app.reefs[i]
  if r then local x,y=M.Project(app,r.x,r.y)
   if x>55 and x<350 and y>l.mapTop+46 and y<l.mapBottom-26 then label(v,x,y+28,i==6 and "北部礁群" or "碎礁区",{113,94,62,239})end
  end
 end
 for _,shark in ipairs(app.sharks)do
 ring(v,app,shark.x,shark.y,150,112,GOLD,{242,171,46,22})
 local sx,sy=M.Project(app,shark.x,shark.y)
 if sx>25 and sx<430 and sy>l.mapTop+45 and sy<l.mapBottom-30 then
  A.poly(v,{sx-13,sy+6,sx+5,sy-18,sx+9,sy+5},{29,65,88,255},CREAM,1)
  label(v,clamp(sx,60,366),sy-30,"鲨鱼出没",{146,63,48,245})
 end
 end
 local px,py=M.Project(app,Bay.port.x,Bay.port.y)
 if px>22 and px<352 and py>l.mapTop+25 and py<l.mapBottom-20 then
  if Skin.Draw(v,"NAV-pin",px-16,py-30,32,40)then A.icon(v,"anchor",px,py-14,20)
  else A.circle(v,px,py,15,{18,72,108,255},CREAM,2);A.icon(v,"anchor",px,py,21,CREAM)end
  label(v,clamp(px+47,55,340),py-17,"出发码头",{30,94,123,245})
 end
 local x,y=M.Project(app,app.boat.x,app.boat.y)
 if x>20 and x<430 and y>l.mapTop+24 and y<l.mapBottom-30 then
  nvgSave(v);nvgTranslate(v,x,y);nvgRotate(v,app.boat.heading)
  if not Skin.Draw(v,"NAV-arrow",-33,-63,66,66,"vision-cone")then A.poly(v,{0,0,-25,-58,25,-58},{138,231,255,62})end;nvgRestore(v)
  A.circle(v,x,y,20,{28,214,236,48},CYAN,2.5)
  arrow(v,x,y,app.boat.heading,15)
  label(v,x,y+36,"你在这里")
 else
  local ex,ey=clamp(x,25,363),clamp(y,l.mapTop+27,l.mapBottom-29)
  arrow(v,ex,ey,math.atan(x-ex,-(y-ey)),13,GOLD)
  label(v,clamp(ex,55,340),clamp(ey+25,l.mapTop+15,l.mapBottom-13),"船位在屏外")
 end
 nvgRestore(v)
 -- North stays screen-up, while the player's arrow carries their true heading.
 local nx,ny=410,l.mapTop+34
 A.circle(v,nx,ny,22,{28,79,110,255})
 Skin.Draw(v,"NAV-compass",nx-24,ny-24,48,48)
 arrow(v,nx,ny,0,13);A.text(v,nx,ny-30,"N",15,CREAM,NVG_ALIGN_CENTER)
 status(app,v,l)
 -- One compact, consistent paper legend instead of a large dark footer panel.
 A.plate(v,119,l.legend,317,37)
 arrow(v,136,l.legend+17,0,9,{63,179,224,255});A.text(v,151,l.legend+17,"船位",11,INK)
 A.ellipse(v,215,l.legend+17,19,10,{131,228,234,220});A.icon(v,"fish",215,l.legend+17,18)
 A.text(v,237,l.legend+17,"鱼群",11,INK)
 rock(v,293,l.legend+18,11);A.text(v,310,l.legend+17,"礁石",11,INK)
 A.circle(v,366,l.legend+17,8,{0,0,0,0},{200,110,51,255},1.5);A.text(v,379,l.legend+17,"危险",11,INK)
 local metres,length=M.Scale(app);local bx,by=436-length,l.footer+35
 A.line(v,{bx,by-5,bx,by,bx+length,by,bx+length,by-5},INK,5)
 A.line(v,{bx,by-5,bx,by,bx+length,by,bx+length,by-5},CREAM,2)
 A.text(v,bx+length/2,by-15,metres.." m",12,CREAM,NVG_ALIGN_CENTER)
 A.text(v,250,l.footer+24,"拖动查看 · 双指缩放",11,CREAM,NVG_ALIGN_CENTER)
end
return M
