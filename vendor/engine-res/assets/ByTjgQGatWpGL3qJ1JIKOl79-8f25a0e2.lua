local Widget = require("urhox-libs/UI/Core/Widget")
local UI = require("urhox-libs/UI/Core/UI")

---@class SvgProps : WidgetProps
---@field src? string Preloaded or explicitly downloaded SVG resource path.
---@field objectFit? "contain"|"cover"|"fill"|"none" Centered fitting; defaults to contain.
---@field onClick? fun(widget: Svg, event: PointerEvent)

---@class Svg : Widget
---@field props SvgProps
---@field svgInstance_ SvgInstance?
---@field renderFailed_ boolean
---@overload fun(props: SvgProps): Svg
local Svg = Widget:Extend("Svg")

--- Compute the same viewport-to-widget transform for drawing and picking.
---@param instance SvgInstance
---@param layout table Widget rectangle in UI base pixels.
---@param fit string
---@return number? x, number? y, number? scaleX, number? scaleY
local function contentTransform(instance, layout, fit)
    local width, height = instance:GetWidth(), instance:GetHeight()
    if not (width > 0 and height > 0 and layout.w > 0 and layout.h > 0) then return end
    local sx, sy = layout.w / width, layout.h / height
    if fit == "none" then
        sx, sy = 1, 1
    elseif fit ~= "fill" then
        local scale = fit == "cover" and math.max(sx, sy) or math.min(sx, sy)
        sx, sy = scale, scale
    end
    return layout.x + (layout.w - width * sx) * 0.5,
        layout.y + (layout.h - height * sy) * 0.5, sx, sy
end

--- Initialize an SVG widget on the existing UI canvas. Call UI.Init first.
---@param props SvgProps
function Svg:Init(props)
    props.objectFit = props.objectFit or "contain"
    local src = props.src
    props.src = nil
    local nvg = UI.GetNVGContext()
    self.svgInstance_ = nvg and nvgSvgCreate(nvg) or nil
    self.renderFailed_ = false
    Widget.Init(self, props)
    if src then self:LoadSvg(src) end
end

--- Load synchronously; failure preserves the previous document, source and node handles.
--- Successful reloads reset time while preserving native pause and playback rate.
--- The first load, or a load after unloading, starts playback at the normal rate.
---@param path string Resource-relative SVG path; downloads are owned by the caller.
---@return boolean loaded Failure is reported through the engine log.
function Svg:LoadSvg(path)
    local instance = self.svgInstance_
    if not instance then
        local nvg = UI.GetNVGContext()
        if not nvg then
            log:Write(LOG_ERROR, "[UI.Svg] UI.Init must be called before loading an SVG widget")
            return false
        end
        instance = nvgSvgCreate(nvg)
        self.svgInstance_ = instance
    end
    local loaded = instance:IsLoaded()
    local paused = loaded and instance:AnimationsPaused()
    local playbackRate = loaded and instance:GetPlaybackRate() or 1
    if not instance:Load(path) then
        log:Write(LOG_ERROR, "[UI.Svg] " .. instance:GetError())
        return false
    end
    self.props.src = path
    instance:SetPlaybackRate(playbackRate)
    if not paused then instance:UnpauseAnimations() end
    self.renderFailed_ = false
    return true
end

--- Change the resource; nil or an empty string unloads it. Identical loaded paths are reused.
---@param path string?
---@return boolean loaded
function Svg:SetSrc(path)
    if not path or path == "" then
        self:UnloadSvg()
        return true
    end
    if path == self.props.src and self:IsLoaded() then return true end
    return self:LoadSvg(path)
end

--- Unload the document and invalidate its node handles without destroying the widget.
function Svg:UnloadSvg()
    if self.svgInstance_ then self.svgInstance_:Unload() end
    self.props.src = nil
    self.renderFailed_ = false
end

--- Release the SVG and the standard widget tree; never delete the shared UI canvas.
function Svg:Destroy()
    self:UnloadSvg()
    self.svgInstance_ = nil
    Widget.Destroy(self)
end

--- Advance once through the UI update tree; callers must not also update the instance.
---@param dt number Frame duration in seconds.
function Svg:Update(dt)
    if self.svgInstance_ then self.svgInstance_:Update(dt) end
end

--- Draw directly into the UI frame, preserving ancestor transforms, clipping and opacity.
--- Log the first failure in each consecutive sequence of failed draws.
---@param nvg NVGContextWrapper The shared UI canvas.
function Svg:Render(nvg)
    self:RenderFullBackground(nvg)
    if not self:IsLoaded() then return end
    local layout = self:GetAbsoluteLayout()
    local x, y, sx, sy = contentTransform(self.svgInstance_, layout, self.props.objectFit)
    if not x then return end
    nvgSave(nvg)
    nvgIntersectScissor(nvg, layout.x, layout.y, layout.w, layout.h)
    nvgTranslate(nvg, x, y)
    nvgScale(nvg, sx, sy)
    local drawn = nvgSvgRender(nvg, self.svgInstance_)
    nvgRestore(nvg)
    if not drawn and not self.renderFailed_ then
        local message = self.svgInstance_:GetError()
        log:Write(LOG_ERROR, "[UI.Svg] " .. (message ~= "" and message or "SVG rendering failed"))
    end
    self.renderFailed_ = not drawn
end

--- Change centered fitting without reloading the resource.
---@param fit "contain"|"cover"|"fill"|"none"
---@return Svg self
function Svg:SetObjectFit(fit)
    self.props.objectFit = fit
    return self
end

--- Return whether this widget has a loaded SVG document.
---@return boolean
function Svg:IsLoaded()
    return self.svgInstance_ and self.svgInstance_:IsLoaded() or false
end

--- Access native playback and element APIs; the widget owns update and lifetime.
---@return SvgInstance?
function Svg:GetNativeInstance() return self.svgInstance_ end

--- Map UI layout coordinates to the SVG viewport, rejecting points outside the widget.
---@param widget Svg
---@param x number
---@param y number
---@return number? x, number? y, number? tolerance
local function hitTestCoordinates(widget, x, y)
    if not widget:IsLoaded() then return end
    local layout = widget:GetAbsoluteLayoutForHitTest()
    if x < layout.x or y < layout.y or x > layout.x + layout.w or y > layout.y + layout.h then
        return
    end
    local ox, oy, sx, sy = contentTransform(widget.svgInstance_, layout, widget.props.objectFit)
    if not ox then return end
    return (x - ox) / sx, (y - oy) / sy, 0.1 / math.max(sx, sy)
end

--- Pick an SVG element using the same layout coordinates as Widget:HitTest.
---@param x number X in UI base pixels, including the widget's layout position.
---@param y number Y in UI base pixels, including the widget's layout position.
---@return SvgElement? Element at the point, or nil if none is hit.
function Svg:HitTestElement(x, y)
    local sx, sy, tolerance = hitTestCoordinates(self, x, y)
    if not sx then return nil end
    return self.svgInstance_:ElementFromPoint(sx, sy, tolerance)
end

--- Pick all SVG elements using the same layout coordinates as Widget:HitTest.
--- Includes the root SVG viewport last when hit, even over blank SVG content.
---@param x number X in UI base pixels, including the widget's layout position.
---@param y number Y in UI base pixels, including the widget's layout position.
---@return SvgElement[] Elements from topmost to bottommost without duplicates; empty if none is hit.
function Svg:HitTestElements(x, y)
    local sx, sy, tolerance = hitTestCoordinates(self, x, y)
    if not sx then return {} end
    return self.svgInstance_:ElementsFromPoint(sx, sy, tolerance)
end

return Svg
