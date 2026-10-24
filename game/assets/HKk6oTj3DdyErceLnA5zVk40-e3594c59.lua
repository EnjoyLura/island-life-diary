-- Retained home-map cutout, adapted from HomeOcean / scene-to-nanovg.md and
-- scaffold-3d-scene.lua. The caller owns the NanoVG frame and the main viewport.
-- Update before Draw(v, 450, app.h); Stop BEFORE destroying that NVG context.
-- HomeIslandData is sampled once: recreate this renderer after changing it.
local Data = require("Game.HomeIslandData")

---@class HomeIslandSprite
---@field x number
---@field y number
---@field size number
---@field kind integer 1-based cell in the original 2x2 atlas
---@field atlas "tree"|"building"
---@field phase number Radians, encoded as COLOR.r = phase / 13
---@field mirror boolean

---@class HomeIslandScene
---@field scene Scene?
---@field cameraNode Node?
---@field camera Camera?
---@field viewport Viewport?
---@field materials Material[]
---@field treeMaterial Material?
---@field texture Texture2D?
---@field surface RenderSurface?
---@field image integer?
---@field context NVGContextWrapper?
---@field width integer?
---@field height integer?
---@field cameraX number?
---@field cameraY number?
---@field cameraZoom number?
---@field viewHeight number?
---@field elapsed number
---@field windTime number
---@field dirty boolean
---@field stopped boolean
local S = {}; S.__index = S
local UNIT, VIEW_WIDTH = .02, 450
local ROOT_V = .9453125
local COLUMNS, ROWS = 4, 6
local FRAME_TIME = 1 / 30
local SHADER = "Shaders/BLGL/CrescentHomeLand.shader"

---@param mesh CustomGeometry
local function vertex(mesh, x, y, z, u, v, color)
    mesh:DefineVertex(Vector3(x * UNIT, -y * UNIT, z))
    mesh:DefineNormal(Vector3(0, 0, -1))
    mesh:DefineTexCoord(Vector2(u, v))
    mesh:DefineColor(color)
end

---@param scene Scene
---@param material Material
---@return CustomGeometry
local function batch(scene, name, material)
    local mesh = scene:CreateChild(name):CreateComponent("CustomGeometry")
    mesh:SetDynamic(false)
    mesh.castShadows = false
    mesh:BeginGeometry(0, TRIANGLE_LIST)
    mesh:SetMaterial(material)
    return mesh
end

---@param mesh CustomGeometry
local function rectangle(mesh, x, y, w, h, z, color)
    vertex(mesh, x, y, z, 0, 0, color)
    vertex(mesh, x + w, y, z, 1, 0, color)
    vertex(mesh, x, y + h, z, 0, 1, color)
    vertex(mesh, x + w, y, z, 1, 0, color)
    vertex(mesh, x + w, y + h, z, 1, 1, color)
    vertex(mesh, x, y + h, z, 0, 1, color)
end

---@param mesh CustomGeometry
---@param sprite HomeIslandSprite
local function spriteMesh(mesh, sprite, z)
    local tree = sprite.atlas == "tree"
    local columns, rows = tree and COLUMNS or 1, tree and ROWS or 1
    local column, row = (sprite.kind - 1) % 2, math.floor((sprite.kind - 1) / 2)
    local phase = tree and (sprite.phase or 0) / 13 or 0
    local function point(i, j)
        local u, t = i / columns, j / rows
        -- t runs from the cell bottom to its top, just like LayeredIsland.Sprite.
        -- At cell v=ROOT_V, map y is exactly sprite.y; transparent bottom padding
        -- extends below it. The bottom 18% has zero branch weight, including roots.
        local y = sprite.y + (1 - ROOT_V - t) * sprite.size
        local weight = tree and math.max(0, (t - .18) / .82) ^ 2 or 0
        local atlasU = sprite.mirror and 1 - u or u
        vertex(mesh, sprite.x + (u - .5) * sprite.size, y, z,
            (column + atlasU) * .5, (row + 1 - t) * .5,
            Color(phase, 1, 1, weight))
    end
    for j = 0, rows - 1 do
        for i = 0, columns - 1 do
            point(i, j); point(i, j + 1); point(i + 1, j + 1)
            point(i, j); point(i + 1, j + 1); point(i + 1, j)
        end
    end
end

---@return HomeIslandScene?
function S.new()
    local self = setmetatable({}, S)
    local ok, err = pcall(function() self:Init() end)
    if not ok then
        self:Stop()
        print("[HomeIslandScene] unavailable: " .. tostring(err))
        return nil
    end
    return self
end

---@param imagePath string?
---@return Material
function S:NewMaterial(imagePath)
    local material = Material:new()
    self.materials[#self.materials + 1] = material
    assert(material:SetSurfaceShader(SHADER), "home island shader unavailable")
    if imagePath then
        local texture = cache:GetResource("Texture2D", imagePath) --[[@as Texture2D?]]
        assert(texture, "home island image unavailable: " .. imagePath)
        material:SetSurfaceTexture("art_map", texture)
    else
        material:SetShaderParameter("use_vertex_color", Variant(1.0))
    end
    return material
end

function S:Init()
    self.materials = {}
    self.elapsed, self.windTime = 0, 0
    self.stopped, self.dirty = false, true

    self.scene = Scene()
    self.scene:CreateComponent("Octree")
    self.cameraNode = self.scene:CreateChild("HomeIslandCamera")
    self.cameraNode.position = Vector3(0, 0, -5)
    self.cameraNode.rotation = Quaternion(0, 0, 0) -- +Z, Y-up; map Y points down.
    self.camera = self.cameraNode:CreateComponent("Camera")
    self.camera.orthographic = true
    self.camera.autoAspectRatio = false -- Use the exact design aspect, not rounded RT pixels.
    self.camera.nearClip, self.camera.farClip = .1, 20

    local ground = batch(self.scene, "HomeIslandGround", self:NewMaterial(Data.image))
    rectangle(ground, 0, 0, Data.width, Data.height, 2, Color(0, 1, 1, 0))
    ground:Commit()

    -- Sort a private index once. All atlases share this depth ordering, so roofs,
    -- the lighthouse and foliage interleave correctly even in separate batches.
    ---@type {sprite: HomeIslandSprite, order: integer}[]
    local sorted = {}
    local treeCount, buildingCount = 0, 0
    local sprites = Data.sprites --[[@as HomeIslandSprite[] ]]
    for i, sprite in ipairs(sprites) do
        sorted[#sorted + 1] = {sprite = sprite, order = i}
        if sprite.atlas == "tree" then treeCount = treeCount + 1
        else buildingCount = buildingCount + 1 end
    end
    table.sort(sorted, function(a, b)
        if a.sprite.y == b.sprite.y then return a.order < b.order end
        return a.sprite.y < b.sprite.y
    end)

    ---@type CustomGeometry?
    local trees
    ---@type CustomGeometry?
    local buildings
    if treeCount > 0 then
        self.treeMaterial = self:NewMaterial(Data.treesImage or "Textures/CelWorld/vegetation.png")
        self.treeMaterial:SetShaderParameter("wind_strength", Variant(.16))
        trees = batch(self.scene, "HomeIslandOriginalVegetation", self.treeMaterial)
    end
    if buildingCount > 0 then
        local material = self:NewMaterial(Data.buildingsImage or "Textures/CelWorld/buildings.png")
        buildings = batch(self.scene, "HomeIslandOriginalBuildings", material)
    end
    for i, entry in ipairs(sorted) do
        -- Higher map base Y is nearer the camera. Z stays in (-1,1), always in
        -- front of ground/docks and well inside the fixed camera clip range.
        local z = 1 - 2 * i / (#sorted + 1)
        local mesh = entry.sprite.atlas == "tree" and trees or buildings
        if mesh then spriteMesh(mesh, entry.sprite, z) end
    end
    if trees then trees:Commit() end
    if buildings then buildings:Commit() end
    self:BuildDocks()

    self.viewport = Viewport:new(self.scene, self.camera)
    self.viewport.drawDebug = false
    local path = self.viewport:GetRenderPath():Clone()
    local definition = cache:GetResource("XMLFile", "RenderPaths/HomeIsland.xml") --[[@as XMLFile?]]
    assert(definition, "home island render path unavailable")
    assert(path:Load(definition), "invalid home island render path")
    -- Do NOT append GammaCorrection: the bundled shader writes alpha=1 over
    -- the entire viewport. Our unlit shader already outputs display RGB.
    self.viewport:SetRenderPath(path)
end

function S:BuildDocks()
    local scene = self.scene
    if not scene or not Data.docks or #Data.docks == 0 then return end
    local mesh = batch(scene, "HomeIslandWoodenDocks", self:NewMaterial(nil))
    local wood = {Color(.69, .46, .25, 0), Color(.75, .50, .29, 0)}
    local dark, light = Color(.43, .28, .15, 0), Color(.91, .84, .63, 0)
    for _, dock in ipairs(Data.docks) do
        -- (x,y) is the shore-side centre; the deck extends toward +map Y.
        local x, y, w, h = dock.x - dock.width / 2, dock.y, dock.width, dock.length
        rectangle(mesh, x, y, w, h + 5, 1.70, dark)
        local planks = math.max(1, math.ceil(h / 13))
        local pitch = h / planks
        for i = 0, planks - 1 do
            rectangle(mesh, x + 2, y + i * pitch, w - 4, math.max(.5, pitch - 1.5),
                1.60, wood[i % 2 + 1])
        end
        local intervals = math.max(1, math.ceil(h / 55))
        for i = 0, intervals do
            local py = y + h * i / intervals
            for _, px in ipairs({x + 1, x + w - 1}) do
                rectangle(mesh, px - 4, py - 6, 8, 17, 1.50, dark)
                rectangle(mesh, px - 5, py - 8, 10, 5, 1.40, wood[2])
                rectangle(mesh, px - 4, py - 2, 8, 2, 1.30, light)
            end
        end
    end
    mesh:Commit()
end

function S:ReleaseImage()
    if self.context and self.image and self.image > 0 then nvgDeleteVideo(self.context, self.image) end
    self.image, self.context = nil, nil
end

function S:ReleaseTexture()
    -- The NVG wrapper must relinquish the GPU handle before its owner is disposed.
    self:ReleaseImage()
    if self.surface then self.surface:SetNumViewports(0) end
    if self.texture then self.texture:Dispose() end
    self.surface, self.texture = nil, nil
    self.width, self.height = nil, nil
end

function S:Resize(app)
    local viewport = assert(self.viewport, "home island renderer stopped")
    local pixels = math.min((app.scale or 1) * graphics:GetDPR(),
        720 / VIEW_WIDTH, 1280 / app.h)
    local w = math.max(1, math.min(720, math.floor(VIEW_WIDTH * pixels + .5)))
    local h = math.max(1, math.min(1280, math.floor(app.h * pixels + .5)))
    if self.texture and w == self.width and h == self.height then return end
    self:ReleaseTexture()
    self.texture = Texture2D:new()
    self.texture:SetNumLevels(1)
    self.texture:SetSRGB(false) -- Display-encoded cutout; no extra hardware gamma conversion.
    assert(self.texture:SetSize(w, h, Graphics:GetRGBAFormat(), TEXTURE_RENDERTARGET),
        "home island render target allocation failed")
    self.texture:SetFilterMode(FILTER_BILINEAR)
    self.width, self.height = w, h
    viewport.rect = IntRect(0, 0, w, h)
    local surface = self.texture:GetRenderSurface() --[[@as RenderSurface?]]
    self.surface = assert(surface, "home island render surface unavailable")
    self.surface:SetViewport(0, viewport)
    self.surface:SetUpdateMode(SURFACE_MANUALUPDATE)
    self.dirty = true
end

function S:Update(app, dt)
    local camera, cameraNode = self.camera, self.cameraNode
    if self.stopped or not camera or not cameraNode then return end
    if app.mode ~= "home" or app.modal then self.dirty = true; return end
    assert(app.h > 0 and app.camera.zoom > 0, "invalid home island camera")
    self:Resize(app)
    local surface = assert(self.surface, "home island render surface unavailable")
    local elapsed = math.max(0, dt or 0)
    self.elapsed = self.elapsed + elapsed
    self.windTime = app.playtime or (self.windTime + elapsed)
    local c = app.camera
    local moved = c.x ~= self.cameraX or c.y ~= self.cameraY
        or c.zoom ~= self.cameraZoom or app.h ~= self.viewHeight
    -- No rounded cache key: even a small pan/zoom queues a fresh frame immediately.
    if not self.dirty and not moved and self.elapsed < FRAME_TIME then return end
    cameraNode.position = Vector3(c.x * UNIT, -c.y * UNIT, -5)
    camera.aspectRatio = VIEW_WIDTH / app.h
    camera.orthoSize = app.h / c.zoom * UNIT
    self.cameraX, self.cameraY, self.cameraZoom, self.viewHeight = c.x, c.y, c.zoom, app.h
    if self.treeMaterial then
        self.treeMaterial:SetShaderParameter("wind_time", Variant(self.windTime))
    end
    surface:QueueUpdate()
    self.elapsed, self.dirty = 0, false
end

function S:Draw(v, w, h)
    if self.stopped or not self.texture or w <= 0 or h <= 0 then return false end
    if self.context and self.context ~= v then self:ReleaseImage() end
    if self.image == nil then
        self.context = v
        self.image = nvgCreateVideo(v, self.texture)
        if not self.image or self.image <= 0 then
            self.image = 0 -- Retry only after resize/context replacement, not every frame.
            print("[HomeIslandScene] NanoVG texture import unavailable")
        end
    end
    if self.image <= 0 then return false end
    -- nvgCreateVideo supplies the backend Y orientation; do not flip it again.
    nvgSave(v)
    nvgIntersectScissor(v, 0, 0, w, h)
    nvgBeginPath(v); nvgRect(v, 0, 0, w, h)
    nvgFillPaint(v, nvgImagePattern(v, 0, 0, w, h, 0, self.image, 1))
    nvgFill(v)
    nvgRestore(v)
    return true
end

function S:Stop()
    self.stopped = true
    self:ReleaseTexture()
    self.viewport, self.camera, self.cameraNode = nil, nil, nil
    if self.scene then self.scene:Dispose() end
    self.scene = nil
    for _, material in ipairs(self.materials or {}) do material:Dispose() end
    self.materials = {}
    self.treeMaterial = nil
end

return S
