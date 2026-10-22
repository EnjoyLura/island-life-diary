-- Based on scaffold-3d-scene.lua: retained Scene/Camera + transparent UI HUD.
-- No native UI, no multiplayer, no remote services required for core play.
local UI = require("urhox-libs/UI")
local App = require("Game.App")
local Scene3D = require("Game.Scene3D")
local RenderSettings = require("Game.RenderSettings")
local RenderProbe = require("Game.RenderProbe")
local Music = require("Game.Music")
local MusicAudio = require("Game.MusicAudio")
local app_ = nil
local function startGame()
 graphics.windowTitle="月牙岛 · 海风与收获"
 input.mouseMode=MM_ABSOLUTE
 -- A calm exploration game has a deliberate sustainable frame budget.
 -- The browser shell also paces RAF; this covers native and official runtimes.
 engine.maxFps=RenderSettings.hostPaced and 240 or RenderSettings.fps;engine.maxInactiveFps=15
 UI.Init({theme="default-light",scale=UI.Scale.DEFAULT,fonts={{family="sans",weights={normal="Fonts/MiSans-Regular.ttf",bold="Fonts/MiSans-Regular.ttf"}}}})
 app_=App.new();app_.music=Music.new(MusicAudio.new(),MusicAudio.ReadSettings())
 app_.scene3d=Scene3D.new(app_);app_:Start()
 RenderProbe.Init(app_)
 SubscribeToEvent("Update","HandleIslandUpdate")
 SubscribeToEvent("KeyDown","HandleIslandKeyDown")
 SubscribeToEvent("InputFocus","HandleIslandFocus")
 SubscribeToEvent("EndViewRender","HandleIslandViewRendered")
 print("[Crescent] playable prototype started")
end
function Start()
 local ok,err=xpcall(startGame,debug and debug.traceback or tostring)
 if not ok then
  print("[CrescentStartup] failed: "..tostring(err))
  error(err,0)
 end
end
function HandleIslandUpdate(_,eventData)
 if app_ then
  RenderProbe.Record(app_);app_:Update(eventData:GetFloat("TimeStep"));RenderProbe.Complete(app_)
 end
end
function HandleIslandViewRendered(_,eventData)if app_ then RenderProbe.ViewRendered(app_,eventData)end end
function HandleIslandFocus(_,eventData)
 local focused=eventData:GetBool("Focus")and not eventData:GetBool("Minimized")
 RenderProbe.Focus(focused)
 if app_ and app_.music then app_.music:SetFocus(focused)end
end
function HandleIslandKeyDown(_,eventData) if app_ then app_:Key(eventData:GetInt("Key")) end end
function Stop() RenderProbe.Finish("shutdown");if app_ then app_:Save();app_:Stop() end;UI.Shutdown();app_=nil end
