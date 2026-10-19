-- LobbySystemDialogs.lua — 大厅系统弹窗默认渲染器。
--
-- 三个会话/连接级提示，由大厅控制层触发；项目脚本可用
-- Lobby.DefineDialog 覆盖视觉，本模块只负责没有自定义或自定义出错时的兜底。
--   - showDialog(deps, options)       模态遮罩 + 居中弹窗（主、次及专用关闭回调）
--   - showKickedDialog(deps, t, msg, onClose) 被踢提示（= showDialog 的语义包装）
--   - showError(deps, message)        错误 Toast（variant=error）
--
-- 纯函数、依赖注入：deps = { UI, root, theme, Toast }。模块不直接 require UI/Toast，
-- 故可在任意持有 UI 库的环境就地渲染，也便于注入假件做结构自测。

local M = {}

--- 模态弹窗：半透明遮罩 + 居中卡片，可选第二操作按钮。
--- @param deps table { UI, root, theme }
--- @param options table { icon, title, message, buttonText, onPrimary, onClose, secondaryButtonText, onSecondary }
function M.showDialog(deps, options)
    options = options or {}

    if not deps.root then
        log:Write(LOG_WARNING, "[LobbySystemDialogs] showDialog (UI not ready): " .. tostring(options.message))
        return
    end

    local UI = deps.UI
    local theme = deps.theme

    local overlay = UI.Panel {
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        backgroundColor = { 0, 0, 0, 200 },
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "auto",
    }

    local dialog = UI.Panel {
        width = "85%",
        maxWidth = 380,
        flexDirection = "column",
        backgroundColor = theme.surface,
        borderRadius = 16,
        padding = 32,
        gap = 16,
        alignItems = "center",
    }

    dialog:AddChild(UI.Label {
        text = options.icon or "⚠",
        fontSize = 48,
        color = theme.error,
    })

    dialog:AddChild(UI.Label {
        text = options.title or "",
        fontSize = 22,
        fontWeight = "bold",
        color = theme.text,
        textAlign = "center",
    })

    dialog:AddChild(UI.Label {
        text = options.message or "",
        fontSize = 14,
        color = theme.textSecondary,
        textAlign = "center",
        marginBottom = 8,
    })

    local closed = false
    local function close(callback)
        if closed then return end
        closed = true
        overlay:Destroy()
        if callback then callback() end
    end

    local primaryProps = {
        height = 44,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = theme.primary,
        borderRadius = 8,
        onClick = function() close(options.onPrimary or options.onClose) end,
    }
    -- 单按钮占满整行；双按钮与次按钮等分可用空间。
    if options.secondaryButtonText then primaryProps.flex = 1 else primaryProps.width = "100%" end
    local btn = UI.Button(primaryProps)
    btn:AddChild(UI.Label {
        text = options.buttonText or _tr("t_JJMNFId6IoqaIkhF"),
        fontSize = 16,
        fontWeight = "bold",
        color = { 255, 255, 255, 255 },
    })
    if options.secondaryButtonText then
        local actions = UI.Panel {
            width = "100%",
            flexDirection = "row",
            gap = 12,
        }
        local secondary = UI.Button {
            flex = 1,
            height = 44,
            alignItems = "center",
            justifyContent = "center",
            backgroundColor = theme.surface,
            borderColor = theme.textSecondary,
            borderWidth = 1,
            borderRadius = 8,
            onClick = function() close(options.onSecondary) end,
        }
        secondary:AddChild(UI.Label {
            text = options.secondaryButtonText,
            fontSize = 16,
            fontWeight = "bold",
            color = theme.text,
        })
        actions:AddChild(secondary)
        actions:AddChild(btn)
        dialog:AddChild(actions)
    else
        dialog:AddChild(btn)
    end

    overlay:AddChild(dialog)
    deps.root:AddChild(overlay)
    log:Write(LOG_INFO, "[LobbySystemDialogs] showDialog: " .. tostring(options.title) .. " - " .. tostring(options.message))
end

--- 被踢提示。
--- @param deps table { UI, root, theme }
--- @param title string
--- @param message string
--- @param onClose function|nil
function M.showKickedDialog(deps, title, message, onClose)
    M.showDialog(deps, { title = title, message = message, onClose = onClose })
end

--- 错误 Toast。
--- @param deps table { Toast }
--- @param message string
function M.showError(deps, message)
    if deps.Toast then
        deps.Toast.Show({
            message = message,
            variant = "error",
            duration = 4,
            showClose = true,
        })
        log:Write(LOG_INFO, "[LobbySystemDialogs] toast: " .. tostring(message))
    else
        log:Write(LOG_ERROR, "[LobbySystemDialogs] error: " .. tostring(message))
    end
end

return M
