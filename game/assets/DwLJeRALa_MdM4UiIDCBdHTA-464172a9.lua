-- Cached geography: zero polygon searches or image readbacks during play.
local data=require("Game.OceanFieldData")
local F={}
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
function F.Sample(x,z,mode)
 if mode=="fishing" then
  local r=math.sqrt(x*x+(z+9)*(z+9))
  local k=clamp((r-3)/37,0,1);k=k*k*(3-2*k)
  return 16,18+k*12
 end
 if mode=="shore" then return 16,28 end
 local map=mode=="home" and data.home or data.bay
 local gx=clamp((x/map.span+.5)*(data.size-1),0,data.size-1)
 local gy=clamp((.5-z/map.span)*(data.size-1),0,data.size-1)
 local ix,iy=math.min(data.size-2,math.floor(gx)),math.min(data.size-2,math.floor(gy))
 local fx,fy=gx-ix,gy-iy
 local a,b,c,d=map.rows[iy+1]:byte(ix*2+1,ix*2+4)
 local e,f,g,h=map.rows[iy+2]:byte(ix*2+1,ix*2+4)
 return ((a*(1-fx)+c*fx)*(1-fy)+(e*(1-fx)+g*fx)*fy)/255*32-16,
  ((b*(1-fx)+d*fx)*(1-fy)+(f*(1-fx)+h*fx)*fy)/255*32
end
function F.Damping(x,z,mode)
 if mode=="fishing" or mode=="shore" then return 1 end
 local coast,depth=F.Sample(x,z,mode)
 local k=clamp(coast/5,0,1);k=k*k*(3-2*k)
 return .10+.90*k*clamp(depth/2,0,1)
end
return F
