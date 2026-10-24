-- Native Yoga panels/buttons keep their existing layout, focus and input behavior.
local UI=require("urhox-libs/UI")
local Skin=require("Game.UISkin")
local Panel=UI.Panel:Extend("NauticalPanel")
function Panel:Render(v)
 local l=self:GetAbsoluteLayout()
 if not Skin.Draw(v,self.props.skin or"PLT-page",l.x,l.y,l.w,l.h,nil,1,self.props.artScale or 1)then UI.Panel.Render(self,v)end
end
local Button=UI.Button:Extend("NauticalSettingsButton")
function Button:RenderFullBackground(v,overrides)
 local l=self:GetAbsoluteLayout();local p=self.props
 if not Skin.Button(v,l.x,l.y,l.w,l.h,"gold",self.state.pressed,self.state.hovered,p.disabled,p.skin,nil,p.artScale or 1)then
  UI.Widget.RenderFullBackground(self,v,overrides)
 end
end
return {Panel=Panel,Button=Button}
