local UI=require("urhox-libs/UI")
local Music=require("Game.Music")
local M={}
function M.Shortcut(app)
 if not app.music then return end
 local y=(app.mode=="shore"or app.mode=="forest")and(app.hudTop+135)or app.h-205
 app:AddButton("music",140,y,88,29,{text="音乐",size=12,tone="dark",action=function()app:OpenModal("music")end})
end
function M.Build(app)
 local s=app.scale;local music=app.music
 local ink,muted={20,45,60,255},{78,105,111,255}
 local page=UI.Panel{position="absolute",left=16*s,top=(app.hudTop+8)*s,width=418*s,
  height=math.max(180,app.h-app.hudTop-24)*s,padding=16*s,gap=10*s,flexDirection="column",
  backgroundColor={255,253,236,255}}
 app.host:AddChild(page)
 local function label(text,size,color,height)
  return UI.Label{text=text,fontSize=(size or 13)*s,fontColor=color or ink,width="100%",
   height=(height or math.ceil((size or 13)*1.45))*s,flexShrink=0,
   whiteSpace="normal",wordBreak="break-word",lineHeight=1.35}
 end
 page:AddChild(label("海岛音乐",25))
 local switchRow=UI.Panel{width="100%",height=38*s,flexShrink=0,flexDirection="row",alignItems="center",gap=10*s}
 local enabled=UI.Toggle{value=music.enabled,width=48*s,height=38*s,
  trackWidth=48*s,trackHeight=26*s,thumbSize=22*s,fontSize=15*s,
  onChange=function(_,value)music:SetEnabled(value)end}
 switchRow:AddChild(enabled)
 switchRow:AddChild(UI.Label{text="背景音乐",fontSize=15*s,fontColor=ink,flexGrow=1,height=24*s})
 page:AddChild(switchRow)
 local volume=label("音量 "..math.floor(music.volume*100+.5).."%",13)
 page:AddChild(volume)
 page:AddChild(UI.Slider{value=music.volume*100,min=0,max=100,step=1,width="100%",height=32*s,flexShrink=0,
  thumbSize=24*s,trackHeight=6*s,onChange=function(_,value)
   music:SetVolume(value/100);volume:SetText("音量 "..math.floor(value+.5).."%")
  end})
 local status=label(music:Status(),12,muted);page:AddChild(status)
 local scroll=UI.ScrollView{width="100%",flexGrow=1,flexBasis=0,minHeight=0,scrollY=true,scrollX=false}
 local content=UI.Panel{width="100%",gap=10*s,paddingRight=8*s,flexDirection="column",flexShrink=0}
 scroll:AddChild(content);page:AddChild(scroll)
 for _,key in ipairs(Music.order)do
  local track=Music.tracks[key]
  local card=UI.Panel{width="100%",height=148*s,flexShrink=0,padding=12*s,gap=4*s,flexDirection="column",backgroundColor={246,236,207,255},borderRadius=9*s}
  card:AddChild(label(track.name,16));card:AddChild(label(track.mood,12,muted))
  card:AddChild(label(track.title,11,muted));card:AddChild(label(track.author,11,muted))
  card:AddChild(UI.Button{text="试听",width="100%",height=34*s,flexShrink=0,fontSize=13*s,
   backgroundColor={243,207,123,255},textColor=ink,
   onClick=function()enabled:SetValue(true);music:Preview(key)end})
  content:AddChild(card)
 end
 content:AddChild(label("音乐鸣谢 · CC0 1.0\n四首配乐来自 OpenGameArt 作者发布页。循环整理、响度调整及 OGG 编码。完整来源见随包 audio/CREDITS.txt。",11,muted,70))
 local clock=0
 page.Update=function(_,dt)clock=clock+dt;if clock>=.25 then clock=0;status:SetText(music:Status())end end
 page:AddChild(UI.Button{text="返回游戏",width="100%",height=43*s,flexShrink=0,fontSize=15*s,
  backgroundColor={245,202,106,255},textColor=ink,onClick=function()app:CloseModal()end})
end
return M
