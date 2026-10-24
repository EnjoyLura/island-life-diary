-- Shares the existing UI tree and safe area. No second NanoVG frame/context.
local UI=require("urhox-libs/UI")
local Probe=require("Game.RenderProbe")
local M={}
function M.Shortcut(app)
 app:AddButton("performance",16,(app.mode=="shore"or app.mode=="forest")and (app.hudTop+135)or app.h-205,112,29,{
  text=function()return Probe.enabled and "● 性能采集中" or "性能报告" end,
  size=12,tone="dark",action=function()app:OpenModal("performance")end})
end
function M.Build(app)
 local Skinned=require("Game.SkinWidgets")
 local s=app.scale;local ink={20,45,60,255};local muted={78,105,111,255}
 local page=Skinned.Panel{artScale=s,position="absolute",left=16*s,top=(app.hudTop+8)*s,
  width=418*s,height=math.max(180,app.h-app.hudTop-24)*s,
  padding=16*s,gap=12*s,flexDirection="column",backgroundColor={255,253,236,255}}
 app.host:AddChild(page)
 local function label(text,size,color)
  return UI.Label{text=text,fontSize=(size or 13)*s,fontColor=color or ink,
   whiteSpace="normal",wordBreak="break-word",lineHeight=1.4,width="100%"}
 end
 local function button(text,action)
  return Skinned.Button{artScale=s,text=text,height=44*s,width="100%",fontSize=14*s,
   backgroundColor={245,202,106,255},textColor=ink,onClick=action}
 end
 page:AddChild(label("真机性能报告",24))
 page:AddChild(UI.Toggle{label="采集并上报运行日志",value=Probe.enabled,width="100%",height=40*s,
  trackWidth=48*s,trackHeight=26*s,thumbSize=22*s,fontSize=15*s,
  onChange=function(_,enabled)
   if enabled then Probe.Start(app);app:CloseModal();app:Toast("性能采集已开启，正常游玩后点性能报告结束",4)
   else local _,message=Probe.Generate();app:Toast(message,4);app:MarkUI() end
  end})
 local scroll=UI.ScrollView{width="100%",flexGrow=1,flexBasis=0,scrollY=true,scrollX=false}
 local content=UI.Panel{width="100%",gap=10*s,paddingRight=8*s,flexDirection="column"}
 scroll:AddChild(content);page:AddChild(scroll)
 local scene=app.scene3d
 if scene and scene.GetRenderInfo then
  local info=scene:GetRenderInfo()
  content:AddChild(label(string.format("当前 3D：%d×%d · %.0f%% · %s · 海水%s",info.width or 0,info.height or 0,(info.scale or 1)*100,info.scaleSource=="auto" and "自动" or "指定",info.waterVisible and "开启" or "关闭"),13,muted))
 end
 content:AddChild(label("建议连续游玩 20 分钟：海岛缩放、开船、看地图和钓鱼。切后台与本页不计入场景帧率。",13,muted))
 local status=label(Probe.Status(),13);content:AddChild(status)
 local seconds=0
 page.Update=function(_,dt)
  seconds=seconds+dt
  if seconds>=1 then seconds=0;status:SetText(Probe.Status()) end
 end
 local function field(title,key,placeholder)
  content:AddChild(label(title,12,muted))
  content:AddChild(UI.TextField{value=Probe.manual[key],placeholder=placeholder,maxLength=160,
   width="100%",height=40*s,fontSize=13*s,onChange=function(_,value)Probe.manual[key]=value end})
 end
 field("机型（手动填写）","model","例如 iQOO 13 · 16+512GB")
 field("测试条件（可选）","conditions","充电 / 亮度 / 刷新率 / 游戏模式")
 field("发热感受（可选）","heat","不热 / 微热 / 明显发烫")
 content:AddChild(label("制造预览：记录发送到运行日志。网页：生成报告后复制、下载或分享给我。只采集性能数据和以上手填内容。",12,muted))
 content:AddChild(label("温度、功耗、GPU 耗时当前不可读取，会在报告中标为不可用。采集不会调整画质或帧率。每 10 秒汇总，最长 60 分钟。",12,muted))
 page:AddChild(button("结束并生成报告",function()
  local _,message=Probe.Generate();status:SetText(Probe.Status());app:Toast(message,4);app:MarkUI()
 end))
 page:AddChild(button("复制报告",function()
  if Probe.enabled then Probe.Generate() end
  local _,message=Probe.Copy();app:Toast(message,4);app:MarkUI()
 end))
 page:AddChild(button("返回游戏",function()app:CloseModal()end))
end
return M
