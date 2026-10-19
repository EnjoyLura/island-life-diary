-- SystemNotification.lua - Lobby / Game Runtime system-notification registration API.
--
-- A Runtime registers one handler and dispatches different notifications by info.id. Returning
-- true means the Runtime accepted responsibility for displaying the notification. Missing
-- handlers, false/nil returns, and handler errors are reported as unhandled so HostSandbox
-- can use its Host-side fallback UI. Runtime-hide installs the legacy OnSystemDialog adapter
-- as the initial handler; a user RegisterHandler call replaces that adapter.

---@alias SystemNotificationId
---| "DisconnectChecking"
---| "Reconnecting"
---| "ConnectFailedRetry"
---| "ConnectInitiateFailed"
---| "MiddleGameJoinFailed"
---| "DuplicateLogin"
---| "ResourceExceeded"
---| "GameOpsKick"
---| "GameOpsClose"
---| "Kicked"
---| "VersionTooLow"
---| "PlayerBanned"
---| "StartupReconnect"

---@class SystemNotificationAction
---@field id string Stable action identifier returned to the notification owner.
---@field label string Default button label.

---@class SystemNotificationInfo
---@field id SystemNotificationId
---@field reason string|nil Only for Kicked: operator-supplied kick text.
---@field exitOnClose boolean|nil Optional caller-owned close behavior for dialogs.
---@field respond fun(actionId:string):boolean|nil Runtime-only one-shot action response.

local M = {
    ---@type table<string, SystemNotificationId>
    Id = {
        DisconnectChecking = "DisconnectChecking",
        Reconnecting = "Reconnecting",
        ConnectFailedRetry = "ConnectFailedRetry",
        ConnectInitiateFailed = "ConnectInitiateFailed",
        MiddleGameJoinFailed = "MiddleGameJoinFailed",
        DuplicateLogin = "DuplicateLogin",
        ResourceExceeded = "ResourceExceeded",
        GameOpsKick = "GameOpsKick",
        GameOpsClose = "GameOpsClose",
        Kicked = "Kicked",
        VersionTooLow = "VersionTooLow",
        PlayerBanned = "PlayerBanned",
        StartupReconnect = "StartupReconnect",
    },
}

-- 与 id 一一对应的默认展示。Dispatch 不传这些字段。
-- kind: error=Toast，kicked=被踢窗，dialog=普通模态。
M.Default = {
    DisconnectChecking = {
        kind = "error",
        title = _tr("t_1DAxD8GdU1DN2CuerG"),
        message = _tr("t_gzoLxoKygUKPIaLi"),
    },
    Reconnecting = {
        kind = "error",
        title = _tr("t_LUbJz4m8LgfbUEQY"),
        message = _tr("t_180lHQNCN18RMOw6pR"),
    },
    ConnectFailedRetry = {
        kind = "error",
        title = _tr("t_JsFLFxtWJMmrQSrA"),
        message = _tr("t_ybJe3ZS7z6kVyYon"),
    },
    ConnectInitiateFailed = {
        kind = "error",
        title = _tr("t_1DeKT71HG1E9lnPejU"),
        message = _tr("t_D0zZnbUyCVWMYBBq"),
    },
    MiddleGameJoinFailed = {
        kind = "error",
        title = _tr("t_PXc3h6TOP71ogQ4u"),
        message = _tr("t_9d7kuGIM9pCbXKUO"),
    },
    DuplicateLogin = {
        kind = "kicked",
        title = _tr("t_19Yloddhz19MhO7hgD"),
        message = _tr("t_AG5ZosmgASG1XhjH"),
    },
    ResourceExceeded = {
        kind = "kicked",
        title = _tr("t_HMrdRPNYGrL0J7Sj"),
        message = _tr("t_OhZmIPIHVMY8en"),
    },
    GameOpsKick = {
        kind = "kicked",
        title = _tr("t_XDDMANtmXdvBbZmp"),
        message = _tr("t_1GS2BY0xy1GKr9EaK7"),
    },
    GameOpsClose = {
        kind = "kicked",
        title = _tr("t_2Okqd8qF1tILerqD"),
        message = _tr("t_PUFyUHaFOyrilgYW"),
    },
    Kicked = {
        kind = "kicked",
        title = _tr("t_XDDMANtmXdvBbZmp"),
        message = _tr("t_uT1HhguLufBqSW5s"),
    },
    VersionTooLow = {
        kind = "dialog",
        title = _tr("t_13aklUcpc146DyfdE6"),
        message = _tr("t_aHrb0ITkaiYnJaNB"),
        exitOnClose = true,
    },
    PlayerBanned = {
        kind = "dialog",
        title = _tr("t_VpND4aYKVJwmP5bq"),
        message = _tr("t_15PUN3IxC14u3mAC83"),
    },
    StartupReconnect = {
        kind = "dialog",
        title = _tr("t_tMvMW5I4tFbei7XA"),
        message = _tr("t_145dobG5w13aAXPFpw"),
        primaryAction = { id = "reconnect", label = _tr("t_dM1IJOuidrPsq1Ui") },
        secondaryAction = { id = "lobby", label = _tr("t_11ItTKN9e11V3FzSfC") },
    },
}

local function copyAction(action)
    if type(action) ~= "table" then return nil end
    return { id = action.id, label = action.label }
end

--- 用 id 还原默认 title / message。Kicked.reason 原样带回，文案由 UI 拼。
---@param info SystemNotificationInfo|nil
---@return table
function M.Resolve(info)
    info = info or {}
    local spec = M.Default[info.id] or {}
    local reason = info.reason
    if type(reason) ~= "string" or reason == "" then
        reason = nil
    end
    return {
        id = info.id,
        kind = spec.kind,
        title = spec.title,
        message = spec.message,
        reason = reason,
        exitOnClose = info.exitOnClose == true or spec.exitOnClose == true,
        primaryAction = copyAction(spec.primaryAction),
        secondaryAction = copyAction(spec.secondaryAction),
    }
end

local bridge_ = rawget(_G, "systemNotificationBridge")
local handler_ = nil
local handlerSupportsChoices_ = false
local actionHandler_ = nil

local function writeError(message)
    if log and LOG_ERROR then
        log:Write(LOG_ERROR, "[SystemNotification] " .. tostring(message))
    else
        print("[SystemNotification] " .. tostring(message))
    end
end

local function dispatch(payloadJson)
    local decodeOk, info = pcall(cjson.decode, payloadJson or "")
    if not decodeOk or type(info) ~= "table" then
        writeError("invalid payload: " .. tostring(info))
        return false
    end

    if not handler_ then
        return false
    end

    local view = M.Resolve(info)
    local interactive = view.primaryAction ~= nil or view.secondaryAction ~= nil
    if interactive and (not handlerSupportsChoices_ or type(actionHandler_) ~= "function") then
        return false
    end
    if interactive then
        local responded = false
        info.respond = function(actionId)
            if responded then return false end

            local valid = (view.primaryAction and actionId == view.primaryAction.id)
                or (view.secondaryAction and actionId == view.secondaryAction.id)
            if not valid then
                writeError("invalid action '" .. tostring(actionId) .. "' for " .. tostring(info.id))
                return false
            end

            local callOk, accepted = pcall(actionHandler_, info.id, actionId)
            if not callOk then
                writeError("action handler failed: " .. tostring(accepted))
                return false
            end
            if accepted == false then return false end

            responded = true
            return true
        end
    end

    local callOk, handled = pcall(handler_, info)
    if not callOk then
        writeError("handler failed: " .. tostring(handled))
        return false
    end
    return handled == true
end

--- Register the action responder used by interactive system notifications.
---@param handler fun(notificationId:SystemNotificationId, actionId:string):boolean|nil
function M.RegisterActionHandler(handler)
    assert(type(handler) == "function", "SystemNotification action handler must be a function")
    actionHandler_ = handler
end

function M.UnregisterActionHandler()
    actionHandler_ = nil
end

--- Register the only system-notification handler for the current Game Runtime.
---@param handler fun(info:SystemNotificationInfo):boolean|nil
---@param options table|nil Set choices=true only when the handler renders and resolves interactive choices.
function M.RegisterHandler(handler, options)
    assert(type(handler) == "function", "SystemNotification handler must be a function")
    handler_ = handler
    handlerSupportsChoices_ = type(options) == "table" and options.choices == true
    if bridge_ and bridge_.setHandler then
        bridge_:setHandler(dispatch)
    else
        writeError("bridge is unavailable; Runtime binary may be older than this urhox-libs")
    end
end

function M.UnregisterHandler()
    handler_ = nil
    handlerSupportsChoices_ = false
    if bridge_ and bridge_.setHandler then
        bridge_:setHandler(nil)
    end
end

--- Dispatch a system notification to the currently registered handler.
--- Both HostSandbox and Game Runtime may produce notifications through this API.
---@param info SystemNotificationInfo
---@return boolean handled
function M.Dispatch(info)
    if not (bridge_ and bridge_.dispatch) then
        return false
    end

    local encodeOk, payloadJson = pcall(cjson.encode, info or {})
    if not encodeOk then
        writeError("encode failed: " .. tostring(payloadJson))
        return false
    end

    local dispatchOk, handled = pcall(bridge_.dispatch, bridge_, payloadJson)
    if not dispatchOk then
        writeError("dispatch failed: " .. tostring(handled))
        return false
    end
    return handled == true
end

return M
