-- Scene music policy. Engine IO lives in MusicAudio; this state machine is testable.
---@class IslandMusic
---@field backend table
---@field voices table[]
---@field enabled boolean
---@field volume number
---@field scene string
---@field current string?
---@field preview string?
---@field loading string?
---@field loadError string?
---@field focused boolean
---@field unlocked boolean
---@field stopped boolean?
---@field epoch integer
---@field clock number
---@field retryAt number
---@field settingsDirty boolean?
---@field settingsWait number?
local M={};M.__index=M
M.tracks={
 home={path="audio/Music/home.ogg",title="Town Theme RPG",name="海岛主界面",author="The Cynic Project / Alex Smith",mood="竖琴与笛声 · 温馨归岛"},
 sea={path="audio/Music/sea.ogg",title="Calm Piano 1 (Vaporware)",name="开船与钓鱼",author="The Cynic Project / Alex Smith",mood="舒缓钢琴 · 悠闲海风"},
 forest={path="audio/Music/forest.ogg",title="Forest Ambience",name="林间采集",author="TinyWorlds",mood="轻柔氛围 · 林间漫步"},
 shore={path="audio/Music/shore.ogg",title="Feel Good Island Loop",name="沙滩赶海",author="Brandon Morris / AntumDeluge",mood="轻快海岛 · 寻找小收获"},
}
M.order={"home","sea","forest","shore"}
local scenes={home="home",sailing="sea",fishing="sea",map="sea",shore="shore",forest="forest"}
local function finite(x)return type(x)=="number"and x==x and math.abs(x)<math.huge end
function M.Settings(value)
 value=type(value)=="table"and value or {}
 return {enabled=value.enabled~=false,volume=finite(value.volume)and math.max(0,math.min(1,value.volume))or .7}
end
---@return IslandMusic
function M.new(backend,settings)
 local p=M.Settings(settings)
 return setmetatable({backend=backend,enabled=p.enabled,volume=p.volume,focused=true,unlocked=false,
  scene="home",voices={},epoch=0,clock=0,retryAt=0},M)
end
function M:Wanted()return self.preview or scenes[self.scene]or "home"end
function M:SetScene(scene)
 self.scene=scene;self.preview=nil;self:_Request()
end
function M:Preview(key)
 if not M.tracks[key]then return end
 self.preview=key;self:Activate();self:_Request()
end
function M:EndPreview()self.preview=nil;self:_Request()end
function M:Activate()
 if self.stopped then return end
 self.unlocked=true;self:_Request()
end
function M:SetEnabled(value)
 if self.stopped then return end
 self.enabled=value==true;self.settingsDirty=true;self.settingsWait=0
 if self.enabled then self:Activate() else self.epoch=self.epoch+1;self.loading=nil;for _,v in pairs(self.voices)do v.target=0 end end
end
function M:SetVolume(value)
 if not finite(value)then return end
 self.volume=math.max(0,math.min(1,value));self.settingsDirty=true;self.settingsWait=.4
end
function M:SetFocus(focus)
 focus=focus==true
 if self.stopped or focus==self.focused then return end
 self.focused=focus;self.backend:Pause(not focus)
 if focus then self:_Request()end
end
function M:_Request()
 if self.stopped or not self.enabled or not self.focused or not self.unlocked or self.volume==0 then return end
 local key=self:Wanted()
 for _,v in pairs(self.voices)do
  if v.key==key then
   self.current=key
   if self.loading then self.epoch=self.epoch+1;self.loading=nil end
   for _,other in pairs(self.voices)do other.target=other==v and 1 or 0 end
   return
  end
 end
 if self.loading==key or self.clock<self.retryAt then return end
 self.epoch=self.epoch+1;local epoch=self.epoch;self.loading=key;self.loadError=nil
 self.backend:Load(M.tracks[key].path,function(sound)
  -- Download completion can arrive after a mode change, mute, or shutdown.
  if self.stopped or self.epoch~=epoch then return end
  self.loading=nil
  if not sound then self.loadError=key;self.retryAt=self.clock+10;return end
  if not self.enabled or self:Wanted()~=key then return end
  local slot=not self.voices[1]and 1 or not self.voices[2]and 2 or(self.voices[1].level<=self.voices[2].level and 1 or 2)
  if self.voices[slot]then self.backend:StopVoice(slot)end
  for _,v in pairs(self.voices)do v.target=0 end
  self.backend:Play(slot,sound,0)
  self.voices[slot]={key=key,level=0,target=1,gain=0};self.current=key
 end)
end
function M:Update(dt)
 if self.stopped then return end
 dt=finite(dt)and math.max(0,math.min(dt,.1))or 0;self.clock=self.clock+dt
 if self.settingsDirty then
  self.settingsWait=(self.settingsWait or 0)-dt
  if self.settingsWait<=0 then self.settingsDirty=false;self.backend:SaveSettings({enabled=self.enabled,volume=self.volume})end
 end
 if not self.focused then return end
 self:_Request()
 for i=1,2 do local v=self.voices[i]
  if v then
   local target=self.enabled and self.volume>0 and v.target or 0
   local step=dt/(target==0 and not self.enabled and .25 or 1.4)
   v.level=v.level<target and math.min(target,v.level+step)or math.max(target,v.level-step)
   -- Smooth amplitude at the ends of a fade. The two voices never exceed unity.
   local gain=(v.level*v.level*(3-2*v.level))*self.volume*.8
   if math.abs(gain-v.gain)>.00001 then self.backend:Gain(i,gain);v.gain=gain end
   if target==0 and v.level==0 then self.backend:StopVoice(i);self.voices[i]=nil end
  end
 end
end
function M:Status()
 if not self.enabled then return "背景音乐已关闭"end
 if not self.unlocked then return "点击任意位置，开启海岛配乐"end
 if self.volume==0 then return "音乐音量为 0"end
 if self.loadError then return "音乐暂未加载，稍后自动重试"end
 if self.loading then return "正在准备配乐…"end
 return "正在播放："..M.tracks[self.current or self:Wanted()].title
end
function M:Stop()
 if self.stopped then return end
 self.stopped=true;self.epoch=self.epoch+1
 if self.settingsDirty then self.backend:SaveSettings({enabled=self.enabled,volume=self.volume})end
 self.backend:Stop();self.voices={}
end
return M
