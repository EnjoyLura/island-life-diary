-- All menus and controls live in the supported Yoga/NanoVG widget tree.
local UI = require("urhox-libs/UI")
local A = require("Game.Art")
local W = {}
local Surface = UI.Widget:Extend("IslandSurface")
function Surface:Init(props) UI.Widget.Init(self,props) end
function Surface:Render(vg) if self.props.draw then self.props.draw(vg,self:GetAbsoluteLayout()) end end
W.Surface=Surface
local Button = UI.Widget:Extend("IslandButton")
function Button:Init(props)
 UI.Widget.Init(self,props);self.down_=false;self.hover_=false;self.clickReady_=false
end
function Button:OnPointerEnter(event) self.hover_=true;UI.Widget.OnPointerEnter(self,event) end
function Button:OnPointerLeave(event) self.hover_=false;UI.Widget.OnPointerLeave(self,event) end
function Button:OnPointerDown(event)
 if not event:IsPrimaryAction() or self.props.disabled then return end
 if self.down_ and self.pressPointer_~=event.pointerId then return end
 self.down_=true;self.pressPointer_=event.pointerId;self.clickReady_=false;self.clickPointer_=nil;event:StopPropagation()
 if self.props.press then self.props.press(event,self) end
end
function Button:OnPointerUp(event)
 if not event:IsPrimaryAction() or self.pressPointer_~=event.pointerId then return end
 self.clickReady_=self.down_;self.clickPointer_=event.pointerId;self.down_=false;self.pressPointer_=nil;event:StopPropagation()
 if self.props.release then self.props.release(event,self) end
end
function Button:OnPointerCancel(event)
 if self.pressPointer_~=event.pointerId then return end
 self.down_=false;self.pressPointer_=nil;self.clickReady_=false;self.clickPointer_=nil
 if self.props.cancel then self.props.cancel(event,self) end
end
function Button:OnClick(event)
 local ready=self.clickReady_ and self.clickPointer_==event.pointerId
 self.clickReady_=false;self.clickPointer_=nil
 if ready and event:IsPrimaryAction() and self.props.action and not self.props.disabled then self.props.action(self,event) end
end
function Button:Render(vg)
 local l=self:GetAbsoluteLayout();local p=self.props;local s=l.w/(p.vw or l.w)
 nvgSave(vg);nvgTranslate(vg,l.x,l.y);nvgScale(vg,s,s)
 local w,h=l.w/s,l.h/s
 local tone=type(p.tone)=="function" and p.tone() or p.tone
 if p.draw then p.draw(vg,w,h,self.down_,self.hover_)
 else
  local dy=self.down_ and 2 or 0
  A.plate(vg,0,dy,w,h-2,tone,self.down_)
  if self.hover_ then A.rect(vg,3,3,w-6,h-8,{255,255,255,30},6) end
  local text=type(p.text)=="function" and p.text() or p.text or ""
  local sub=type(p.sub)=="function" and p.sub() or p.sub
  if p.icon and p.iconOnly then A.icon(vg,p.icon,w/2,h/2-2,p.iconSize or 27)
  elseif p.icon and h>60 then A.icon(vg,p.icon,w/2,h*.34,p.iconSize or 31);A.text(vg,w/2,h*.77+dy,text,p.size or 15,A.ink,NVG_ALIGN_CENTER)
  else
   if p.icon then A.icon(vg,p.icon,23,h/2-2,p.iconSize or 25) end
   local light=tone=="dark" or tone=="blue"
   A.text(vg,p.icon and (w+24)/2 or w/2,sub and h*.38+dy or h/2-2+dy,text,p.size or 16,light and A.cream or A.ink,NVG_ALIGN_CENTER)
   if sub then A.text(vg,w/2,h*.74+dy,sub,11,light and {211,233,234,255} or {85,106,103,255},NVG_ALIGN_CENTER,false) end
  end
 end
 nvgRestore(vg)
end
W.Button=Button
return W
