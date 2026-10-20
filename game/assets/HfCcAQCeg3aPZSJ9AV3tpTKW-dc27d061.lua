-- Small ballistic cast model: wind up for 1.1 s, then release toward the
-- water guide. Charging extends horizontal reach; the flight has gravity.
local C={chargeSeconds=1.1,flickSeconds=.16,maxRange=42,guaranteeSeconds=30,arrivalSeconds=4}
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
function C.Charge(seconds)return clamp(seconds/C.chargeSeconds,0,1)end
function C.Target(origin,guide,charge)
 local x,z=guide.x-origin.x,guide.z-origin.z
 local n=math.sqrt(x*x+z*z)
 if n<1e-6 then x,z,n=0,1,1 end
 local reach=clamp(clamp(n,8,18)+24*clamp(charge,0,1),8,C.maxRange)
 return {x=origin.x+x/n*reach,y=0,z=origin.z+z/n*reach},reach
end
function C.Duration(reach)return .7+clamp(reach,8,C.maxRange)*.015 end
function C.Flight(origin,target,phase,duration)
 local k=clamp(phase,0,1);local arc=4.905*duration*duration*k*(1-k)
 return {x=origin.x+(target.x-origin.x)*k,y=origin.y+(target.y-origin.y)*k+arc,
  z=origin.z+(target.z-origin.z)*k}
end
-- Resample the visible projected curve in screen space. Uniform flight-time
-- samples bunch at the landing point and scatter at the near end in perspective.
function C.Guide(origin,target,duration,project,bounds)
 local samples={};local total=0;local previous=nil
 for i=0,64 do
  local q=C.Flight(origin,target,i/64,duration);local x,y,z=project(q)
  local visible=x and y and z and z>.15 and x>=bounds.left and x<=bounds.right and y>=bounds.top and y<=bounds.bottom
  if visible then
   local length=previous and math.sqrt((x-previous.x)^2+(y-previous.y)^2)or 0
   samples[#samples+1]={x=x,y=y,length=length,connected=previous~=nil}
   total=total+length;previous={x=x,y=y}
  else previous=nil end
 end
 local dots={};local spacing=math.max(7,total/32);local carry=0;previous=nil
 for _,p in ipairs(samples)do
  if not p.connected then carry=0;if #dots<36 then dots[#dots+1]={x=p.x,y=p.y}end
  elseif p.length>1e-5 then
   local at=spacing-carry
   while at<=p.length and #dots<36 do
    local k=at/p.length;dots[#dots+1]={x=previous.x+(p.x-previous.x)*k,y=previous.y+(p.y-previous.y)*k}
    at=at+spacing
   end
   carry=(carry+p.length)%spacing
  end
  previous=p
 end
 return dots
end
return C
