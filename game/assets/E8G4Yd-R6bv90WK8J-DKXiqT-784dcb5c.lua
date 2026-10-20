-- Crescent Island / style A. Content renderer for scaffold-2d.lua's UI layer.
-- Call from a parent's Widget:Render after translating into widget-local space.
-- The parent owns UI scaling (450 logical px wide), the NVG context/frame,
-- input, pause/time, simulation, collisions, resources, and all HUD elements.
-- This module only reads ctx; cached image handles are its only retained state.
--
-- World.draw(vg,w,h,ctx):
--   mode = home | sailing | map | fishing | shore; time = seconds, paused by parent.
--   camera = {x,y,zoom}: center in world units, zoom = logical px / world unit.
--   World.toScreen / toWorld use exactly this transform; neither infers a mode.
--   If omitted, draw defaults to island(500,1000,.45), boat(1000,1100,.55),
--   shore(900,1000,.65); map defaults to a fit of the entire sea(2000x2400).
--   Explicit camera components, including zero x/y, always take precedence.
--   boat = {x,y,heading,speed}: radians clockwise from NORTH, speed world units/s.
--   fishSchools = {{x,y,id,count,phase,radius?,species?}}; max 12 x 10 shadows.
--   reefs = {{x,y,radius?}} (r alias accepted); same circular footprint as parent.
--   shore = {x,y,targets={{x,y,id,kind,collected,phase,species?}},
--            action={kind='tongs'|'dig'|'salt',t=0..1,tx,ty,species?}}.
--   Action tx/ty and target x/y are world coordinates. No targets are fabricated.
--   fish = {stage,aimX,aimY,power,progress,castT,rodSide,species?,viewX?,viewY?,population?}; aim is LOCAL
--          screen px; castT and progress normalized 0..1, rodSide normalized -1..1.
--          viewX/Y are scene translations in virtual px, clamped to +/-100, +/-70;
--          positive values move scenery right/down. Rod/deck/aim remain screen-fixed.
--          population is a dense array of actual species ({shape,color,...}):
--          nil keeps 9 default fish and 5 deep shadows; {} shows neither.
--          Otherwise draw #population foreground fish and at most 2 deep shadows.
--   particles = {{x,y,age?,born?,life?,vx?,vy?,size?,kind?,screen?}}; life seconds,
--               age overrides time-born. Coordinates world except fishing/screen.
--   assets = {island?,sea?,fishing?,shore?}: resource paths, NOT assets/ prefixed.
--   Background extents: island1000x2000, sea2000x2400, shore1800x2000.
--   Fishing uses aspect-cover; world assets stretch to their exact world extents.
-- World.image is aspect-cover within the supplied rect, alpha 0..1; returns loaded.
-- drawFish/drawCreature: size = approximate total width in caller's coordinates;
--   species = {shape,color={r,g,b}} or a shape string; fish face RIGHT, phase radians.
-- fishPose(i,time,w,h,view?) returns x,y,heading,size,speciesIndex (1..6), heading from EAST.
--   i=1..#ctx.fish.population (or World.fishCount when omitted) gives foreground poses.
--   With population, the species is population[i]; the fifth result is only the
--   legacy fallback index into Catalog.fish[1..6]. No RNG/global clock is used.
--   Pass ctx.fish as view for screen-space nearest-fish hit testing; do NOT add view
--   again. Legacy four-argument calls return the unshifted pose, so the parent's
--   existing fishPose(...) + clamped viewX/Y calculation remains compatible.

local ImageCache = require('urhox-libs/UI/Core/ImageCache')
local World = { fishCount = 9 }
local sin, cos, pi = math.sin, math.cos, math.pi
local min, max, floor, abs = math.min, math.max, math.floor, math.abs
local TAU = pi * 2
local VIEW_X, VIEW_Y = 100, 70
local INK, CREAM, BRASS = { 22, 49, 69 }, { 255, 243, 208 }, { 221, 169, 78 }
local WHITE, FOAM, WOOD = { 245, 255, 249 }, { 174, 240, 237 }, { 198, 122, 66 }
local EMPTY = {}
local images = {} -- handle metadata only; ImageCache owns creation/destruction.
local FISH = {
    { shape = 'bream', color = { 103, 145, 161 } },
    { shape = 'bass', color = { 152, 191, 180 } },
    { shape = 'slender', color = { 66, 170, 181 } },
    { shape = 'small', color = { 157, 205, 218 } },
    { shape = 'slender', color = { 130, 169, 154 } },
    { shape = 'bream', color = { 235, 197, 81 } },
}
---@param v number
---@param a number
---@param b number
---@return number
local function clamp(v, a, b) return max(a, min(b, v)) end
local function color(c, alpha, light)
    local k = light or 1
    return nvgRGBA(floor(clamp(c[1] * k, 0, 255)), floor(clamp(c[2] * k, 0, 255)),
        floor(clamp(c[3] * k, 0, 255)), floor(clamp(alpha or 255, 0, 255)))
end
local function finish(vg, fill, edge, width)
    if fill then nvgFillColor(vg, fill); nvgFill(vg) end
    if edge then nvgStrokeColor(vg, edge); nvgStrokeWidth(vg, width or 2); nvgStroke(vg) end
end
local function poly(vg, points, fill, edge, width)
    nvgBeginPath(vg); nvgMoveTo(vg, points[1], points[2])
    for i = 3, #points, 2 do nvgLineTo(vg, points[i], points[i + 1]) end
    nvgClosePath(vg); finish(vg, fill, edge, width)
end
local function oval(vg, x, y, rx, ry, fill, edge, width)
    nvgBeginPath(vg); nvgEllipse(vg, x, y, max(.01, rx), max(.01, ry))
    finish(vg, fill, edge, width)
end
local function box(vg, x, y, w, h, radius, fill, edge, width)
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, radius)
    finish(vg, fill, edge, width)
end
local function line(vg, x1, y1, x2, y2, c, width)
    nvgBeginPath(vg); nvgMoveTo(vg, x1, y1); nvgLineTo(vg, x2, y2)
    finish(vg, nil, c, width)
end
local function curve(vg, x, y, a, b, c, d, ex, ey, col, width)
    nvgBeginPath(vg); nvgMoveTo(vg, x, y); nvgBezierTo(vg, a, b, c, d, ex, ey)
    finish(vg, nil, col, width)
end
local function arc(vg, x, y, rx, ry, a, b, col, width)
    nvgBeginPath(vg)
    for i = 0, 12 do
        local q = a + (b - a) * i / 12
        local px, py = x + cos(q) * rx, y + sin(q) * ry
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    finish(vg, nil, col, width)
end
local function visible(x, y, r, w, h) return x + r > 0 and x - r < w and y + r > 0 and y - r < h end
local function zoom(camera) return max(.001, camera.zoom or 1) end

---@param wx number
---@param wy number
---@param w number
---@param h number
---@param camera table|nil
---@return number, number
function World.toScreen(wx, wy, w, h, camera)
    camera = camera or EMPTY
    local z = zoom(camera)
    return (wx - (camera.x or 0)) * z + w * .5, (wy - (camera.y or 0)) * z + h * .5
end
---@param x number
---@param y number
---@param w number
---@param h number
---@param camera table|nil
---@return number, number
function World.toWorld(x, y, w, h, camera)
    camera = camera or EMPTY
    local z = zoom(camera)
    return (x - w * .5) / z + (camera.x or 0), (y - h * .5) / z + (camera.y or 0)
end

local function imageInfo(vg, path)
    if type(path) ~= 'string' or path == '' then return nil end
    path = path:gsub('\\', '/'):gsub('^assets/', '')
    local previous = ImageCache.GetContext()
    if previous ~= vg then ImageCache.SetContext(vg) end
    local entry = images[path] or { misses = 0 }
    -- Failed loads are cached by the shared library. Bounded retries let assets
    -- delivered after first render appear without reloading every single frame.
    if entry.misses >= 120 then ImageCache.Release(path); entry.misses = 0 end
    local handle = ImageCache.Get(path)
    entry.handle = handle
    if handle and handle > 0 then
        entry.w, entry.h = ImageCache.GetSize(path)
        entry.misses = 0
    else entry.misses = entry.misses + 1 end
    images[path] = entry
    if previous ~= vg then ImageCache.SetContext(previous) end
    if not handle or handle <= 0 then return nil end
    return entry
end
local function imageRect(vg, path, x, y, w, h, alpha, stretch)
    if w <= 0 or h <= 0 then return false end
    local entry = imageInfo(vg, path)
    if not entry then return false end
    local dw, dh = w, h
    if not stretch and entry.w > 0 and entry.h > 0 then
        local scale = max(w / entry.w, h / entry.h)
        dw, dh = entry.w * scale, entry.h * scale
    end
    nvgBeginPath(vg); nvgRect(vg, x, y, w, h)
    nvgFillPaint(vg, nvgImagePattern(vg, x + (w - dw) / 2, y + (h - dh) / 2,
        dw, dh, 0, entry.handle, clamp(alpha or 1, 0, 1))); nvgFill(vg)
    return true
end
function World.image(vg, path, x, y, w, h, alpha)
    nvgSave(vg)
    local loaded = imageRect(vg, path, x, y, w, h, alpha, false)
    nvgRestore(vg)
    return loaded
end

function World.drawFish(vg, x, y, size, species, phase, shadow)
    species = type(species) == 'table' and species or { shape = species or 'bream' }
    local shape, tint = species.shape or 'bream', species.color or FISH[1].color
    local tall = ({ bream = 22, bass = 15, slender = 12, small = 13, grouper = 26,
        flat = 30, spiny = 22, long = 17, tuna = 22, ribbon = 7, shark = 18 })[shape] or 20
    local beat = sin(phase or 0) * 5
    ---@type NVGcolor|nil
    local ink = color(INK)
    local base = color(tint)
    if shadow then ink, base = nil, color({ 13, 77, 104 }, 125) end
    nvgSave(vg); nvgTranslate(vg, x, y); nvgScale(vg, size / 100, size / 100)
    if shape == 'ray' then
        poly(vg, { 38,0, 0,-34, -30,-10, -55,0, -30,10, 0,34 }, base, ink, 2)
        curve(vg, -25,0, -55,0, -60,15 + beat, -73,9 + beat, base, 3)
    else
        poly(vg, { -27,0, -52,-17 + beat, -47,beat, -52,17 + beat }, base, ink, 2)
        if shape == 'spiny' or shape == 'shark' then
            for i = 1, (shape == 'shark' and 1 or 6) do
                local fx = -18 + i * 7
                poly(vg, { fx-9,-tall*.6, fx-5,-tall-20, fx+8,-tall*.5 }, base, ink, 1.5)
            end
        else
            poly(vg, { -21,-tall*.6, -9,-tall-10, 14,-tall*.8 }, base, ink, 1.5)
        end
        poly(vg, { -7,tall*.7, -18,tall+12, 16,tall*.6 }, base, ink, 1.5)
        nvgBeginPath(vg); nvgMoveTo(vg, 45, 0)
        nvgBezierTo(vg, 30,-tall-4, -17,-tall-8, -33,0)
        nvgBezierTo(vg, -18,tall+4, 31,tall+5, 45,0); nvgClosePath(vg)
        finish(vg, base, ink, 2.2)
        if not shadow then
            -- Two graphic planes, a narrow sunlit back, and an enamel-like belly.
            nvgBeginPath(vg); nvgMoveTo(vg, -24,-2)
            nvgBezierTo(vg, -5,-tall, 25,-tall*.7, 37,-3)
            nvgBezierTo(vg, 10,-tall*.25, -2,-tall*.18, -24,-2)
            finish(vg, color(tint, 255, .7))
            nvgBeginPath(vg); nvgMoveTo(vg, -19,6)
            nvgBezierTo(vg, 6,tall*.83, 26,tall*.6, 38,3)
            nvgBezierTo(vg, 16,tall*.2, -5,3, -19,6)
            finish(vg, color(CREAM, 190))
            curve(vg, -17,-tall*.55, -2,-tall*.85, 17,-tall*.75, 24,-tall*.52, color(WHITE,190), 2)
            if shape == 'grouper' then
                for i = 1, 9 do oval(vg, -18+(i%4)*11, -8+floor(i/4)*7, 2.3, 2, color(INK,130)) end
            elseif shape == 'spiny' or shape == 'slender' then
                for i = 1, 5 do line(vg, -22+i*8, -tall*.55, -26+i*8, 5, color(INK,110), 2) end
            elseif shape == 'ribbon' then
                curve(vg, -30,-5, -4,-12, 20,-9, 34,-4, color({229,93,99}), 3)
            end
            poly(vg, { 7,3, -3,10, 0,0 }, color(tint,255,.8), color(INK,170), 1)
            arc(vg, 23,0, 5,tall*.55, pi*.5, pi*1.5, color(INK,160), 1.2)
        end
    end
    if not shadow then
        oval(vg, 31,-4, 4.2,4.2,color(CREAM),color(INK),1.3)
        oval(vg, 32,-4, 2.4,2.7,color(INK)); oval(vg,32.6,-5.2,.8,.8,color(WHITE))
    end
    nvgRestore(vg)
end

function World.drawCreature(vg, x, y, size, species, phase)
    species = type(species) == 'table' and species or { shape = species or 'crab' }
    local kind, tint = species.shape or 'crab', species.color or { 215, 126, 74 }
    local p, ink = phase or 0, color(INK)
    nvgSave(vg); nvgTranslate(vg,x,y); nvgScale(vg,size/100,size/100)
    oval(vg,0,18,38,10,color(INK,40))
    if kind == 'crab' then
        for side = -1, 1, 2 do
            for j = 1, 4 do
                local yy = -5+j*7
                curve(vg,side*20,yy,side*34,yy-10,side*40,yy+sin(p+j)*3,side*45,yy+9,ink,5)
                curve(vg,side*20,yy,side*34,yy-10,side*40,yy+sin(p+j)*3,side*45,yy+9,color(tint),2.4)
            end
            curve(vg,side*20,-4,side*40,-15,side*27,-27,side*39,-31,ink,8)
            curve(vg,side*20,-4,side*40,-15,side*27,-27,side*39,-31,color(tint),4.5)
            oval(vg,side*37,-30,11,12,color(tint),ink,2)
            poly(vg,{side*33,-41,side*38,-31,side*43,-41},color(CREAM),ink,1.3)
            line(vg,side*10,-11,side*12,-25,ink,4)
            oval(vg,side*12,-25,4,5,color(CREAM),ink,1.5)
            oval(vg,side*12,-26,2,2.5,ink)
        end
        oval(vg,0,3,27,20,color(tint),ink,2.6)
        oval(vg,-3,-3,19,10,color(tint,255,1.25))
        arc(vg,0,5,16,8,.15,pi-.15,color(tint,255,.65),2)
    elseif kind == 'shrimp' then
        for i = 1, 7 do
            local a = -.8+i*.22
            local px, py = cos(a)*32-20,sin(a)*32
            oval(vg,px,py,11-i*.4,12-i*.65,color(tint,255,1-i*.035),ink,1.6)
            line(vg,px,py+8,px-7,py+20+sin(p+i)*2,ink,1.5)
        end
        poly(vg,{-11,27,-29,32,-20,15},color(tint),ink,2)
        for side=-1,1,2 do curve(vg,8,-19,17,-37,35+side*9,-37,40,-24+side*4,ink,1.6) end
        oval(vg,19,-20,3,3,color(CREAM),ink,1.2)
    elseif kind == 'octopus' then
        for i = 1, 8 do
            local xx = (i-4.5)*7
            curve(vg,xx*.5,7,xx,35,xx*1.6,34+sin(p+i)*7,xx*1.6,19,ink,9)
            curve(vg,xx*.5,7,xx,35,xx*1.6,34+sin(p+i)*7,xx*1.6,19,color(tint),5.5)
        end
        oval(vg,0,-8,24,29,color(tint),ink,2.4)
        oval(vg,-8,-19,9,7,color(tint,255,1.25))
        for side=-1,1,2 do oval(vg,side*9,2,5,6,color(CREAM),ink,1); oval(vg,side*9,3,2,3,ink) end
    elseif kind == 'razor' then
        nvgRotate(vg,-.45); box(vg,-13,-40,26,80,10,color(tint),ink,2.4)
        box(vg,-8,-35,7,68,3,color(CREAM,190)); line(vg,7,-31,7,32,color(tint,255,.6),2)
    elseif kind == 'conch' then
        poly(vg,{-40,20,-22,-4,-10,-32,8,-19,27,-12,39,11,22,30,-9,26},color(tint),ink,2.6)
        oval(vg,1,1,26,22,color(tint,255,1.15),ink,2)
        nvgBeginPath(vg)
        for i=0,28 do
            local a=i*.45; local r=1+i*.64
            local px,py=cos(a)*r,sin(a)*r*.85
            if i==0 then nvgMoveTo(vg,px,py) else nvgLineTo(vg,px,py) end
        end
        finish(vg,nil,color(tint,255,.6),2.3)
        oval(vg,25,15,11,8,color(CREAM),ink,1.5)
    else -- scallop, oyster, clam and abalone
        local flat = kind == 'abalone'
        nvgBeginPath(vg); nvgMoveTo(vg,-10,27)
        nvgBezierTo(vg,-60,-5,-35,-42,1,-31)
        nvgBezierTo(vg,44,-44,59,3,12,28); nvgClosePath(vg)
        finish(vg,color(tint),ink,2.6)
        for i=1,7 do
            local xx=-32+(i-1)*11
            curve(vg,0,24,xx*.45,7,xx*.9,-14,xx,-23+abs(xx)*.18,color(tint,255,.7),1.8)
        end
        arc(vg,0,1,31,22,pi*1.1,pi*1.9,color(CREAM,210),3)
        if flat then for i=1,5 do oval(vg,-25+i*9,-17,2.5,3,ink) end end
        box(vg,-10,22,22,9,3,color(CREAM),ink,1.8)
    end
    nvgRestore(vg)
end

function World.boat(vg, x, y, size, heading, time, speed)
    local t, moving = time or 0, clamp(abs(speed or 0)/120,0,1)
    nvgSave(vg); nvgTranslate(vg,x,y); nvgRotate(vg,heading or 0); nvgScale(vg,size/160,size/160)
    -- Wake is derived from time/speed, never appended to a simulation list.
    for i=1,7 do
        local age=(t*.7+i/7)%1
        local yy=55+age*(70+moving*90)
        local spread=27+age*(15+moving*50)
        if moving>.015 then
            curve(vg,-21,yy-8,-spread,yy,-spread-8,yy+12,-spread-20,yy+17,color(WHITE,(1-age)*125*moving),2+age*3)
            curve(vg,21,yy-8,spread,yy,spread+8,yy+12,spread+20,yy+17,color(WHITE,(1-age)*125*moving),2+age*3)
        end
    end
    oval(vg,5,10,43,68,color(INK,55))
    arc(vg,0,0,46,75,.1,pi-.1,color(FOAM,125),2)
    nvgTranslate(vg,0,sin(t*2.2)*1.8)
    nvgBeginPath(vg); nvgMoveTo(vg,0,-76)
    nvgBezierTo(vg,54,-55,47,29,33,58); nvgLineTo(vg,-33,58)
    nvgBezierTo(vg,-47,29,-54,-55,0,-76); nvgClosePath(vg)
    finish(vg,color(CREAM),color(INK),3.5)
    nvgBeginPath(vg); nvgMoveTo(vg,0,-66)
    nvgBezierTo(vg,42,-43,36,23,28,49); nvgLineTo(vg,-28,49)
    nvgBezierTo(vg,-36,23,-42,-43,0,-66); nvgClosePath(vg)
    finish(vg,color(WOOD),color(INK),2.4)
    for i=1,7 do
        local yy=-46+i*12; local ww=yy< -16 and 21 or 29
        line(vg,-ww,yy,ww,yy,color(INK,120),1)
        line(vg,-ww,yy+2,ww,yy+2,color(CREAM,85),1)
    end
    poly(vg,{-23,-34,23,-34,28,-24,-28,-24},color({237,169,85}),color(INK),1.5)
    box(vg,-30,15,60,12,3,color({229,160,83}),color(INK),2)
    box(vg,-18,-14,35,27,4,color({63,132,176}),color(INK),2)
    box(vg,-18,-18,35,11,3,color({123,196,222}),color(INK),2)
    box(vg,-3,-7,7,7,1,color(BRASS),color(INK),1)
    box(vg,-13,48,26,26,5,color({92,112,125}),color(INK),2.5)
    box(vg,-9,50,18,9,2,color({171,190,191}),color(INK),1)
    line(vg,0,72,0,82,color(INK),5); oval(vg,0,82,11,3,color(INK))
    line(vg,11,49,29,39,color(INK),3)
    oval(vg,0,-50,7,5,color(WOOD,255,.7),color(BRASS),2)
    nvgRestore(vg)
end

local function reef(vg, r, t)
    local x,y,s=r.x or 0,r.y or 0,r.radius or r.r or 55
    oval(vg,x+6,y+7,s*1.08,s*.7,color({20,102,121},100))
    arc(vg,x,y+3,s+12+sin(t)*2,s*.65+8,.1,pi*1.85,color(FOAM,200),3)
    poly(vg,{x-s*.85,y+s*.3,x-s*.7,y-s*.4,x-s*.2,y-s*.82,x+s*.32,y-s*.55,
        x+s*.85,y+s*.12,x+s*.52,y+s*.49,x-s*.3,y+s*.52},color({98,124,134}),color(INK),3)
    poly(vg,{x-s*.7,y-s*.4,x-s*.2,y-s*.82,x+s*.22,y-s*.48,x-s*.07,y+s*.27},color({177,186,170}))
    poly(vg,{x-s*.07,y+s*.27,x+s*.22,y-s*.48,x+s*.85,y+s*.12,x+s*.52,y+s*.49},color({63,88,108}))
    line(vg,x-s*.18,y-s*.65,x+s*.03,y-s*.38,color(CREAM,180),2)
end
local function worldEffects(vg,w,h,camera,t,isHome)
    local z=zoom(camera)
    local left,top=World.toWorld(0,0,w,h,camera)
    local right,bottom=World.toWorld(w,h,w,h,camera)
    -- Viewport-relative iteration is bounded even with the whole sea zoomed out.
    for i=1,36 do
        local wx=(i*191.31)%2000; local wy=(i*277.17)%2400
        if isHome then wx=i%2==0 and (wx%100) or 910+(wx%90); wy=wy%2000 end
        if wx>left-20 and wx<right+20 and wy>top-20 and wy<bottom+20 then
            local shine=max(0,sin(t*1.4+i*2.3))^8
            local len=(5+shine*9)/max(z,.3)
            curve(vg,wx-len,wy,wx-len*.4,wy+3,wx+len*.4,wy+3,wx+len,wy,color(WHITE,35+shine*145),1.2/max(z,.3))
        end
    end
    if isHome then
        for i=1,3 do
            local cx=(t*13+i*390)%1600-300; local cy=240+i*470
            nvgBeginPath(vg); nvgEllipse(vg,cx,cy,230,85)
            nvgFillPaint(vg,nvgRadialGradient(vg,cx,cy,20,230,color(INK,21),color(INK,0))); nvgFill(vg)
        end
    end
end
local function gulls(vg,w,h,t)
    for i=1,3 do
        local x=(t*12+i*151)%(w+90)-45
        local y=h*(.17+i*.105)+sin(t*.3+i)*18
        local flap=sin(t*3.3+i)*4
        curve(vg,x-10,y+flap,x-5,y-4,x-2,y-1,x,y+2,color(INK,85),3)
        curve(vg,x,y+2,x+3,y-2,x+6,y-4,x+11,y+flap,color(INK,85),3)
        curve(vg,x-10,y+flap-1,x-5,y-5,x-2,y-2,x,y+1,color(WHITE,220),1.8)
        curve(vg,x,y+1,x+3,y-3,x+6,y-5,x+11,y+flap-1,color(WHITE,220),1.8)
    end
end
local function schools(vg,ctx,w,h,camera,t,map)
    for i,s in ipairs(ctx.fishSchools or EMPTY) do
        if i>12 then break end
        local x,y=s.x or 0,s.y or 0
        local radius=s.radius or 85
        local sx,sy=World.toScreen(x,y,w,h,camera)
        if visible(sx,sy,(radius+65)*zoom(camera),w,h) then
            if map then
                -- Approximate field, deliberately independent of individual poses.
                for j=1,12 do
                    local a=j*TAU/12
                    arc(vg,x,y,radius+24,radius*.72+18,a,a+.24,color(CREAM,205),2/zoom(camera))
                end
                World.drawFish(vg,x-12,y,42,FISH[(i-1)%6+1],0,true)
                World.drawFish(vg,x+24,y+16,30,FISH[(i-1)%6+1],0,true)
            else
                local n=clamp(floor(s.count or 6),1,10)
                for j=1,n do
                    local phase=(s.phase or i*1.7)+j*2.399
                    local a=t*.19+phase; local rad=radius*(.4+.5*j/n)
                    local fx,fy=x+cos(a)*rad,y+sin(a)*rad*.65
                    nvgSave(vg); nvgTranslate(vg,fx,fy)
                    nvgRotate(vg,math.atan(cos(a)*.65,-sin(a)))
                    World.drawFish(vg,0,0,34+(j%3)*9,s.species or FISH[(i-1)%6+1],t*5+j,true)
                    nvgRestore(vg)
                end
            end
        end
    end
end
local function particles(vg,list,t,screen)
    for i,p in ipairs(list or EMPTY) do
        if i>64 then break end
        if (p.screen==true)==screen then
            local life=max(.01,p.life or 1)
            local age=p.age or (t-(p.born or t))
            if age>=0 and age<life then
                local q=age/life; local x=(p.x or 0)+(p.vx or 0)*age
                local y=(p.y or 0)+(p.vy or 0)*age
                local s=(p.size or 3)*(1-q*.6)
                oval(vg,x,y,s,s*.65,color(p.kind=='sand' and BRASS or WHITE,(1-q)*220))
            end
        end
    end
end

---@param view table|nil
---@return number, number
local function fishingView(view)
    view = view or EMPTY
    return clamp(view.viewX or 0,-VIEW_X,VIEW_X),clamp(view.viewY or 0,-VIEW_Y,VIEW_Y)
end

---@param index integer
---@param time number
---@param w number
---@param h number
---@param view table|nil ctx.fish; omit for the original unshifted pose.
---@return number, number, number, number, integer
function World.fishPose(index, time, w, h, view)
    local i,t=index,time or 0
    local a=t*(.11+(i%3)*.023)+i*1.73
    local rx=w*(.23+(i%3)*.035); local ry=h*(.105+(i%2)*.055)
    local x=w*.5+cos(a)*rx; local y=h*(.41+(i%3)*.043)+sin(a)*ry
    local viewX,viewY=fishingView(view)
    return x+viewX,y+viewY,math.atan(cos(a)*ry,-sin(a)*rx),w*(.09+(i%3)*.018),(i-1)%6+1
end
local function splash(vg,x,y,t,strength)
    for j=1,3 do
        local q=(t*1.05+j/3)%1
        arc(vg,x,y,12+q*38*strength,5+q*14*strength,.15,pi*1.9,color(WHITE,(1-q)*185),1.8)
    end
    for j=1,7 do
        local q=(t*1.35+j*.143)%1; local a=j*2.399
        oval(vg,x+cos(a)*q*31*strength,y+sin(a)*q*10-sin(q*pi)*22*strength,
            1+(1-q)*2,2+(1-q)*2,color(WHITE,(1-q)*210))
    end
end
local function fishing(vg,w,h,ctx,t)
    local f=ctx.fish or EMPTY
    local viewX,viewY=fishingView(f)
    ---@type table[]|nil
    local population=f.population
    local count=population ~= nil and #population or World.fishCount
    local shadowCount=population ~= nil and min(2,count) or 5
    -- Overscan the background by the full pan limits: dragging at either edge
    -- reveals more scenery instead of a blank strip. This affects no foreground
    -- transform; both fish loops use the exact same view as the public pose API.
    World.image(vg,(ctx.assets or EMPTY).fishing or 'image/crescent/fishing.jpg',
        viewX-VIEW_X,viewY-VIEW_Y,w+VIEW_X*2,h+VIEW_Y*2)
    for i=1,shadowCount do
        local x,y,a,s,k=World.fishPose(i+11,t*.85,w,h,f)
        local species=population and population[i] or FISH[k]
        nvgSave(vg); nvgTranslate(vg,x,y+30); nvgRotate(vg,a)
        World.drawFish(vg,0,0,s*.72,species,t*5+i,true); nvgRestore(vg)
    end
    for i=1,count do
        local x,y,a,s,k=World.fishPose(i,t,w,h,f)
        local species=population and population[i] or FISH[k]
        nvgSave(vg); nvgTranslate(vg,x,y); nvgRotate(vg,a)
        World.drawFish(vg,3,7,s,species,t*5+i,true)
        World.drawFish(vg,0,0,s,species,t*5+i); nvgRestore(vg)
    end
    local stage=f.stage or 'idle'
    local power,progress=clamp(f.power or .5,0,1),clamp(f.progress or 0,0,1)
    local hooked=stage=='hooked'; local safe=power>=.32 and power<=.72
    local side=hooked and ((f.rodSide or 0)+sin(t*2.6)*(safe and .65 or .18)) or sin(t*.8)*.04
    local ax,ay=clamp(f.aimX or w*.5,20,w-20),clamp(f.aimY or h*.43,120,h-170)
    local bx,by=w*.96,h-132
    local tx,ty=w*(.58+side*.14),h*.25+(hooked and 36+power*48 or sin(t)*3)
    if stage=='casting' then tx,ty=tx+sin(clamp(f.castT or 0,0,1)*pi)*w*.2,ty-40*sin((f.castT or 0)*pi) end
    local c1x,c1y,c2x,c2y=w*.83,h*.56,w*(.68+side*.1),h*.18+(hooked and 40+power*55 or 0)
    -- A small strip of boat is scenery only; HUD is rendered later by the parent.
    poly(vg,{0,h-39,w*.5,h-55,w,h-35,w,h,0,h},color(WOOD),color(INK),3)
    for j=1,6 do line(vg,j*w/6,h-45,j*w/6-13,h,color(INK,145),1.4) end
    curve(vg,-10,h-51,w*.3,h-78,w*.7,h-64,w+10,h-49,color(INK),12)
    curve(vg,-10,h-54,w*.3,h-81,w*.7,h-67,w+10,h-52,color(CREAM),6)
    local fx,fy=ax,ay+sin(t*3)*1.4
    if hooked then fx,fy=ax+sin(t*2.3)*29*(1-progress*.5),ay+progress*h*.13 end
    if stage=='aim' then
        for j=1,14 do
            local u=(j-1)/14; local v=u+.043
            local function point(q) return bx+(ax-bx)*q,by+(ay-by)*q-sin(q*pi)*100 end
            local x1,y1=point(u); local x2,y2=point(v)
            line(vg,x1,y1,x2,y2,color(CREAM,225),2)
        end
        oval(vg,ax,ay,25+sin(t*4)*2,10,color(BRASS,40),color(CREAM),2.4)
        oval(vg,ax,ay,4,2,color(BRASS))
    elseif stage~='idle' then
        if stage=='casting' then
            local u=clamp(f.castT or 0,0,1)
            fx,fy=tx+(ax-tx)*u,ty+(ay-ty)*u-sin(u*pi)*h*.19
        end
        curve(vg,tx,ty,tx-12,ty+15,fx+8,fy-25,fx,fy,color(CREAM,235),1.1)
        if stage~='casting' then splash(vg,fx,fy,t,hooked and .85 or .25) end
        if hooked then
            nvgSave(vg); nvgTranslate(vg,fx,fy+8); nvgRotate(vg,sin(t*2.3)*.9)
            World.drawFish(vg,0,0,58-progress*9,f.species or FISH[6],t*13); nvgRestore(vg)
        elseif stage=='landed' then
            World.drawFish(vg,fx,fy-45-abs(sin(t*2))*8,78,f.species or FISH[6],t*3)
        end
        line(vg,fx,fy-13,fx,fy+7,color(INK),2)
        oval(vg,fx,fy-2,3.5,6,color(CREAM),color(INK),1)
        oval(vg,fx,fy-5,3,3.6,color({231,104,73}))
    end
    -- Tapered graphite blank follows the same cubic used for all brass guides.
    local function rodPoint(u)
        local v=1-u
        return v^3*bx+3*v*v*u*c1x+3*v*u*u*c2x+u^3*tx,
            v^3*by+3*v*v*u*c1y+3*v*u*u*c2y+u^3*ty
    end
    for j=1,14 do
        local u,v=(j-1)/14,j/14
        local x1,y1=rodPoint(u); local x2,y2=rodPoint(v)
        line(vg,x1,y1,x2,y2,color(INK),9-6*u)
        line(vg,x1-.7,y1,x2-.7,y2,color({86,110,119}),5.5-4*u)
    end
    for j=1,5 do
        local x,y=rodPoint(j/5)
        oval(vg,x-3,y,3.5-j*.35,2.4,color(INK),color(BRASS),1.2)
    end
    local gx,gy=rodPoint(.12)
    line(vg,bx,by,gx,gy,color(INK),14); line(vg,bx,by,gx,gy,color({141,99,57}),9)
    oval(vg,bx-12,by-24,13,17,color(INK),color(BRASS),2.4)
    oval(vg,bx-12,by-24,7,11,color({86,139,149}),color(CREAM),1)
end

local function shoreTargets(vg,shore,t,w,h,camera)
    for i,target in ipairs(shore.targets or EMPTY) do
        if i>64 then break end
        local x,y=target.x or 0,target.y or 0
        local sx,sy=World.toScreen(x,y,w,h,camera)
        if not target.collected and visible(sx,sy,60*zoom(camera),w,h) then
            local p=t*3+(target.phase or i)
            if target.kind=='hole' then
                oval(vg,x+2,y+4,23,12,color({176,137,83},100))
                oval(vg,x,y,19,10,color({185,142,91}),color({127,101,69}),1.5)
                oval(vg,x-2,y-1,12,6,color({63,68,60}))
                arc(vg,x,y,20,10,pi,TAU,color(CREAM,190),2)
                for j=1,4 do oval(vg,x+cos(j*2.4)*26,y+sin(j*2.4)*13,2,1.5,color({142,111,74})) end
            elseif target.kind=='mound' then
                oval(vg,x,y+9,36,15,color({153,121,80},90))
                poly(vg,{x-32,y+8,x-23,y-6,x-9,y-18,x+8,y-20,x+28,y-1,x+34,y+11,x,y+17},
                    color({215,175,114}),color({151,118,77}),2)
                poly(vg,{x-23,y-6,x-9,y-18,x+8,y-20,x+5,y-2,x-13,y+8},color({242,211,155}))
                for j=1,6 do oval(vg,x-20+j*7,y+sin(j*2)*7,2,1.2,color({153,122,80},180)) end
            else
                World.drawCreature(vg,x,y,70,target.species or (target.kind=='crab' and 'crab' or 'shell'),p)
            end
        end
    end
end
local function tool(vg,w,h,shore,t,camera,project)
    local action=shore.action
    local q=action and clamp(action.t or 0,0,1) or 0
    local target=action or EMPTY
    local targetX,targetY=target.tx or shore.x or 900,target.ty or shore.y or 1000
    local projectedX,projectedY
    if project then projectedX,projectedY=project(targetX,targetY)
    else projectedX,projectedY=World.toScreen(targetX,targetY,w,h,camera)end
    local tx=action and projectedX or w*.78
    local ty=action and projectedY or h*.57
    local bx,by=w*.96,h-150; local lift=action and sin(q*pi)*20 or sin(t*1.8)*3
    local dx,dy=tx-bx,ty-by-lift
    local length=clamp(math.sqrt(dx*dx+dy*dy),65,h*.7)
    nvgSave(vg); nvgTranslate(vg,bx,by); nvgRotate(vg,math.atan(dy,dx)+pi*.5)
    if action and (action.kind=='dig' or action.kind=='shovel') then
        line(vg,0,0,0,-length+20,color(INK),11); line(vg,0,0,0,-length+20,color(WOOD),6)
        poly(vg,{-18,-length+23,-22,-length-9,0,-length-29,22,-length-9,18,-length+23},
            color({162,185,185}),color(INK),2.4)
        poly(vg,{0,-length+20,0,-length-24,18,-length-8,15,-length+18},color({101,138,149}))
    elseif action and action.kind=='salt' then
        box(vg,-17,-length+6,34,52,6,color(CREAM),color(INK),2.4)
        box(vg,-20,-length,40,16,4,color({90,151,170}),color(INK),2)
        for i=1,3 do oval(vg,-10+i*5,-length+4,1.5,1.5,color(INK)) end
    else
        local gap=action and (14-10*sin(q*pi)) or 14
        for side=-1,1,2 do
            curve(vg,side*6,0,side*12,-length*.35,side*5,-length*.72,side*gap,-length,color(INK),7)
            curve(vg,side*6,0,side*12,-length*.35,side*5,-length*.72,side*gap,-length,color({184,209,207}),3.4)
            line(vg,side*gap,-length,side*(gap-4),-length-10,color(INK),5)
        end
        oval(vg,0,-length*.62,5,5,color(BRASS),color(INK),1.6)
    end
    nvgRestore(vg)
    if action then
        if action.kind=='salt' or action.kind=='dig' or action.kind=='shovel' then
            for i=1,9 do
                local a=i*2.399; local r=sin(q*pi)*(8+i*2)
                oval(vg,tx+cos(a)*r,ty+sin(a)*r*.4-sin(q*pi)*i*2,1.5,2,
                    color(action.kind=='salt' and CREAM or BRASS,sin(q*pi)*230))
            end
        elseif q>.4 then
            World.drawCreature(vg,tx,ty-lift,38,action.species or 'crab',t*4)
        end
    end
end

World.drawTool=tool
function World.draw(vg,w,h,ctx)
    if not vg or w<=0 or h<=0 then return end
    ctx=ctx or EMPTY
    local mode,t=ctx.mode or 'home',ctx.time or 0
    local boat,shore,assets=ctx.boat or EMPTY,ctx.shore or EMPTY,ctx.assets or EMPTY
    local defaults={x=500,y=1000,zoom=.45}
    if mode=='shore' then defaults={x=shore.x or 900,y=shore.y or 1000,zoom=.65}
    elseif mode=='map' then defaults={x=1000,y=1200,zoom=min(w/2100,h/2500)}
    elseif mode=='sailing' then defaults={x=boat.x or 1000,y=boat.y or 1100,zoom=.55} end
    local input=ctx.camera or EMPTY
    local camera={x=input.x or defaults.x,y=input.y or defaults.y,zoom=input.zoom or defaults.zoom}
    nvgSave(vg); nvgIntersectScissor(vg,0,0,w,h)
    nvgLineCap(vg,NVG_ROUND); nvgLineJoin(vg,NVG_ROUND)
    nvgBeginPath(vg); nvgRect(vg,0,0,w,h)
    nvgFillPaint(vg,nvgLinearGradient(vg,0,0,w,h,color({18,134,174}),color({27,176,194}))); nvgFill(vg)
    if mode=='fishing' then
        fishing(vg,w,h,ctx,t)
        -- In first person, particles without screen=true are still local pixels.
        particles(vg,ctx.particles,t,false)
    else
        nvgSave(vg); nvgTranslate(vg,w*.5,h*.5); nvgScale(vg,zoom(camera),zoom(camera))
        nvgTranslate(vg,-camera.x,-camera.y)
        if mode=='home' then
            imageRect(vg,assets.island or 'image/crescent/island.jpg',0,0,1000,2000,1,true)
        elseif mode=='shore' then
            imageRect(vg,assets.shore or 'image/crescent/shore.jpg',0,0,1800,2000,1,true)
        else
            imageRect(vg,assets.sea or 'image/crescent/sea.jpg',0,0,2000,2400,1,true)
        end
        if mode~='shore' then worldEffects(vg,w,h,camera,t,mode=='home') end
        if mode=='sailing' or mode=='map' then
            schools(vg,ctx,w,h,camera,t,mode=='map')
            for i,r in ipairs(ctx.reefs or EMPTY) do
                if i>64 then break end
                local sx,sy=World.toScreen(r.x or 0,r.y or 0,w,h,camera)
                if visible(sx,sy,((r.radius or r.r or 55)+20)*zoom(camera),w,h) then reef(vg,r,t+i) end
            end
            if mode=='map' then
                nvgSave(vg); nvgTranslate(vg,boat.x or 1000,boat.y or 1100)
                nvgScale(vg,1/zoom(camera),1/zoom(camera)); nvgRotate(vg,boat.heading or 0)
                oval(vg,0,0,16,16,color(BRASS,70),color(CREAM),2)
                poly(vg,{0,-14,9,10,0,6,-9,10},color(CREAM),color(INK),2)
                nvgRestore(vg)
            else World.boat(vg,boat.x or 1000,boat.y or 1100,160,boat.heading,t,boat.speed) end
        elseif mode=='shore' then shoreTargets(vg,shore,t,w,h,camera) end
        particles(vg,ctx.particles,t,false)
        nvgRestore(vg)
        if mode=='shore' then tool(vg,w,h,shore,t,camera) else gulls(vg,w,h,t) end
    end
    -- A faint warm sun wash is below the HUD, never a grey screen filter.
    nvgBeginPath(vg); nvgRect(vg,0,0,w,h)
    nvgFillPaint(vg,nvgRadialGradient(vg,w*.12+sin(t*.08)*30,h*.12,10,w*.9,
        color({255,238,170},mode=='home' and 23 or 10),color(CREAM,0))); nvgFill(vg)
    particles(vg,ctx.particles,t,true)
    nvgRestore(vg)
end

return World
