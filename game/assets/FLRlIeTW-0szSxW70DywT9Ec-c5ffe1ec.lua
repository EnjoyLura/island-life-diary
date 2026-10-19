-- Data-only companion to scaffold-2d.lua's game-content layer.
-- Style A: readable silhouettes and RGB (0..255) cel-shaded accent colours.
-- Prototype balance: weights are kg; price is integer coins per kg.
-- `unlocked` describes the INITIAL region state, not encyclopedia discovery.
---@class IslandSpecies
---@field id string
---@field name string
---@field quality integer
---@field minWeight number
---@field maxWeight number
---@field price integer
---@field slots integer
---@field desc string
---@field region string
---@field unlocked boolean
---@field shape string
---@field color number[]
---@field category string

local Catalog = {
    qualityColors = {
        { 86, 188, 119 },   -- 1 普通 / green
        { 74, 159, 234 },   -- 2 稀有 / blue
        { 176, 112, 224 },  -- 3 史诗 / purple
        { 246, 166, 61 },   -- 4 传说 / orange
    },
    regions = {
        { id = "bay", name = "月牙湾", category = "fish", unlocked = true },
        { id = "outer_reef", name = "外礁深水", category = "fish", unlocked = false },
        { id = "beach", name = "月牙滩", category = "shore", unlocked = true },
        { id = "mangrove", name = "红树林", category = "shore", unlocked = false },
    },
    ---@type IslandSpecies[]
    fish = {
        { id = "black_bream", name = "黑鲷", quality = 1, minWeight = 1, maxWeight = 5,
          price = 5, slots = 1, desc = "近岸礁石边的常客，常成群觅食。",
          region = "月牙湾", unlocked = true, shape = "bream", color = { 103, 145, 161 }, category = "fish" },
        { id = "sea_bass", name = "海鲈", quality = 1, minWeight = 0.8, maxWeight = 5,
          price = 10, slots = 2, desc = "银亮的身影穿梭于潮流之间，收线时很有劲。",
          region = "月牙湾", unlocked = true, shape = "bass", color = { 152, 191, 180 }, category = "fish" },
        { id = "mackerel", name = "鲭鱼", quality = 1, minWeight = 0.3, maxWeight = 1.8,
          price = 10, slots = 1, desc = "背上有蓝绿波纹，总爱追着小鱼一起游。",
          region = "月牙湾", unlocked = true, shape = "slender", color = { 66, 170, 181 }, category = "fish" },
        { id = "sardine", name = "沙丁鱼", quality = 1, minWeight = 0.05, maxWeight = 0.3,
          price = 10, slots = 1, desc = "小小的银色鱼群，是海湾里闪动的星星。",
          region = "月牙湾", unlocked = true, shape = "small", color = { 157, 205, 218 }, category = "fish" },
        { id = "mullet", name = "鲻鱼", quality = 1, minWeight = 0.5, maxWeight = 3,
          price = 8, slots = 1, desc = "喜欢浅湾的平静水面，偶尔会跃出水花。",
          region = "月牙湾", unlocked = true, shape = "slender", color = { 130, 169, 154 }, category = "fish" },
        { id = "yellowfin_bream", name = "黄鳍鲷", quality = 2, minWeight = 0.5, maxWeight = 2.5,
          price = 20, slots = 1, desc = "金黄的鱼鳍像一面小旗，在清澈水中格外显眼。",
          region = "月牙湾", unlocked = true, shape = "bream", color = { 235, 197, 81 }, category = "fish" },
        { id = "grouper", name = "石斑鱼", quality = 2, minWeight = 1, maxWeight = 8,
          price = 20, slots = 2, desc = "藏在礁石缝里的大胃王，斑点是它的伪装。",
          region = "月牙湾", unlocked = true, shape = "grouper", color = { 180, 132, 90 }, category = "fish" },
        { id = "pomfret", name = "银鲳", quality = 2, minWeight = 0.3, maxWeight = 2,
          price = 30, slots = 1, desc = "扁扁的银色身体，转身时像一枚水中的月亮。",
          region = "月牙湾", unlocked = true, shape = "flat", color = { 188, 213, 224 }, category = "fish" },
        { id = "lionfish", name = "火焰狮子鱼", quality = 3, minWeight = 0.2, maxWeight = 1,
          price = 90, slots = 1, desc = "展开火焰般的鳍，在外礁的阴影里慢慢巡游。",
          region = "外礁深水", unlocked = false, shape = "spiny", color = { 224, 113, 93 }, category = "fish" },
        { id = "mahi_mahi", name = "鲯鳅", quality = 3, minWeight = 2, maxWeight = 12,
          price = 55, slots = 3, desc = "金绿交错的远洋访客，奋力游动时带起长长水痕。",
          region = "外礁深水", unlocked = false, shape = "long", color = { 119, 196, 99 }, category = "fish" },
        { id = "bluefin_tuna", name = "蓝鳍金枪鱼", quality = 4, minWeight = 10, maxWeight = 50,
          price = 100, slots = 5, desc = "深蓝海域的强壮旅人，一次相遇就值得记进图鉴。",
          region = "外礁深水", unlocked = false, shape = "tuna", color = { 71, 127, 194 }, category = "fish" },
        { id = "oarfish", name = "皇带鱼", quality = 4, minWeight = 5, maxWeight = 25,
          price = 160, slots = 4, desc = "银色长带与红色冠鳍，是深水里难得一见的惊喜。",
          region = "外礁深水", unlocked = false, shape = "ribbon", color = { 220, 154, 170 }, category = "fish" },
    },
    ---@type IslandSpecies[]
    shore = {
        { id = "green_crab", name = "青蟹", quality = 1, minWeight = 0.1, maxWeight = 1.5,
          price = 20, slots = 1, desc = "藏在礁石与潮沟间，退潮后更容易发现。",
          region = "月牙滩", unlocked = true, shape = "crab", color = { 100, 164, 132 }, category = "shore" },
        { id = "razor_clam", name = "蛏子", quality = 1, minWeight = 0.02, maxWeight = 0.12,
          price = 12, slots = 1, desc = "小洞口下的长壳居民，撒一点盐就会探出头。",
          region = "月牙滩", unlocked = true, shape = "razor", color = { 209, 174, 117 }, category = "shore" },
        { id = "clam", name = "花蛤", quality = 1, minWeight = 0.02, maxWeight = 0.15,
          price = 10, slots = 1, desc = "花纹各不相同的小贝壳，常躲在湿沙下面。",
          region = "月牙滩", unlocked = true, shape = "shell", color = { 198, 164, 131 }, category = "shore" },
        { id = "conch", name = "海螺", quality = 2, minWeight = 0.1, maxWeight = 0.8,
          price = 20, slots = 1, desc = "潮池里缓缓移动的螺旋小屋，壳上带着暖色条纹。",
          region = "月牙滩", unlocked = true, shape = "conch", color = { 228, 159, 97 }, category = "shore" },
        { id = "mantis_shrimp", name = "皮皮虾", quality = 2, minWeight = 0.05, maxWeight = 0.3,
          price = 30, slots = 1, desc = "潮沟边的机灵家伙，总想飞快钻回自己的小洞。",
          region = "月牙滩", unlocked = true, shape = "shrimp", color = { 171, 172, 113 }, category = "shore" },
        { id = "oyster", name = "牡蛎", quality = 3, minWeight = 0.1, maxWeight = 0.8,
          price = 40, slots = 2, desc = "层层叠叠的粗糙外壳下，藏着值得寻找的收获。",
          region = "红树林", unlocked = false, shape = "shell", color = { 162, 151, 185 }, category = "shore" },
        { id = "abalone", name = "九孔鲍", quality = 3, minWeight = 0.1, maxWeight = 0.5,
          price = 90, slots = 1, desc = "牢牢贴在礁石上的海味，壳边排列着整齐的小孔。",
          region = "红树林", unlocked = false, shape = "abalone", color = { 124, 177, 184 }, category = "shore" },
        { id = "golden_conch", name = "金冠海螺", quality = 4, minWeight = 0.2, maxWeight = 1,
          price = 180, slots = 2, desc = "稀少的金色螺壳，在退潮后的阳光下闪着柔光。",
          region = "红树林", unlocked = false, shape = "conch", color = { 245, 188, 73 }, category = "shore" },
    },
}

---@type table<string, IslandSpecies>
local byId = {}
for _, list in ipairs({ Catalog.fish, Catalog.shore }) do
    for _, species in ipairs(list) do
        byId[species.id] = species
    end
end

---@param id any
---@return IslandSpecies?
function Catalog.find(id)
    if type(id) ~= "string" then return nil end
    return byId[id]
end

return Catalog
