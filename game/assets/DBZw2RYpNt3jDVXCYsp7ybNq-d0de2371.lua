-- One camera/gesture contract for the fishing observation window.
-- Keep the existing fish population and world positions; reveal more of them.
local Cast=require("Game.FishingCast")
local V={height=7.2,back=12,xLimit=220,yMin=-120,yMax=160,rodStep=.60,rodSeat=.35}
local rad=math.pi/180
local function clamp(x,a,b)return math.max(a,math.min(b,x))end
function V.Clamp(x,y)
 return clamp(x,-V.xLimit,V.xLimit),clamp(y,V.yMin,V.yMax)
end
function V.Drag(x,y,dx,dy)
 return V.Clamp(x+dx*.55,y+dy*.55)
end
local function angles(x,y,aspect)
 x,y=V.Clamp(x,y)
 -- Preserve useful horizontal coverage on tall portrait phones.
 local fov=clamp(2*math.atan(math.tan(20*rad)/math.max(aspect,.3))/rad,68,80)
 return fov,-x*.28*rad,(32-y*.22)*rad
end
function V.Camera(x,y,aspect)
 local fov,yaw,pitch=angles(x,y,aspect)
 local cp=math.cos(pitch)
 return fov,math.sin(yaw)*cp,-math.sin(pitch),math.cos(yaw)*cp
end
function V.AimTop(y,aspect,height)
 local fov,_,pitch=angles(0,y,aspect)
 -- Place the cast row five degrees below the centre horizon, also after
 -- looking up. This avoids casts into sky or near-parallel water rays.
 local waterY=height*(.5-.5*math.tan(pitch-5*rad)/math.tan(fov*.5*rad))+2
 return math.max(140,waterY)
end
-- A compact camera-relative rod pivots at the reel seat. The backswing may
-- naturally leave the portrait frame; never translate the hand to chase it.
function V.RodSeat(aspect,lookY)
 local fov=V.Camera(0,0,aspect);local span=math.tan(fov*.5*rad)
 local lift=clamp(-(lookY or 0)/120,0,1)
 return span*aspect*.48,-span*.76,.72,.46*span/math.tan(40*rad),lift
end
local function ease(k)k=clamp(k,0,1);return k*k*k*(k*(k*6-15)+10)end
-- Anticipation, forward stroke and follow-through have separate durations.
-- The lure leaves during the stroke, while the rod continues settling.
function V.RodPose(aspect,lookY,stage,charge,elapsed,start)
 local x,y,z,size,lift=V.RodSeat(aspect,lookY)
 local c=clamp(charge or 0,0,1)
 local forward=-24-lift*2
 local raised=-32-lift*2-c*72
 local held=stage=="idle"or stage=="aim"
 local pose={x=x,y=y,z=z,size=size,pitch=held and raised or forward,
  yaw=-4,roll=0,bend=.035+(held and c*.025 or 0)}
 if stage=="casting"then
  local t=elapsed or (Cast.flickSeconds+Cast.followSeconds)
  local back=ease(t/Cast.windupSeconds)
  local stroke=ease((t-Cast.windupSeconds)/Cast.strokeSeconds)
  local settle=ease((t-Cast.flickSeconds)/Cast.followSeconds)
  local loaded=-104-lift*2
  local from=start or {x=x,y=y,z=z,size=size,pitch=raised,yaw=-4,roll=0,bend=.035+c*.025}
  -- The hand remains on the reel seat. A quick tap still has an anticipation;
  -- a charged cast continues from the actual raised pose instead of snapping.
  pose.pitch=from.pitch+(loaded-from.pitch)*back+(-18-loaded)*stroke+(forward+18)*settle
  pose.yaw=from.yaw+(-4-from.yaw)*back
  pose.x=from.x+(x-from.x)*back;pose.y=from.y+(y-from.y)*back
  pose.z=from.z+(z-from.z)*back;pose.size=from.size+(size-from.size)*back
  pose.bend=from.bend+(.035+c*.025-from.bend)*back-c*.025*stroke-math.sin(stroke*math.pi)*.09
 end
 return pose
end
-- Same nine-segment bend and Yaw*Pitch rotation as the retained rod mesh.
-- Align the RELEASE tip with the vertical camera/landing plane: gravity then
-- keeps the entire trajectory in that plane, including off-centre aiming.
function V.RodTip(pose)
 local y,z=-pose.bend*81*.025*pose.size,(9*V.rodStep-V.rodSeat)*pose.size
 local p,q=pose.pitch*rad,pose.yaw*rad
 local yy,zz=y*math.cos(p)-z*math.sin(p),y*math.sin(p)+z*math.cos(p)
 return pose.x+zz*math.sin(q),pose.y+yy,pose.z+zz*math.cos(q)
end
function V.RodRoot(pose)
 local p,q=pose.pitch*rad,pose.yaw*rad;local offset=V.rodSeat*pose.size
 return pose.x-offset*math.cos(p)*math.sin(q),pose.y+offset*math.sin(p),pose.z-offset*math.cos(p)*math.cos(q)
end
function V.AlignRod(pose,nx,ny,nz)
 local y,z=-pose.bend*81*.025*pose.size,(9*V.rodStep-V.rodSeat)*pose.size
 local p=pose.pitch*rad
 local yy,zz=y*math.cos(p)-z*math.sin(p),y*math.sin(p)+z*math.cos(p)
 if zz<.4 then return pose end -- A natural backswing may leave the view.
 local a,b=nx*zz,nz*zz;local length=math.sqrt(a*a+b*b)
 if length>1e-6 then
  local k=clamp(-(nx*pose.x+ny*(pose.y+yy)+nz*pose.z)/length,-1,1)
  pose.yaw=(math.asin(k)-math.atan(b,a))/rad
 end
 return pose
end
-- Retain the pose across stage changes, including charge cancellation and
-- bringing an empty rod back. The same elapsed time gives the same response
-- at 30/60/120 Hz; no world-space interpolation can drag the line's water end.
function V.SmoothRod(current,target,dt,stage)
 if not current then return target end
 local speed=stage=="casting"and 14 or stage=="aim"and 7 or 5
 local k=1-math.exp(-math.max(0,dt or 1/60)*speed)
 for key,value in pairs(target)do current[key]=current[key]+(value-current[key])*k end
 return current
end
-- The crossing swell and slow envelope avoid a single repeating sine.
-- Shared heave lets the eye and held rod ride with the boat.
function V.Bob(heave,pitch,roll,t)
 local h=heave*(.30+.06*math.sin(t*.37))+.022*math.sin(t*.71)+.012*math.sin(t*1.13+.8)
 return h,pitch*.17,roll*.17
end
return V
