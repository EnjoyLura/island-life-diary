-- Retained audio-only Scene: non-positional stereo music, two compressed voices.
local B={};B.__index=B
local FILE="crescent-audio-v1.json"
function B.ReadSettings()
 local ok,result=pcall(function()
  if not fileSystem:FileExists(FILE)then return nil end
  local f=File(FILE,FILE_READ);if not f:IsOpen()then return nil end
  local raw=f:ReadString();f:Close();return cjson.decode(raw)
 end)
 return ok and result or nil
end
function B.new()
 require("urhox-libs/Engine/ResourceCacheExtensions")
 local self=setmetatable({scene=Scene(),sources={}},B)
 for i=1,2 do
  local source=self.scene:CreateChild("IslandMusic"..i):CreateComponent("SoundSource")
  source.soundType=SOUND_MUSIC;source.gain=0;self.sources[i]=source
 end
 return self
end
function B:Load(path,done)
 cache:GetResourceAsync("Sound",path,function(resource)
  ---@type Sound?
  local sound=resource --[[@as Sound?]]
  if sound and sound:GetLength()>0 then sound:SetLooped(true);done(sound)
  else print("[CrescentMusic] unavailable: "..path);done(nil)end
 end)
end
function B:Play(slot,sound,gain)
 self.sources[slot]:Play(sound,0,gain)
 print(string.format("[CrescentMusic] play slot=%d compressed=%s loop=%s seconds=%.2f playing=%s",slot,
  tostring(sound:IsCompressed()),tostring(sound:IsLooped()),sound:GetLength(),tostring(self.sources[slot]:IsPlaying())))
end
function B:Gain(slot,gain)self.sources[slot].gain=gain end
function B:StopVoice(slot)self.sources[slot]:Stop()end
function B:Pause(paused)
 if paused then audio:PauseSoundType(SOUND_MUSIC)else audio:ResumeSoundType(SOUND_MUSIC)end
end
function B:SaveSettings(settings)
 local ok,err=pcall(function()
  local f=File(FILE,FILE_WRITE);if not f:IsOpen()then error("audio settings unavailable")end
  f:WriteString(cjson.encode(settings));f:Close()
 end)
 if not ok then print("[CrescentMusic] settings not saved: "..tostring(err))end
end
function B:Stop()
 for _,source in ipairs(self.sources)do source:Stop()end
 self.scene:Remove();self.sources={};self.scene=nil
 audio:ResumeSoundType(SOUND_MUSIC)
end
return B
