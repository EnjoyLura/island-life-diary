-- Three sea regions share the original village as their hub. Only the east
-- fishing grounds have encounters for now; the western regions are reserved.
local S={home={x=90,y=2070,scale=.66},originalEastRight=4900,eastAreaScale=2}
local h=S.home
S.east={id="east",name="东部海域",developed=true,left=h.x,
 right=h.x+(S.originalEastRight-h.x)*S.eastAreaScale,top=-3600,bottom=5600}
S.northwest={id="northwest",name="西北海域",developed=false,
 left=-4200,right=h.x,top=-3600,bottom=h.y}
S.southwest={id="southwest",name="西南海域",developed=false,
 left=-4200,right=h.x,top=h.y,bottom=5600}
S.all={S.east,S.northwest,S.southwest}
function S.Contains(region,x,y)
 return x>=region.left and x<=region.right and y>=region.top and y<=region.bottom
end
function S.Area(region)return (region.right-region.left)*(region.bottom-region.top)*.04^2 end
return S
