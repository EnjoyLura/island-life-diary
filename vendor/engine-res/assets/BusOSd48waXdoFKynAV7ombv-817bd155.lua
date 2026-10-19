-- ============================================================================
-- FakeAd Module
-- Simulates reward video ad on platforms without ad SDK, including WASM preview.
-- ============================================================================
--
-- Called from C++ SDKLuaAPI when platform lacks ad SDK and default_ad_url
-- is configured. Plays a fullscreen video with 30-second countdown,
-- skip/confirm dialog, and reports result via sdk:__OnFakeAdResult().
--
-- Usage (from C++):
--   require("urhox-libs/FakeAd").Show(url)
-- The RewardedVideoAd binding uses CreateRewardedVideoAd to simulate load/show.
--
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local UI = require("urhox-libs/UI/Core/UI")
local Panel = require("urhox-libs/UI/Widgets/Panel")
local Label = require("urhox-libs/UI/Widgets/Label")
local Button = require("urhox-libs/UI/Widgets/Button")

local FakeAd = {}

local COUNTDOWN_SECONDS = 30

-- ============================================================================
-- Module state
-- ============================================================================

local overlay_ = nil          -- root fullscreen panel
local videoPlayer_ = nil      -- C++ VideoPlayer instance
local nvgImage_ = nil         -- NanoVG image handle for video texture
local eventNode_ = nil        -- standalone Node for independent event subscription
local eventSO_ = nil          -- ScriptObject on eventNode_ (avoids overriding game's global handlers)
local countdown_ = COUNTDOWN_SECONDS
local paused_ = false
local completed_ = false      -- countdown reached 0
local confirmPanel_ = nil     -- confirm dialog panel
local skipLabel_ = nil        -- label inside skip button (for text updates)
local rewardLabel_ = nil      -- "奖励已领取" label
local videoView_ = nil        -- custom video widget
local startTime_ = 0          -- wall-clock start time (time.elapsedTime)
local pauseStartTime_ = 0     -- wall-clock time when pause began
---@type FakeRewardedVideoAd?
local owner_ = nil            -- explicit-load adapter that owns the current overlay
---@type fun(success: boolean, msg: string)?
local resultCallback_ = nil   -- nil keeps the legacy sdk:__OnFakeAdResult path

-- ============================================================================
-- VideoView Widget - renders C++ VideoPlayer texture via NanoVG
-- ============================================================================

local VideoView = Widget:Extend("FakeAdVideoView")

function VideoView:Init(props)
    props = props or {}
    props.width = props.width or "100%"
    props.height = props.height or "100%"
    Widget.Init(self, props)
end

function VideoView:Render(nvg)
    local l = self:GetAbsoluteLayout()

    -- Black background
    nvgBeginPath(nvg)
    nvgRect(nvg, l.x, l.y, l.w, l.h)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 255))
    nvgFill(nvg)

    if not videoPlayer_ or not videoPlayer_:IsReady() then
        return
    end

    local texture = videoPlayer_:GetTexture()
    if not texture then return end

    -- Create NanoVG image handle once
    if not nvgImage_ and nvgCreateVideo then
        nvgImage_ = nvgCreateVideo(nvg, texture)
    end
    if not nvgImage_ or nvgImage_ <= 0 then return end

    local vw = videoPlayer_:GetVideoWidth()
    local vh = videoPlayer_:GetVideoHeight()
    if vw <= 0 or vh <= 0 then return end

    -- "contain" fit: letterbox / pillarbox
    local ratio = vw / vh
    local containerRatio = l.w / l.h
    local drawW, drawH
    if ratio > containerRatio then
        drawW = l.w
        drawH = l.w / ratio
    else
        drawH = l.h
        drawW = l.h * ratio
    end
    local drawX = l.x + (l.w - drawW) / 2
    local drawY = l.y + (l.h - drawH) / 2

    nvgSave(nvg)
    nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)

    local paint = nvgImagePattern(nvg, drawX, drawY, drawW, drawH, 0, nvgImage_, 1)
    nvgBeginPath(nvg)
    nvgRect(nvg, drawX, drawY, drawW, drawH)
    nvgFillPaint(nvg, paint)
    nvgFill(nvg)

    nvgRestore(nvg)
end

-- ============================================================================
-- Cleanup
-- ============================================================================

local function cleanup()
    -- Destroy the event node first — this automatically unsubscribes all events
    -- on the ScriptObject without touching the game's global event handlers.
    if eventNode_ then
        eventNode_:Remove()
        eventNode_:Dispose()
        eventNode_ = nil
        eventSO_ = nil
    end

    -- Delete NanoVG video image BEFORE destroying the video player,
    -- so NanoVG releases its reference to the BGFX texture first.
    if nvgImage_ then
        local nvg = UI.GetNVGContext()
        if nvg and nvgDeleteVideo then
            nvgDeleteVideo(nvg, nvgImage_)
        end
        nvgImage_ = nil
    end

    if videoPlayer_ then
        videoPlayer_:Stop()
        videoPlayer_:Dispose()
        videoPlayer_ = nil
    end

    if overlay_ then
        UI.PopOverlay(overlay_)
        local root = UI.GetRoot()
        if root then
            root:RemoveChild(overlay_)
        end
        overlay_:Destroy()
        overlay_ = nil
    end

    videoView_ = nil
    confirmPanel_ = nil
    skipLabel_ = nil
    rewardLabel_ = nil
    paused_ = false
    completed_ = false
    countdown_ = COUNTDOWN_SECONDS
    startTime_ = 0
    pauseStartTime_ = 0
    owner_ = nil
    resultCallback_ = nil
end

-- ============================================================================
-- Result reporting
-- ============================================================================

local function reportResult(success, msg)
    local callback = resultCallback_
    cleanup()
    if callback then
        callback(success, msg)
    else
        -- This internal C++ callback is intentionally absent from the public SDK typings.
        ---@diagnostic disable-next-line: undefined-field
        local legacyResult = sdk and sdk.__OnFakeAdResult
        if legacyResult then legacyResult(sdk, success, msg) end
    end
end

-- ============================================================================
-- Confirm dialog (early skip)
-- ============================================================================

local function hideConfirmDialog()
    if confirmPanel_ and overlay_ then
        overlay_:RemoveChild(confirmPanel_)
        confirmPanel_:Destroy()
        confirmPanel_ = nil
    end
end

local function showConfirmDialog()
    if confirmPanel_ then return end

    paused_ = true
    pauseStartTime_ = time.elapsedTime
    if videoPlayer_ then videoPlayer_:Pause() end

    -- Scale UI elements proportionally to screen size
    local uiScale = UI.GetScale()
    local logW = graphics.width / uiScale
    local logH = graphics.height / uiScale
    local portrait = logW < logH
    -- Portrait: scale by height (lots of vertical space); Landscape: scale by width (~50% for dialog)
    local s = portrait and math.max(1.0, logW / 350) or math.max(1.0, logW / 720)

    confirmPanel_ = Panel({
        position = "absolute",
        top = 0, left = 0, width = "100%", height = "100%",
        backgroundColor = {0, 0, 0, 179},
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "auto",
    })

    -- Cap dialog width at 85% of screen to prevent overflow in portrait
    local dialogW = math.min(math.floor(360 * s), math.floor(logW * 0.85))

    local dialog = Panel({
        width = dialogW,
        backgroundColor = {50, 50, 50, 240},
        borderRadius = math.floor(16 * s),
        padding = math.floor(32 * s),
        gap = math.floor(28 * s),
        alignItems = "center",
    })

    dialog:AddChild(Label({
        text = string.format(_tr("t_1T9MqQ3Q1bs5zWkv"), math.ceil(countdown_)),
        color = {255, 255, 255, 255},
        fontSize = math.floor(18 * s),
        textAlign = "center",
        width = "100%",
    }))

    local btnRow = Panel({
        flexDirection = "row",
        gap = math.floor(16 * s),
        justifyContent = "center",
        width = "100%",
    })

    btnRow:AddChild(Button({
        text = _tr("t_2hIAWSaB2saciIY6"),
        variant = "primary",
        fontSize = math.floor(16 * s),
        height = math.floor(40 * s),
        paddingHorizontal = math.floor(20 * s),
        onClick = function()
            hideConfirmDialog()
            -- Shift start time forward by pause duration so countdown doesn't jump
            startTime_ = startTime_ + (time.elapsedTime - pauseStartTime_)
            paused_ = false
            if videoPlayer_ then videoPlayer_:Play() end
        end,
    }))

    btnRow:AddChild(Button({
        text = _tr("t_N3kZzsTxMYh33aMS"),
        variant = "secondary",
        fontSize = math.floor(16 * s),
        height = math.floor(40 * s),
        paddingHorizontal = math.floor(20 * s),
        onClick = function()
            hideConfirmDialog()
            reportResult(false, _tr("t_D257fevbCWz04PXW"))
        end,
    }))

    dialog:AddChild(btnRow)
    confirmPanel_:AddChild(dialog)

    if overlay_ then
        overlay_:AddChild(confirmPanel_)
    end
end

-- ============================================================================
-- Skip button handler
-- ============================================================================

local function onSkipClicked()
    if confirmPanel_ then return end

    if completed_ then
        reportResult(true, "success")
    else
        showConfirmDialog()
    end
end

-- ============================================================================
-- Update loop
-- ============================================================================

local function onUpdate(dt)
    -- Update video texture
    if videoPlayer_ then
        videoPlayer_:Update()
    end

    if paused_ or completed_ then return end

    -- Countdown using wall-clock time (immune to Engine::timeStepRate_ scaling)
    countdown_ = COUNTDOWN_SECONDS - (time.elapsedTime - startTime_)
    if countdown_ <= 0 then
        countdown_ = 0
        completed_ = true

        -- Update skip button text
        if skipLabel_ then
            skipLabel_:SetText(_tr("t_XnOw08gAYEHhIQQx"))
        end

        -- Show reward label
        if rewardLabel_ then
            rewardLabel_:SetVisible(true)
        end

        return
    end

    -- Update skip button text with remaining seconds
    if skipLabel_ then
        skipLabel_:SetText(string.format(_tr("t_wJL6xdd3wUekOEAS"), math.ceil(countdown_)))
    end
end

-- ============================================================================
-- Build UI
-- ============================================================================

local function buildUI()
    -- Ensure UI system is initialized (games that don't use urhox-libs/UI won't have called UI.Init())
    if not UI.GetNVGContext() then
        UI.Init({ scale = function() return graphics:GetDPR() end })
    end

    local root = UI.GetRoot()
    if not root then
        root = Panel({
            width = "100%",
            height = "100%",
            pointerEvents = "box-none",
        })
        UI.SetRoot(root)
    end

    -- Scale UI elements proportionally to screen size
    local uiScale = UI.GetScale()
    local logW = graphics.width / uiScale
    local logH = graphics.height / uiScale
    local portrait = logW < logH
    local s = portrait and math.max(1.0, logW / 350) or math.max(1.0, logW / 720)

    -- Fullscreen overlay
    overlay_ = Panel({
        position = "absolute",
        top = 0,
        left = 0,
        width = "100%",
        height = "100%",
        backgroundColor = {0, 0, 0, 255},
        pointerEvents = "auto",
    })

    -- Video view (fills entire overlay)
    videoView_ = VideoView({
        position = "absolute",
        top = 0,
        left = 0,
        width = "100%",
        height = "100%",
    })
    overlay_:AddChild(videoView_)

    -- Skip capsule button (top-right)
    local skipBtn = Button({
        text = string.format(_tr("t_wJL6xdd3wUekOEAS"), COUNTDOWN_SECONDS),
        position = "absolute",
        top = math.floor(20 * s),
        right = math.floor(20 * s),
        height = math.floor(36 * s),
        borderRadius = math.floor(18 * s),
        backgroundColor = {0, 0, 0, 160},
        hoverBackgroundColor = {0, 0, 0, 200},
        pressedBackgroundColor = {0, 0, 0, 220},
        textColor = {255, 255, 255, 255},
        fontSize = math.floor(14 * s),
        paddingHorizontal = math.floor(16 * s),
        onClick = onSkipClicked,
    })
    skipLabel_ = skipBtn
    overlay_:AddChild(skipBtn)

    -- "奖励已领取" label (centered, hidden until countdown ends)
    rewardLabel_ = Label({
        text = _tr("t_531zyTGS5WsDooMz"),
        position = "absolute",
        top = math.floor(20 * s),
        left = 0,
        width = "100%",
        textAlign = "center",
        color = {76, 217, 100, 255},
        fontSize = math.floor(18 * s),
    })
    rewardLabel_:SetVisible(false)
    overlay_:AddChild(rewardLabel_)

    root:AddChild(overlay_)
    UI.PushOverlay(overlay_)
end

-- ============================================================================
-- Public API
-- ============================================================================

local function showVideo(url, owner, callback)
    ---@type VideoPlayer?
    local player = nil
    local loaded = false
    if VideoPlayer then
        player = VideoPlayer:new()
        loaded = player:Load(url, 1920, 1080)
        if not loaded then
            print("[FakeAd] VideoPlayer:Load failed: " .. tostring(url))
        end
    else
        print("[FakeAd] VideoPlayer class not available, showing black screen with countdown")
    end

    -- Reset state
    countdown_ = COUNTDOWN_SECONDS
    paused_ = false
    completed_ = false
    startTime_ = time.elapsedTime
    pauseStartTime_ = 0

    videoPlayer_ = player
    owner_ = owner
    resultCallback_ = callback
    if loaded then
        player:SetLoop(true)
        player:SetMuted(false)
        player:Play()
    end

    -- Build and show UI
    buildUI()

    -- Subscribe Update via an independent ScriptObject on a standalone Node.
    -- CRITICAL: Global SubscribeToEvent("Update", ...) goes through a single
    -- eventInvoker_ object; Urho3D's Object::SubscribeToEvent REPLACES the
    -- existing handler for the same event on the same object. This would
    -- overwrite the game's own "Update" handler, causing the game to freeze.
    -- Using a dedicated Node+ScriptObject gives FakeAd its own event subscriber.
    eventNode_ = Node()
    eventSO_ = eventNode_:CreateScriptObject("LuaScriptObject")
    eventSO_:SubscribeToEvent("Update", function(self, eventType, eventData)
        local dt = eventData["TimeStep"]:GetFloat()
        onUpdate(dt)
    end)
end

--- Show fake ad video with countdown and report through the legacy SDK callback.
---@param url string Video URL to play
function FakeAd.Show(url)
    if overlay_ then
        print("[FakeAd] Already showing, ignoring duplicate call")
        return
    end

    showVideo(url, nil, nil)
end

---@class FakeRewardedVideoAd
---@field url_ string?
---@field loaded_ boolean
---@field onClose_ fun(result: RewardedVideoAdCloseResult)?
---@field onError_ fun(error: RewardedVideoAdError)?
local PreviewAd = {}
PreviewAd.__index = PreviewAd

local function reportError(ad, code, message)
    if ad.onError_ then
        ad.onError_({ code = code, message = message })
    end
end

--- Simulate a successful load without requesting video resources.
---@param url string Preview video URL saved for show()
---@param callback? fun(result: RewardedVideoAdLoadResult) Called synchronously once with success=true
function PreviewAd:load(url, callback)
    self.url_ = url
    self.loaded_ = true
    if callback then callback({ success = true }) end
end

--- Show the preview video and countdown after a simulated load.
--- Closing after the countdown reports isEnded=true; confirmed early exit reports false.
function PreviewAd:show()
    if overlay_ then
        reportError(self, -1, "FakeAd is already showing")
        return
    end
    if not self.loaded_ then
        reportError(self, -1, "FakeAd is not loaded; call load() first")
        return
    end
    self.loaded_ = false
    showVideo(self.url_, self, function(isEnded)
        if self.onClose_ then self.onClose_({ isEnded = isEnded, extra = "" }) end
    end)
end

--- Clear the simulated load and close this object's overlay without firing onClose.
function PreviewAd:destroy()
    if owner_ == self then
        cleanup()
    end
    self.url_ = nil
    self.loaded_ = false
    self.onClose_, self.onError_ = nil, nil
end

--- Create the simulated-load preview backend. Listener registration/removal is owned by the SDK binding.
---@param onClose fun(result: RewardedVideoAdCloseResult) Main-thread close event receiver
---@param onError fun(error: RewardedVideoAdError) Main-thread failure receiver
---@return FakeRewardedVideoAd
function FakeAd.CreateRewardedVideoAd(onClose, onError)
    return setmetatable({
        loaded_ = false,
        onClose_ = onClose,
        onError_ = onError,
    }, PreviewAd)
end

return FakeAd
