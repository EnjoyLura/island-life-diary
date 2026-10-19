-- Pure domain layer for scaffold-2d.lua's CreateGameContent integration point.
-- No engine globals, IO, UI, SDK, timers or reward-video simulation.
-- All mutators use M.fn(profile, ...). Callers own saving and encounter selection.
-- Prices/milestones below are prototype balance, not final design decisions.
local Catalog = require("Game.Catalog")

---@class IslandCatch
---@field id string
---@field weight number Total kg, rounded to 0.001 kg.
---@field value integer Total integer coins, rounded once per catch.
---@field slots integer
---@field count integer Always 1; stack presentation belongs to the view.
---@field quality integer

---@class IslandTotals
---@field count integer
---@field weight number
---@field value integer
---@field slots integer
---@field kinds integer

---@class IslandTrip
---@field kind string sea | coast | shore
---@field items IslandCatch[]
---@field capacity integer Snapshot at departure; permanent upgrades apply next trip.
---@field doubled boolean Persisted flag only; this module never grants this reward.
---@field fuel number
---@field hull number
---@field elapsed number

---@class IslandStats
---@field trips integer Completed outings, including empty outings.
---@field fish integer Fish kept (released fish are not counted here).
---@field shore integer Shore creatures kept.
---@field sold integer Number of individual catches sold.
---@field earned integer Coins from sales AND encyclopedia rewards.
---@field spent integer Coins spent at the shop.

---@class IslandProfile
---@field coins integer
---@field stamina number
---@field bread integer
---@field salt integer
---@field fishCapacity integer
---@field shoreCapacity integer
---@field boatLevel integer
---@field rodLevel integer
---@field shovel boolean
---@field discoveries table<string, boolean>
---@field rewardClaimed integer Number of milestones already claimed, 0..4.
---@field homeInventory IslandCatch[]
---@field trip IslandTrip?
---@field stats IslandStats

local M = {}
local MAX_COINS = 1000000000000
local MAX_CAPACITY = 200
local MAX_LEVEL = 5
local MAX_BREAD = 999
local MAX_SALT = 9999
local STAT_KEYS = { "trips", "fish", "shore", "sold", "earned", "spent" }

-- Public read-only balance data for views; use price() for level-scaled costs.
M.shop = {
    bread = { name = "面包", cost = 60, amount = 1, restore = 30 },
    salt = { name = "盐", cost = 30, amount = 5 },
    fishCapacity = { name = "鱼护扩容", cost = 360, amount = 5 },
    shoreCapacity = { name = "水桶扩容", cost = 300, amount = 5 },
    boat = { name = "升级小船", cost = 900, amount = 1 },
    rod = { name = "升级鱼竿", cost = 600, amount = 1 },
    shovel = { name = "铁锹", cost = 180, amount = 1 },
}
M.rewards = {
    { threshold = 5, coins = 150 },
    { threshold = 10, coins = 300 },
    { threshold = 15, coins = 600 },
    { threshold = 20, coins = 1000 },
}

local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

local function integer(n)
    return finite(n) and n == math.floor(n)
end

local function read(data, key)
    if type(data) == "table" then return rawget(data, key) end
    return nil
end

local function bounded(n, fallback, low, high, whole)
    if not finite(n) then return fallback end
    local value = math.max(low, math.min(high, n))
    if whole then return math.floor(value) end
    return value
end

local function validKind(kind)
    return kind == "sea" or kind == "shore" or kind == "coast"
end

local function category(kind)
    return kind == "shore" and "shore" or "fish"
end

local function emptyTotals()
    return { count = 0, weight = 0, value = 0, slots = 0, kinds = 0 }
end

-- Only flat known catch fields cross storage boundaries. Values, quality and
-- slots are derived from Catalog, never trusted from a caller or a save file.
local function catchFor(id, weight)
    local species = Catalog.find(id)
    if not species then return nil, "未知物种" end
    if not finite(weight) or weight < species.minWeight or weight > species.maxWeight then
        return nil, "重量超出该物种范围"
    end
    local grams = math.floor(weight * 1000 + 0.5)
    local kg = grams / 1000
    return {
        id = species.id, weight = kg,
        -- Round in integer gram-coins: e.g. 0.350 * 90 must pay 32, not 31
        -- because a floating-point kg multiplication landed below 31.5.
        value = math.max(1, math.floor((grams * species.price + 500) / 1000)),
        slots = species.slots, count = 1, quality = species.quality,
    }
end

local function cleanItem(data)
    if type(data) ~= "table" then return nil end
    local count = read(data, "count")
    if count ~= nil and count ~= 1 then return nil end
    -- A missing saved weight is invalid, never an invitation to reroll a fish.
    return catchFor(read(data, "id"), read(data, "weight"))
end

-- Sort numeric save keys so sparse/corrupt arrays are recovered deterministically.
-- raw access avoids executing metatables; cycles never get recursively copied.
local function itemList(data)
    local result = {}
    if type(data) ~= "table" then return result end
    local keys = {}
    for key in next, data do
        if integer(key) and key >= 1 then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local item = cleanItem(rawget(data, key))
        if item then result[#result + 1] = item end
    end
    return result
end

---@return IslandProfile
function M.new()
    return {
        coins = 2860, stamina = 100, bread = 3, salt = 5,
        fishCapacity = 20, shoreCapacity = 20, boatLevel = 1, rodLevel = 1,
        shovel = true, discoveries = {}, rewardClaimed = 0,
        homeInventory = {}, trip = nil,
        stats = { trips = 0, fish = 0, shore = 0, sold = 0, earned = 0, spent = 0 },
    }
end

---@param items table|nil
---@return IslandTotals
function M.totals(items)
    local total = emptyTotals()
    local seen = {}
    local grams = 0
    for _, item in ipairs(itemList(items)) do
        total.count = total.count + 1
        grams = grams + math.floor(item.weight * 1000 + 0.5)
        total.value = total.value + item.value
        total.slots = total.slots + item.slots
        if not seen[item.id] then
            seen[item.id] = true
            total.kinds = total.kinds + 1
        end
    end
    total.weight = grams / 1000
    return total
end

---@param state IslandProfile
---@return integer
function M.capacity(state)
    if type(state) ~= "table" then return 0 end
    if state.trip then return state.trip.capacity end
    return state.fishCapacity
end

---@param state IslandProfile
---@return integer
function M.used(state)
    return M.totals(type(state) == "table" and state.trip and state.trip.items or nil).slots
end

---@param state IslandProfile
---@param kind string
---@return boolean, string
function M.startTrip(state, kind)
    if not validKind(kind) then return false, "出行类型无效" end
    if state.trip then return false, "请先结束当前行程" end
    state.trip = {
        kind = kind, items = {},
        capacity = kind == "shore" and state.shoreCapacity or state.fishCapacity,
        doubled = false, fuel = 100, hull = 100, elapsed = 0,
    }
    return true, kind == "shore" and "赶海开始" or "垂钓行程开始"
end

---@param speciesId string
---@param weight number|nil
---@return IslandCatch?, string?
function M.createCatch(speciesId, weight)
    local species = Catalog.find(speciesId)
    if not species then return nil, "未知物种" end
    if weight == nil then
        -- Integer grams keep save/load and displayed weight stable.
        weight = math.random(math.ceil(species.minWeight * 1000), math.floor(species.maxWeight * 1000)) / 1000
    end
    return catchFor(speciesId, weight)
end

---@param state IslandProfile
---@param id string
---@return boolean
function M.discover(state, id)
    if not Catalog.find(id) or state.discoveries[id] == true then return false end
    state.discoveries[id] = true
    return true
end

---@param state IslandProfile
---@return integer
function M.discoveryCount(state)
    local count = 0
    for _, list in ipairs({ Catalog.fish, Catalog.shore }) do
        for _, species in ipairs(list) do
            if state.discoveries[species.id] == true then count = count + 1 end
        end
    end
    return count
end

local function canKeep(state, item)
    if not state.trip then return false, "请先开始一次行程" end
    if not item then return false, "收获数据无效" end
    local species = Catalog.find(item.id)
    if species.category ~= category(state.trip.kind) then
        return false, "该收获不属于当前玩法"
    end
    if M.used(state) + item.slots > state.trip.capacity then
        return false, "容量不足，已收入的收获不能移除"
    end
    return true, "可以收入"
end

local function store(state, item)
    state.trip.items[#state.trip.items + 1] = item
    M.discover(state, item.id)
    local key = Catalog.find(item.id).category
    state.stats[key] = state.stats[key] + 1
end

---@param state IslandProfile
---@param item IslandCatch
---@return boolean, string
function M.keep(state, item)
    local canonical = cleanItem(item)
    local ok, message = canKeep(state, canonical)
    if not ok then return false, message end
    -- canonical is a fresh copy: mutating the landing popup cannot change cargo.
    store(state, canonical)
    return true, "已收入，返程前不可移除"
end

---@param state IslandProfile
---@param id string
---@param cost number|nil Successful action stamina cost; defaults to 1.
---@param saltCost number|nil Defaults to 0; encounter/tool selection is the caller's job.
---@return boolean, string, IslandCatch?
function M.collect(state, id, cost, saltCost)
    if cost == nil then cost = 1 end
    if saltCost == nil then saltCost = 0 end
    if not integer(cost) or cost < 0 or not integer(saltCost) or saltCost < 0 then
        return false, "消耗数值无效"
    end
    local species = Catalog.find(id)
    if not species then return false, "未知物种" end
    -- Preflight a minimum-weight catch: capacity is per catch, not per kg.
    local probe = catchFor(id, species.minWeight)
    local ok, message = canKeep(state, probe)
    if not ok then return false, message end
    if state.stamina < cost then return false, "体力不足，吃点面包再试试" end
    if state.salt < saltCost then return false, "盐不足" end
    -- All rejection paths are above both random sampling and resource writes.
    local item = M.createCatch(id)
    store(state, item)
    state.stamina = state.stamina - cost
    state.salt = state.salt - saltCost
    -- Return a detached result, not a mutable handle to locked cargo.
    return true, "收获已放入容器", cleanItem(item)
end

---@param state IslandProfile
---@return IslandTotals
function M.endTrip(state)
    if not state.trip then return emptyTotals() end
    local items = itemList(state.trip.items)
    local total = M.totals(items)
    for _, item in ipairs(items) do
        state.homeInventory[#state.homeInventory + 1] = item
    end
    state.trip = nil
    state.stats.trips = state.stats.trips + 1
    return total
end

---@param state IslandProfile
---@return IslandTotals, string?
function M.sellAll(state)
    if state.trip then return emptyTotals(), "请先返程，再到收购摊出售" end
    local total = M.totals(state.homeInventory)
    if state.coins + total.value > MAX_COINS then return emptyTotals(), "金币已达上限" end
    state.coins = state.coins + total.value
    state.stats.sold = state.stats.sold + total.count
    state.stats.earned = state.stats.earned + total.value
    state.homeInventory = {}
    return total
end

---@param state IslandProfile
---@param key string
---@return number?
function M.price(state, key)
    local product = type(key) == "string" and M.shop[key] or nil
    if not product then return nil end
    if key == "boat" then return product.cost * state.boatLevel end
    if key == "rod" then return product.cost * state.rodLevel end
    return product.cost
end

---@param state IslandProfile
---@param key string
---@return boolean, string
function M.buy(state, key)
    local price = M.price(state, key)
    if not price then return false, "商品不存在" end
    if state.trip then return false, "回岛后才能购买" end
    local product = M.shop[key]
    if key == "shovel" and state.shovel then return false, "已拥有铁锹" end
    local field = ({ boat = "boatLevel", rod = "rodLevel" })[key] or key
    local limit = ({ bread = MAX_BREAD, salt = MAX_SALT, fishCapacity = MAX_CAPACITY,
        shoreCapacity = MAX_CAPACITY, boat = MAX_LEVEL, rod = MAX_LEVEL })[key]
    if limit and state[field] + product.amount > limit then return false, "已达到上限" end
    if state.coins < price then return false, "金币不足" end
    state.coins = state.coins - price
    state.stats.spent = state.stats.spent + price
    if key == "shovel" then state.shovel = true
    else state[field] = state[field] + product.amount end
    return true, "已购买：" .. product.name
end

---@param state IslandProfile
---@return boolean, string
function M.eat(state)
    if state.stamina >= 100 then return false, "体力已满，不用吃面包" end
    if state.bread <= 0 then return false, "没有面包了" end
    state.bread = state.bread - 1
    state.stamina = math.min(100, state.stamina + M.shop.bread.restore)
    return true, "吃了面包，体力恢复"
end

---@param state IslandProfile
---@return boolean, string
function M.claimEncyclopedia(state)
    local reward = M.rewards[state.rewardClaimed + 1]
    if not reward then return false, "图鉴奖励已全部领取" end
    if M.discoveryCount(state) < reward.threshold then
        return false, "发现 " .. reward.threshold .. " 种生物即可领取"
    end
    if state.coins + reward.coins > MAX_COINS then return false, "金币已达上限" end
    state.coins = state.coins + reward.coins
    state.stats.earned = state.stats.earned + reward.coins
    state.rewardClaimed = state.rewardClaimed + 1
    return true, "图鉴奖励：" .. reward.coins .. " 金币"
end

---@param data any
---@return IslandProfile
function M.restore(data)
    local state = M.new()
    if type(data) ~= "table" then return state end
    state.coins = bounded(read(data, "coins"), state.coins, 0, MAX_COINS, true)
    state.stamina = bounded(read(data, "stamina"), state.stamina, 0, 100, false)
    state.bread = bounded(read(data, "bread"), state.bread, 0, MAX_BREAD, true)
    state.salt = bounded(read(data, "salt"), state.salt, 0, MAX_SALT, true)
    state.fishCapacity = bounded(read(data, "fishCapacity"), state.fishCapacity, 1, MAX_CAPACITY, true)
    state.shoreCapacity = bounded(read(data, "shoreCapacity"), state.shoreCapacity, 1, MAX_CAPACITY, true)
    state.boatLevel = bounded(read(data, "boatLevel"), 1, 1, MAX_LEVEL, true)
    state.rodLevel = bounded(read(data, "rodLevel"), 1, 1, MAX_LEVEL, true)
    if type(read(data, "shovel")) == "boolean" then state.shovel = read(data, "shovel") end
    -- Never reduce this to match damaged discovery data: that could reissue rewards.
    state.rewardClaimed = bounded(read(data, "rewardClaimed"), 0, 0, #M.rewards, true)
    local savedStats = read(data, "stats")
    for _, key in ipairs(STAT_KEYS) do
        state.stats[key] = bounded(read(savedStats, key), 0, 0, MAX_COINS, true)
    end
    local discoveries = read(data, "discoveries")
    for _, list in ipairs({ Catalog.fish, Catalog.shore }) do
        for _, species in ipairs(list) do
            if read(discoveries, species.id) == true then state.discoveries[species.id] = true end
        end
    end
    state.homeInventory = itemList(read(data, "homeInventory"))
    local savedTrip = read(data, "trip")
    local kind = read(savedTrip, "kind")
    local recovered = itemList(read(savedTrip, "items"))
    if validKind(kind) then
        local doubled = read(savedTrip, "doubled") == true
        local base = kind == "shore" and state.shoreCapacity or state.fishCapacity
        local ceiling = base * (doubled and 2 or 1)
        state.trip = {
            kind = kind, items = {}, doubled = doubled,
            capacity = bounded(read(savedTrip, "capacity"), ceiling, 1, ceiling, true),
            fuel = bounded(read(savedTrip, "fuel"), 100, 0, 100, false),
            hull = bounded(read(savedTrip, "hull"), 100, 0, 100, false),
            elapsed = bounded(read(savedTrip, "elapsed"), 0, 0, 1000000000, false),
        }
    end
    -- Retain valid cargo from damaged trips. Wrong-category/overflow cargo is
    -- salvaged at home, never silently discarded or made sellable while at sea.
    local used = 0
    for _, item in ipairs(recovered) do
        if state.trip and Catalog.find(item.id).category == category(kind)
            and used + item.slots <= state.trip.capacity then
            state.trip.items[#state.trip.items + 1] = item
            used = used + item.slots
        else
            state.homeInventory[#state.homeInventory + 1] = item
        end
    end
    for _, item in ipairs(state.homeInventory) do M.discover(state, item.id) end
    if state.trip then
        for _, item in ipairs(state.trip.items) do M.discover(state, item.id) end
    end
    return state
end

---@param state IslandProfile
---@return table
function M.export(state)
    -- Whitelist and deep-copy through the same recovery boundary as load.
    -- Unknown UI objects, functions, cyclic tables and metatables never escape.
    local data = M.restore(state)
    data.version = 1
    return data
end

return M
