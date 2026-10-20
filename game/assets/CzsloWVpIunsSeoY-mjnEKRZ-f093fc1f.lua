-- Small ballistic cast model: wind up for 1.1 s, then release toward the
-- water guide. Charging extends horizontal reach; the flight has gravity.
local C={chargeSeconds=1.1,maxRange=42,guaranteeSeconds=30,arrivalSeconds=4}
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
function C.Charge(seconds)return clamp(seconds/C.chargeSeconds,0,1)end
function C.Target(origin,guide,charge)
 local x,z=guide.x-origin.x,guide.z-origin.z
 local n=math.sqrt(x*x+z*z)
 if n<1e-6 then x,z,n=0,1,1 end
 local reach=clamp(n+24*clamp(charge,0,1),8,C.maxRange)
 return {x=origin.x+x/n*reach,y=0,z=origin.z+z/n*reach},reach
end
function C.Duration(reach)return .7+clamp(reach,8,C.maxRange)*.015 end
function C.Flight(origin,target,phase,duration)
 local k=clamp(phase,0,1);local arc=4.905*duration*duration*k*(1-k)
 return {x=origin.x+(target.x-origin.x)*k,y=origin.y+(target.y-origin.y)*k+arc,
  z=origin.z+(target.z-origin.z)*k}
end
return C
