-- One explicit GM entry replaces persistent music/performance shortcuts.
local UI=require("urhox-libs/UI")
local A=require("Game.Art")
local Home=require("Game.HomeUI")
local Probe=require("Game.RenderProbe")
local M={}
function M.Shortcut(app)
 local r=app.mode=="home"and Home.Layout(app).gm or {14,(app.hudTop or 0)+145,29,29}
 app:AddButton("gm",r[1],r[2],r[3],r[4],{icon="gear",iconOnly=true,iconSize=app.mode=="home"and 31 or 21,
  action=function()app:OpenModal("gm")end,
  draw=function(v,w,h,down,hover)
   if app.mode=="home"then Home.DrawGM(v,w,h,down,hover);return end
   A.button(v,0,0,w,h,nil,down,hover,false,"BTN-square");A.icon(v,"gear",w/2,h*.44,h*.66)
   A.text(v,w/2,h*.83,"GM",h*.21,A.ink,NVG_ALIGN_CENTER)
  end})
end
function M.Build(app)
 local Skin=require("Game.SkinWidgets");local s=app.scale;local ink=A.ink
 local page=Skin.Panel{artScale=s,position="absolute",left=20*s,top=(app.hudTop+8)*s,width=410*s,
  height=math.max(200,app.h-app.hudTop-24)*s,padding=18*s,gap=14*s,flexDirection="column"}
 app.host:AddChild(page)
 local function label(text,size)
  return UI.Label{text=text,fontSize=(size or 14)*s,fontColor=ink,height=((size or 14)*1.5)*s,flexShrink=0}
 end
 page:AddChild(label("GM · 游戏选项",24))
 local function row(text,value,change)
  local p=UI.Panel{width="100%",height=44*s,flexShrink=0,flexDirection="row",alignItems="center",justifyContent="space-between"}
  p:AddChild(label(text,17))
  p:AddChild(UI.Toggle{value=value,width=54*s,height=40*s,trackWidth=50*s,trackHeight=28*s,thumbSize=24*s,
   onChange=function(_,enabled)change(enabled)end})
  page:AddChild(p)
 end
 row("背景音乐",app.music and app.music.enabled or false,function(enabled)
  if app.music then app.music:SetEnabled(enabled)end
 end)
 row("性能采集",Probe.enabled,function(enabled)
  if enabled then Probe.Start(app)else local _,message=Probe.Generate();app:Toast(message,3)end
 end)
 local function button(text,action)
  page:AddChild(Skin.Button{artScale=s,text=text,width="100%",height=46*s,fontSize=16*s,textColor=ink,flexShrink=0,onClick=action})
 end
 button("音乐与音量设置",function()app:OpenModal("music")end)
 button("查看性能报告",function()app:OpenModal("performance")end)
 page:AddChild(UI.Panel{flexGrow=1})
 page:AddChild(label("开关按需开启，关闭面板即可继续游玩。",11))
 button("返回游戏",function()app:CloseModal()end)
end
return M
