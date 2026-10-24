-- Full-screen secondary pages in the scaffold-2d.lua widget tree; no simulation or SDK.
-- build() calls app:AddButton (Widgets.Button), never creates a second UI root.
-- Caller rebuilds a MODAL-ONLY button tree while app.modal is set; the first
-- transparent blocker also prevents clicks from reaching lower world widgets.
-- AddButton owns modal press forwarding and the post-drag click guard.
-- draw(): widget-local viewport w/h; internally scales to 450 virtual px.
-- Already-scaled callers pass 450, app.h. Do not scale it a second time.
-- scroll(): dy is virtual FINGER delta (+down); caller handles wheel conversion
-- and calls MarkUI after a changed offset. All scroll/hit bounds are virtual.
local UI = require("urhox-libs/UI")
local A = require("Game.Art")
local Skin = require("Game.UISkin")
local World = require("Game.World")
local Catalog = require("Game.Catalog")
local State = require("Game.State")
local ForestArt = require("Game.ForestArt")
---@class IslandMenus
local M = {}

local W, PAD, GAP = 450, 32, 10
local INK, CREAM, BRASS = A.ink, A.cream, { 202, 151, 67, 255 }
local MUTED, FAINT, PAPER = { 73, 104, 118, 255 }, { 218, 230, 231, 255 }, { 239, 248, 242, 255 }
local GREY, WHITE = { 141, 153, 156 }, { 255, 253, 236, 255 }
local SHOP_ORDER = { "bread", "salt", "fishCapacity", "shoreCapacity", "forestCapacity", "boat", "rod", "shovel" }
local SHOP_ICONS = { bread = "bread", salt = "salt", fishCapacity = "fish",
    shoreCapacity = "bucket", forestCapacity = "basket", boat = "boat", rod = "rod", shovel = "shovel" }

local function finite(v) return type(v) == "number" and v == v and math.abs(v) < math.huge end
local function clamp(v, low, high) return math.max(low, math.min(high, v)) end
local function weight(n)
    return (string.format("%.3f", n or 0):gsub("0+$", ""):gsub("%.$", "")) .. " kg"
end
local function money(n) return string.format("%.0f", n or 0) end
---@param app IslandApp
local function source(app) return app.profile.trip and app.profile.trip.items or app.profile.homeInventory end
---@param app IslandApp
local function tripName(app)
    local kind = app.profile.trip and app.profile.trip.kind
    return (kind == "shore" or kind == "forest") and "收工回家" or (kind == "coast" and "结束垂钓" or "返航")
end

---@param app IslandApp
local function menuState(app)
    if type(app.menu) ~= "table" then app.menu = {} end
    local menu = app.menu
    menu.quality = finite(menu.quality) and clamp(math.floor(menu.quality), 1, 4) or 1
    if menu.category ~= "fish" and menu.category ~= "shore" and menu.category ~= "forest" then
        menu.category = app.mode == "forest" and "forest" or app.mode == "shore" and "shore" or "fish"
    end
    menu.scroll = finite(menu.scroll) and math.max(0, menu.scroll) or 0
    if menu._modal ~= app.modal then menu._modal = app.modal; menu.scroll = 0 end
    return menu
end

local function speciesList(menu)
    local result = {}
    for _, species in ipairs(Catalog.list(menu.category)) do
        if species.quality == menu.quality then result[#result + 1] = species end
    end
    return result
end

local function selected(menu, list)
    for _, species in ipairs(list) do if species.id == menu.selected then return species end end
    return list[1]
end

local function grouped(items)
    local result, byId = {}, {}
    for _, item in ipairs(items or {}) do
        local species = Catalog.find(item.id)
        if species then
            local group = byId[item.id]
            if not group then
                group = { species = species, count = 0, grams = 0, value = 0, slots = 0 }
                byId[item.id] = group; result[#result + 1] = group
            end
            group.count = group.count + (item.count or 1)
            group.grams = group.grams + math.floor(item.weight * 1000 + .5)
            group.value = group.value + item.value; group.slots = group.slots + item.slots
        end
    end
    table.sort(result, function(a, b)
        if a.species.quality ~= b.species.quality then return a.species.quality > b.species.quality end
        return a.species.id < b.species.id
    end)
    return result
end

---@class IslandMenuLayout
---@field h number
---@field inset number
---@field top number
---@field height number
---@field footer number
---@field gridTop number
---@field gridBottom number
---@field cols integer
---@field cellH number
---@field cellW number

-- Shared geometry keeps static painting, hit regions and scroll limits identical.
---@param app IslandApp
---@return IslandMenuLayout
local function layout(app)
    local inset = app.hudTop or 0
    local h = (finite(app.h) and app.h or 800) - inset
    ---@type IslandMenuLayout
    local l = { h = h, inset = inset, top = 0, height = h, footer = h - 74,
        gridTop = 122, gridBottom = h - 100, cols = 2, cellH = 156, cellW = 0 }
    if app.modal == "encyclopedia" then
        l.gridTop, l.gridBottom, l.cols, l.cellH = 338, l.footer - 84, 4, 104
    elseif app.modal == "cargo" then
        l.gridTop, l.gridBottom, l.cellH = 264, l.footer - 34, 140
    elseif app.modal == "shop" then
        l.gridTop = 124
    end
    l.gridBottom = math.max(l.gridTop + 36, l.gridBottom)
    l.cellW = (W - PAD * 2 - GAP * (l.cols - 1)) / l.cols
    return l
end

---@param app IslandApp
local function content(app, menu)
    if app.modal == "encyclopedia" then return speciesList(menu) end
    if app.modal == "cargo" then return grouped(source(app)) end
    if app.modal == "shop" then return SHOP_ORDER end
    return {}
end

local function scrollLimit(l, count)
    local rows = math.ceil(count / l.cols)
    return math.max(0, rows * (l.cellH + GAP) - GAP - (l.gridBottom - l.gridTop))
end

local function textWidth(vg, text, size, bold)
    nvgFontFace(vg, UI.Theme.FontFace("sans", bold and "bold" or "normal"))
    nvgFontSize(vg, size)
    return nvgTextBounds(vg, 0, 0, tostring(text))
end

local function fit(vg, x, y, text, size, width, color, align, bold)
    text = tostring(text or "")
    local measured = textWidth(vg, text, size, bold ~= false)
    if measured > width then size = math.max(10, size * width / measured) end
    if textWidth(vg, text, size, bold ~= false) > width then
        local short = ""
        for _, code in utf8.codes(text) do
            local nextText = short .. utf8.char(code)
            if textWidth(vg, nextText .. "…", size, bold ~= false) > width then break end
            short = nextText
        end
        text = short .. "…"
    end
    A.text(vg, x, y, text, size, color or INK, align, bold)
end

local function wrap(vg, x, y, text, width, size, lines, color)
    local rows, row = {}, ""
    for _, code in utf8.codes(text or "") do
        local character = utf8.char(code)
        if character == "\n" or (row ~= "" and textWidth(vg, row .. character, size, false) > width) then
            rows[#rows + 1] = row; row = ""
        end
        if character ~= "\n" then row = row .. character end
    end
    if row ~= "" then rows[#rows + 1] = row end
    for i = 1, math.min(lines, #rows) do
        local line = rows[i]
        if i == lines and #rows > lines then line = line .. "…" end
        fit(vg, x, y + (i - 1) * (size + 5), line, size, width, color or MUTED, NVG_ALIGN_LEFT, false)
    end
end

local function creature(vg, species, x, y, size, known)
    if species.category == "forest" then
        ForestArt.Draw(vg,species,x,y,size,known)
    elseif species.category == "fish" then
        World.drawFish(vg, x, y, size, species, 0, not known)
    else
        -- drawCreature has no shadow argument: a detached grey palette makes
        -- unrecorded shore creatures monochrome without modifying Catalog.
        World.drawCreature(vg, x, y, size,
            known and species or { shape = species.shape, color = GREY }, 0)
    end
end

---@param app IslandApp
local function button(app, id, x, y, w, h, props)
    return app:AddButton("menu." .. tostring(app.modal) .. "." .. id, x, y + (app.hudTop or 0), w, h, props)
end

---@param app IslandApp
local function actionButton(app, id, x, y, w, text, sub, icon, tone, enabled, action)
    button(app, id, x, y, w, 52, {
        text = text, sub = sub, icon = icon, tone = enabled and tone or "cream", disabled = not enabled,
        action = function()
            if enabled then action() end
        end,
        draw = function(vg, bw, bh, down, hover)
            if not Skin.Button(vg,0,0,bw,bh,tone,down,hover,not enabled)then A.plate(vg,0,0,bw,bh,enabled and tone or nil,down)end
            if icon then A.icon(vg, icon, 24, bh / 2 - 2, 25) end
            local tx = icon and (bw + 30) / 2 or bw / 2
            fit(vg, tx, sub and 19 or 25, text, 16, bw - (icon and 52 or 20),
                enabled and INK or MUTED, NVG_ALIGN_CENTER)
            if sub then fit(vg, tx, 38, sub, 10.5, bw - (icon and 52 or 20), MUTED, NVG_ALIGN_CENTER, false) end
        end,
    })
end

---@param app IslandApp
local function back(app, l)
    actionButton(app, "back", PAD, l.footer, 98, "返回", nil, "back", "cream", true,
        function() app:CloseModal() end)
end

---@param app IslandApp
local function stateAction(app, fn, ...)
    local ok, message = fn(app.profile, ...)
    if ok then app:Save() end
    app:Toast(message); app:MarkUI()
    return ok
end

-- Partially visible rows have clipped drawing AND clipped widget hit bounds;
-- scrolling never puts an invisible card over the fixed header or footer.
---@param app IslandApp
---@param l IslandMenuLayout
local function gridButtons(app, l, list, drawCard, clicked, disabled)
    local offset = app.menu.scroll
    for i, entry in ipairs(list) do
        local x = PAD + ((i - 1) % l.cols) * (l.cellW + GAP)
        local y = l.gridTop + math.floor((i - 1) / l.cols) * (l.cellH + GAP) - offset
        local top, bottom = math.max(y, l.gridTop), math.min(y + l.cellH, l.gridBottom)
        if bottom > top then
            local shift, cellH, cellW = y - top, l.cellH, l.cellW
            button(app, "cell." .. i, x, top, cellW, bottom - top, {
                disabled = disabled and disabled(entry) or false,
                action = function() if clicked then clicked(entry) end end,
                draw = function(vg, bw, bh, down, hover)
                    nvgSave(vg); nvgIntersectScissor(vg, 0, 0, bw, bh)
                    nvgTranslate(vg, 0, shift)
                    drawCard(vg, cellW, cellH, entry, down, hover)
                    nvgRestore(vg)
                end,
            })
        end
    end
end

---@param app IslandApp
local function shopStatus(app, key)
    local p = app.profile
    if p.trip then return false, "回岛后购买" end
    if key == "shovel" and p.shovel then return false, "已拥有" end
    -- State exposes prices/effects but not its caps; mirror those presentation
    -- limits here. buy() remains authoritative, including after stale clicks.
    local field = ({ boat = "boatLevel", rod = "rodLevel" })[key] or key
    local limit = ({ bread = 999, salt = 9999, fishCapacity = 200,
        shoreCapacity = 200, forestCapacity = 200, boat = 5, rod = 5 })[key]
    if limit and p[field] + State.shop[key].amount > limit then return false, "已达上限" end
    if p.coins < State.price(p, key) then return false, "金币不足" end
    return true, "点击购买"
end

local function shopInfo(p, key)
    local product = State.shop[key]
    if key == "bread" then return "恢复 " .. product.restore .. " 体力", "现有 " .. p.bread .. " 个" end
    if key == "salt" then return "补充 " .. product.amount .. " 份盐", "现有 " .. p.salt .. " 份" end
    if key == "fishCapacity" then return "永久增加 " .. product.amount .. " 格", "鱼护 " .. p.fishCapacity .. " 格" end
    if key == "shoreCapacity" then return "永久增加 " .. product.amount .. " 格", "水桶 " .. p.shoreCapacity .. " 格" end
    if key == "forestCapacity" then return "永久增加 " .. product.amount .. " 格", "背篓 " .. p.forestCapacity .. " 格" end
    if key == "boat" then return "小船等级 +1", "当前 Lv." .. p.boatLevel end
    if key == "rod" then return "鱼竿等级 +1", "当前 Lv." .. p.rodLevel end
    return "用于洞口与土堆挖掘", p.shovel and "已拥有铁锹" or "永久工具"
end

---@param app IslandApp
local function candidate(app)
    local pending = app.pendingCatch
    if type(pending) ~= "table" or not finite(pending.weight) then return nil end
    return State.createCatch(pending.id, pending.weight)
end

---@param app IslandApp
local function keepStatus(app, item)
    if not item then return false, "当前没有可收入的鱼" end
    local trip = app.profile.trip
    if not trip then return false, "行程已结束，请放生后返回" end
    local species = Catalog.find(item.id)
    if not species then return false, "收获资料不可用" end
    if species.category ~= (trip.kind == "shore" and "shore" or "fish") then
        return false, "该收获不属于当前玩法"
    end
    local remaining = State.capacity(app.profile) - State.used(app.profile)
    if item.slots > remaining then return false, "容量不足，还差 " .. (item.slots - remaining) .. " 格" end
    return true, "收入后，本趟不可主动移出"
end

---@param app IslandApp
local function encyclopediaButtons(app, l, list)
    local menu = app.menu
    for i, cat in ipairs({ "fish", "shore", "forest" }) do
        local active = menu.category == cat
        button(app, "category." .. cat, 220 + (i - 1) * 66, 64, 62, 31, {
            text=cat == "forest" and "林产" or cat == "fish" and "鱼类" or "海货",
            tone=active and "gold" or "cream",action=function()
                menu.category = cat; menu.selected = nil; menu.scroll = 0; app:MarkUI()
            end})
    end
    gridButtons(app, l, list, function(vg, w, h, species, down)
        local known = app.profile.discoveries[species.id] == true
        local active = menu.selected == species.id
        A.plate(vg, 0, down and 1 or 0, w, h - 2, active and "gold" or nil, down)
        A.rect(vg, 5, 6, w - 10, 65, known and { 232, 245, 242, 255 } or FAINT, 5)
        Skin.Quality(vg,0,0,w,h-2,species.quality,active)
        creature(vg, species, w / 2, 39, w * .8, known)
        if not known then Skin.Draw(vg,"STA-locked",5,6,w-10,65)end
        if not known then A.text(vg, w / 2, 42, "?", 22, CREAM, NVG_ALIGN_CENTER) end
        fit(vg, w / 2, 85, known and species.name or "未发现", 12, w - 10, INK, NVG_ALIGN_CENTER)
        if active then A.circle(vg, w - 12, 16, 7, A.gold, INK, 1); A.icon(vg, "check", w - 12, 16, 10) end
    end, function(species) menu.selected = species.id; app:MarkUI() end)
    for quality = 1, 4 do
        local q = quality
        button(app, "quality." .. q, PAD + (q - 1) * 99, l.footer - 64, 89, 44, {
            action = function() menu.quality = q; menu.selected = nil; menu.scroll = 0; app:MarkUI() end,
            draw = function(vg, w, h, down)
                if not Skin.Button(vg,0,0,w,h,nil,down,false,false,"BTN-tab",menu.quality==q)then A.plate(vg,0,0,w,h-2,menu.quality==q and"gold"or nil,down)end
                A.circle(vg, 16, 20, 5, A.quality[q], INK, 1)
                A.text(vg, 51, 21, A.qualityNames[q], 14, INK, NVG_ALIGN_CENTER)
            end,
        })
    end
    back(app, l)
    local reward = State.rewards[app.profile.rewardClaimed + 1]
    local count = State.discoveryCount(app.profile)
    local eligible = reward ~= nil and count >= reward.threshold
    local progress = reward and (math.min(count, reward.threshold) .. "/" .. reward.threshold .. " 种 · " .. reward.coins .. " 金币") or "全部里程碑已完成"
    actionButton(app, "reward", 142, l.footer, 276, eligible and "领取图鉴奖励" or "图鉴奖励", progress,
        "chest", "gold", eligible, function() stateAction(app, State.claimEncyclopedia) end)
end

---@param app IslandApp
local function cargoButtons(app, l, list)
    gridButtons(app, l, list, function(vg, w, h, group, down)
        local species = group.species
        A.plate(vg, 0, 0, w, h - 2, nil, down)
        A.rect(vg, 5, 6, w - 10, 62, { 232, 245, 242, 255 }, 5)
        Skin.Quality(vg,0,0,w,h-2,species.quality)
        creature(vg, species, w / 2, 37, 90, true)
        A.icon(vg, "lock", 17, 18, 17)
        Skin.Draw(vg,"STA-quantity",w-58,8,48,23)
        fit(vg, w - 15, 19, "×" .. group.count, 14, 40, CREAM, NVG_ALIGN_RIGHT)
        fit(vg, 12, 82, species.name, 15, w - 24, INK)
        A.text(vg, 12, 104, weight(group.grams / 1000), 12, MUTED)
        A.icon(vg, "coin", w - 66, 105, 15)
        fit(vg, w - 11, 105, money(group.value), 12, 47, INK, NVG_ALIGN_RIGHT)
        A.text(vg, 12, 123, "占用 " .. group.slots .. " 格", 11, MUTED)
    end, function() app:Toast(app.profile.trip and "已收入锁定，返程后可出售" or "已带回仓库，点击一键出售") end)
    back(app, l)
    local trip, total = app.profile.trip, State.totals(source(app))
    actionButton(app, "finish", 142, l.footer, 276, trip and tripName(app) or "一键出售",
        trip and "带回仓库，回岛后出售" or (money(total.value) .. " 金币"), trip and "home" or "coin", "gold",
        trip ~= nil or total.count > 0, function()
            if app.profile.trip then app:OpenModal("return") else app:SellAll() end
        end)
end

---@param app IslandApp
local function shopButtons(app, l)
    gridButtons(app, l, SHOP_ORDER, function(vg, w, h, key, down)
        local enabled, status = shopStatus(app, key)
        local detail, current = shopInfo(app.profile, key)
        A.plate(vg, 0, 0, w, h - 2, nil, down)
        A.circle(vg, w / 2, 34, 25, PAPER, BRASS, 1.5)
        A.icon(vg, SHOP_ICONS[key], w / 2, 34, 31)
        fit(vg, w / 2, 72, State.shop[key].name, 16, w - 18, INK, NVG_ALIGN_CENTER)
        fit(vg, w / 2, 92, detail, 11, w - 16, MUTED, NVG_ALIGN_CENTER, false)
        fit(vg, w / 2, 108, current, 11, w - 16, MUTED, NVG_ALIGN_CENTER, false)
        if not Skin.Draw(vg,"STA-badge",9,h-37,w-18,26,enabled and"gold"or"muted")then A.rect(vg,9,h-37,w-18,26,enabled and A.gold or FAINT,5)end
        fit(vg, w / 2, h - 24, enabled and (money(State.price(app.profile, key)) .. " 金币 · 购买") or status,
            12, w - 24, enabled and INK or MUTED, NVG_ALIGN_CENTER)
    end, function(key)
        if shopStatus(app, key) then stateAction(app, State.buy, key) end
    end, function(key) return not shopStatus(app, key) end)
    back(app, l)
end

---Build only modal controls. The owner supplies a fresh widget list per rebuild.
---@param app IslandApp
function M.build(app)
    app.menuScrollTop, app.menuScrollBottom = nil, nil
    if not app.modal then return end
    local menu, l = menuState(app), layout(app)
    local list = content(app, menu)
    menu.scroll = clamp(menu.scroll, 0, scrollLimit(l, #list))
    if app.modal == "encyclopedia" then
        local species = selected(menu, list)
        menu.selected = species and species.id or nil
    end
    button(app, "blocker", 0, -l.inset, W, l.h + l.inset, { draw = function() end, action = function() end })
    if app.modal == "encyclopedia" or app.modal == "cargo" or app.modal == "shop" then
        app.menuScrollTop, app.menuScrollBottom = l.gridTop + l.inset, l.gridBottom + l.inset
    end
    if app.modal == "encyclopedia" then encyclopediaButtons(app, l, list)
    elseif app.modal == "cargo" then cargoButtons(app, l, list)
    elseif app.modal == "shop" then shopButtons(app, l)
    elseif app.modal == "food" then
        back(app, l)
        local p = app.profile
        local reason = p.stamina >= 100 and "体力已满" or (p.bread == 0 and "没有面包了" or "吃一个面包")
        actionButton(app, "eat", 142, l.footer, 276, reason,
            "恢复 " .. math.min(State.shop.bread.restore, 100 - p.stamina) .. " 点体力", "bread", "gold",
            p.stamina < 100 and p.bread > 0, function() stateAction(app, State.eat) end)
    elseif app.modal == "return" then
        actionButton(app, "stay", PAD, l.footer, 158, "继续探索", nil, nil, "cream", true, function() app:CloseModal() end)
        actionButton(app, "confirm", 202, l.footer, 216, "确认" .. tripName(app), nil, "home", "gold", app.profile.trip ~= nil,
            function() if app.profile.trip then app:ReturnHome() end end)
    elseif app.modal == "catch" then
        local item = candidate(app)
        local enabled = keepStatus(app, item)
        if item then
            actionButton(app, "release", PAD, l.footer, 158, "放生", "这条鱼回到海里", nil, "cream", true,
                function() if app.pendingCatch then app:ReleaseCatch() end end)
        else back(app, l) end
        actionButton(app, "keep", 202, l.footer, 216, enabled and "收入鱼护" or "无法收入",
            item and ("占用 " .. item.slots .. " 格") or "收获信息不可用", "fish", "gold", enabled, function()
                if keepStatus(app, candidate(app)) then app:KeepCatch() end
            end)
    else
        actionButton(app, "close", PAD, l.footer, W - PAD * 2, "知道了，继续游玩", nil, "check", "gold", true,
            function() app:CloseModal() end)
    end
end

local function frame(vg, l, title, subtitle)
    A.rect(vg, 0, 0, W, l.h, {228,243,244,255})
    Skin.Draw(vg,"PLT-page",12,4,W-24,l.h-10)
    fit(vg, PAD + 2, l.top + 28, title, 24, 218, INK)
    if subtitle then fit(vg, PAD + 2, l.top + 58, subtitle, 11, 374, MUTED, nil, false) end
    A.line(vg, { PAD, l.footer - 10, W - PAD, l.footer - 10 }, { 172, 208, 212, 255 }, 1)
end

---@param app IslandApp
local function scrollChrome(vg, app, l, list)
    A.rect(vg, 28, l.gridTop - 3, 394, l.gridBottom - l.gridTop + 6, { 226, 239, 236, 255 }, 7)
    local limit = scrollLimit(l, #list)
    if limit > 0 then
        local viewport = l.gridBottom - l.gridTop
        ---@type number
        local thumb = math.max(25, viewport * viewport / (viewport + limit))
        Skin.Draw(vg,"NAV-scroll",423,l.gridTop,6,viewport)
        Skin.Draw(vg,"NAV-scroll",423,l.gridTop+(viewport-thumb)*clamp(app.menu.scroll/limit,0,1),6,thumb,"thumb")
    end
end

---@param app IslandApp
local function encyclopediaInfo(vg, app, l, list)
    local species = selected(app.menu, list)
    A.plate(vg, PAD, 102, 386, 208)
    if not species then
        A.text(vg, W / 2, 196, "这个品质还没有物种资料", 17, MUTED, NVG_ALIGN_CENTER)
        return
    end
    local known = app.profile.discoveries[species.id] == true
    A.rect(vg, 40, 110, 174, 111, { 217, 232, 220, 255 }, 7)
    creature(vg, species, 127, 164, 162, known)
    if not known then A.text(vg, 127, 167, "?", 32, CREAM, NVG_ALIGN_CENTER) end
    fit(vg, 228, 125, species.name, 22, 177, INK)
    A.circle(vg, 234, 151, 4, A.quality[species.quality])
    A.text(vg, 246, 151, A.qualityNames[species.quality] .. " · " .. (known and "已收录" or "未发现"), 11, MUTED)
    wrap(vg, 228, 177, species.desc, 176, 11, 3)
    A.text(vg, 46, 238, "重量范围", 10.5, MUTED)
    fit(vg, 46, 258, weight(species.minWeight):gsub(" kg", "") .. "—" .. weight(species.maxWeight), 17, 177, INK)
    A.text(vg, 236, 238, "出售单价", 10.5, MUTED)
    A.icon(vg, "coin", 243, 258, 18)
    A.text(vg, 260, 258, money(species.price) .. " 金币/kg", 16, INK)
    A.rect(vg, 43, 279, 364, 23, species.unlocked and { 203, 226, 201, 255 } or FAINT, 5)
    A.icon(vg, species.unlocked and "check" or "lock", 57, 291, 15)
    fit(vg, 73, 291, "出现区域：" .. species.region .. (species.unlocked and " · 已解锁" or " · 未解锁"),
        11.5, 324, species.unlocked and { 38, 110, 91, 255 } or MUTED)
    local total, found = 0, 0
    for _, s in ipairs(Catalog.list(app.menu.category)) do
        total = total + 1; if app.profile.discoveries[s.id] then found = found + 1 end
    end
    A.text(vg, PAD + 2, 324, "物种档案", 13, INK)
    A.text(vg, 416, 324, "已发现 " .. found .. "/" .. total, 11, MUTED, NVG_ALIGN_RIGHT)
end

local function summary(vg, total, top)
    local values = { { "数量 / 种类", total.count .. " 件 · " .. total.kinds .. " 种" },
        { "合计重量", weight(total.weight) }, { "预计售价", money(total.value) .. " 金币" } }
    for i, entry in ipairs(values) do
        local x = PAD + (i - 1) * 132
        if not Skin.Draw(vg,"PLT-summary",x,top,122,63)then A.rect(vg,x,top,122,63,PAPER,6)end
        A.text(vg, x + 61, top + 16, entry[1], 10.5, MUTED, NVG_ALIGN_CENTER)
        fit(vg, x + 61, top + 40, entry[2], 16, 112, INK, NVG_ALIGN_CENTER)
    end
end

---@param app IslandApp
local function cargoInfo(vg, app, l, list)
    local p, total = app.profile, State.totals(source(app))
    A.icon(vg, p.trip and(p.trip.kind=="forest"and"basket"or p.trip.kind=="shore"and"bucket"or"cooler")or"bag", 49, 117, 30)
    local capacity = p.trip and State.capacity(p) or nil
    A.text(vg, 73, 111, capacity and ("容量 " .. total.slots .. "/" .. capacity) or "已带回岛上的收获", 17, INK)
    A.text(vg, 73, 134, capacity and ("剩余 " .. math.max(0, capacity - total.slots) .. " 格") or ("仓库占格 " .. total.slots .. " · 可出售"), 11, MUTED)
    A.bar(vg, PAD, 154, 386, 12, capacity and total.slots / capacity or (total.count > 0 and 1 or 0), A.quality[1])
    summary(vg, total, 179)
    A.icon(vg, "lock", 42, l.footer - 25, 14)
    fit(vg, 57, l.footer - 25, p.trip and "已收入锁定 · 返程后可出售" or "一键出售会清空仓库并增加金币", 11, 357, MUTED)
    if #list == 0 then
        A.icon(vg, "bucket", W / 2, (l.gridTop + l.gridBottom) / 2 - 20, 60)
        A.text(vg, W / 2, (l.gridTop + l.gridBottom) / 2 + 40, p.trip and "收获还在等你发现" or "仓库空空，去海边看看吧", 15, MUTED, NVG_ALIGN_CENTER)
        if not p.trip and app.lastTotals and app.lastTotals.count then
            fit(vg, W / 2, (l.gridTop + l.gridBottom) / 2 + 66,
                "上趟带回 " .. app.lastTotals.count .. " 件 · " .. weight(app.lastTotals.weight), 11, 342, MUTED, NVG_ALIGN_CENTER)
        end
    end
end

---@param app IslandApp
local function foodInfo(vg, app, l)
    local p = app.profile
    A.circle(vg, 104, l.top + 144, 43, PAPER, BRASS, 2)
    A.icon(vg, "bread", 104, l.top + 143, 66)
    A.text(vg, 176, l.top + 121, "面包 ×" .. p.bread, 23, INK)
    A.text(vg, 176, l.top + 151, "每个恢复 " .. State.shop.bread.restore .. " 点体力", 13, MUTED)
    A.icon(vg, "energy", 48, l.top + 203, 27)
    A.bar(vg, 72, l.top + 194, 268, 19, p.stamina / 100, A.quality[1])
    A.text(vg, 403, l.top + 203, money(p.stamina) .. "/100", 13, INK, NVG_ALIGN_RIGHT)
    wrap(vg, 45, l.top + 238,
        p.bread == 0 and "面包用完了，回岛后可在杂货铺补充。体力为零仍然可以移动和返程。"
            or "体力已满时不会消耗面包。补充后可继续抛竿或采集。", 359, 12, 2)
end

---@param app IslandApp
local function returnInfo(vg, app, l)
    local trip = app.profile.trip
    local total = trip and State.totals(trip.items) or app.lastTotals or State.totals(nil)
    A.icon(vg, "home", 225, l.top + 109, 62)
    summary(vg, total, l.top + 161)
    A.text(vg, 225, l.top + 254, "所有收获将带回岛上仓库", 17, INK, NVG_ALIGN_CENTER)
    wrap(vg, 58, l.top + 282, "返程不会自动出售，也不会消耗体力。回岛后可到收购摊一键卖货。", 334, 12, 2)
end

---@param app IslandApp
local function catchInfo(vg, app, l)
    local item = candidate(app)
    local species = item and Catalog.find(item.id) or nil
    if not item or not species then
        A.text(vg, 225, l.top + 142, "当前没有待处理的收获", 18, MUTED, NVG_ALIGN_CENTER)
        return
    end
    local p = app.profile
    -- App discovers at landing time, before opening the catch modal.
    local isNew = app.newDiscovery
    if type(isNew) ~= "boolean" then isNew = p.discoveries[item.id] ~= true end
    A.text(vg, 225, l.top + 75, isNew and "新发现！点亮海岛图鉴" or "又收获了一条好鱼", 13,
        isNew and { 157, 104, 26, 255 } or MUTED, NVG_ALIGN_CENTER)
    A.ellipse(vg, 225, l.top + 166, 137, 66, { 222, 234, 212, 255 }, BRASS, 1.5)
    creature(vg, species, 225, l.top + 163, 231, true)
    if not Skin.Draw(vg,"STA-rarity",170,l.top+224,110,22,({"default","blue","purple","orange"})[item.quality])then A.rect(vg,170,l.top+224,110,22,A.quality[item.quality],5)end
    A.text(vg, 225, l.top + 235, A.qualityNames[item.quality], 12, WHITE, NVG_ALIGN_CENTER)
    local entries = { { "重量", weight(item.weight) }, { "预计售价", money(item.value) .. " 金币" }, { "占用容量", item.slots .. " 格" } }
    for i, entry in ipairs(entries) do
        local x = PAD + (i - 1) * 132
        A.rect(vg, x, l.top + 261, 122, 61, PAPER, 6)
        A.text(vg, x + 61, l.top + 277, entry[1], 11, MUTED, NVG_ALIGN_CENTER)
        fit(vg, x + 61, l.top + 302, entry[2], 18, 112, INK, NVG_ALIGN_CENTER)
    end
    wrap(vg, 47, l.top + 346, species.desc, 356, 12, 2)
    local used, capacity = State.used(p), State.capacity(p)
    local enabled, reason = keepStatus(app, item)
    A.text(vg, 44, l.footer - 69, "鱼护 " .. used .. "/" .. capacity, 13, INK)
    local status = enabled and "可以收入" or (p.trip and "无法收入" or "行程已结束")
    A.text(vg, 407, l.footer - 69, status, 12,
        enabled and { 38, 126, 97, 255 } or { 175, 75, 54, 255 }, NVG_ALIGN_RIGHT)
    A.bar(vg, 43, l.footer - 51, 364, 12, capacity > 0 and used / capacity or 0, enabled and A.quality[1] or A.gold)
    fit(vg, 225, l.footer - 25, reason, 11.5, 360, enabled and MUTED or { 175, 75, 54, 255 }, NVG_ALIGN_CENTER)
end

---@param app IslandApp
local function helpInfo(vg, app, l)
    local rows = {
        { "compass", "环顾小岛", "拖动浏览、双指缩放，点击建筑或海滩选择玩法。" },
        { "boat", "出海寻鱼", "拖动海面出现方向轮盘；避开礁石，观察鱼影寻找钓点。" },
        { "rod", "抛竿与溜鱼", "点按直接抛竿，长按拖动瞄准。上钩后按住加力，松手缓力，保持在绿色区。" },
        { "shovel", "走近再互动", "赶海靠近目标点击气泡：夹取、撒盐或用铁锹挖掘。" },
        { "lock", "收获入库就锁定", "确认收入后本趟不能移出；可以放生刚钓起的鱼，给更好的收获留位置。" },
        { "bread", "吃面包继续探索", "体力不足时补充食物；移动、查阅菜单和返程不会消耗体力。" },
        { "coin", "带回岛上再卖货", "渔获页返航或收工，把收获带回仓库，在收购摊出售换取金币。" },
        { "leaf", "林间采集", "双摇杆探索月牙林，走近后点击蘑菇、浆果、药草或枝木。背篓满了可随时收工回家。" },
    }
    local available = l.footer - (l.top + 88) - 24
    ---@type number
    local spacing = math.min(86, available / #rows)
    for i, entry in ipairs(rows) do
        local y = l.top + 91 + (i - 1) * spacing
        A.icon(vg, entry[1], 52, y + 10, 26)
        A.text(vg, 77, y + 2, entry[2], 15, INK)
        wrap(vg, 77, y + 23, entry[3], 327, spacing < 70 and 10.5 or 12, 2)
    end
end

---Paint the modal surface and information; controls paint in Widgets.Button.
---@param app IslandApp
---@param vg NVGContextWrapper
---@param w number Widget-local viewport width (450 if already virtual).
---@param h number Widget-local viewport height.
function M.draw(app, vg, w, h)
    if not app.modal or not vg or not finite(w) or not finite(h) or w <= 0 or h <= 0 then return end
    local menu, l = menuState(app), layout(app)
    local list = content(app, menu)
    local catchItem = app.modal == "catch" and candidate(app) or nil
    local catchSpecies = catchItem and Catalog.find(catchItem.id) or nil
    local title = ({ encyclopedia = "海岛图鉴", cargo = app.profile.trip and
        (app.profile.trip.kind == "forest" and "林间采集背篓" or app.profile.trip.kind == "shore" and "本趟收获" or "本趟渔获") or "返程仓库",
        shop = "海边杂货铺", food = "补充体力", ads = "补给说明", help = "海岛游玩指南",
        ["return"] = "准备" .. tripName(app), catch = catchSpecies and catchSpecies.name or "收获信息" })[app.modal] or "海岛提示"
    local subtitle = ({ encyclopedia = "每一次发现，都让小岛更丰富", cargo = "好收获，带回家", shop = "升级装备，带着补给再出发",
        food = "吃点面包，让下一次收获更从容", ["return"] = "按自己的节奏，满载或尽兴就回家" })[app.modal]
    nvgSave(vg); nvgScale(vg, w / W, w / W)
    nvgTranslate(vg, 0, l.inset); nvgIntersectScissor(vg, 0, 0, W, l.h)
    frame(vg, l, title, subtitle)
    if app.modal == "encyclopedia" or app.modal == "cargo" or app.modal == "shop" then scrollChrome(vg, app, l, list) end
    if app.modal == "encyclopedia" then encyclopediaInfo(vg, app, l, list)
    elseif app.modal == "cargo" then cargoInfo(vg, app, l, list)
    elseif app.modal == "shop" then
        A.icon(vg, "coin", 326, l.top + 27, 23)
        fit(vg, 408, l.top + 28, money(app.profile.coins), 19, 66, INK, NVG_ALIGN_RIGHT)
        fit(vg, 413, l.footer + 24, app.profile.trip and "请先返程，再来添置装备" or "永久容量与等级升级，下趟出行生效", 11, 268, MUTED, NVG_ALIGN_RIGHT)
    elseif app.modal == "food" then foodInfo(vg, app, l)
    elseif app.modal == "return" then returnInfo(vg, app, l)
    elseif app.modal == "catch" then catchInfo(vg, app, l)
    elseif app.modal == "help" then helpInfo(vg, app, l)
    elseif app.modal == "ads" then
        A.icon(vg, "video", 225, l.top + 114, 53)
        A.text(vg, 225, l.top + 165, "激励视频暂未接入", 20, INK, NVG_ALIGN_CENTER)
        wrap(vg, 55, l.top + 204, "当前原型不会播放广告或发放广告奖励。关闭窗口后，可以继续游玩或正常返程。", 340, 13, 3)
    else A.text(vg, 225, l.top + 120, "此菜单暂不可用", 17, MUTED, NVG_ALIGN_CENTER) end
    nvgRestore(vg)
end

---Returns whether offset changed. No save, rebuild, SDK or world mutation here.
---@param app IslandApp
---@param dy number Virtual finger delta (+down, -up).
---@return boolean
function M.scroll(app, dy)
    if not app.modal or not finite(dy) then return false end
    if app.modal ~= "encyclopedia" and app.modal ~= "cargo" and app.modal ~= "shop" then return false end
    local menu, l = menuState(app), layout(app)
    local limit = scrollLimit(l, #content(app, menu))
    local nextOffset = clamp(menu.scroll - dy, 0, limit)
    if nextOffset == menu.scroll then return false end
    menu.scroll = nextOffset
    return true
end

return M
