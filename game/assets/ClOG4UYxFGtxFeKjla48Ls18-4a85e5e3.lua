-- One camera/gesture contract for the fishing observation window.
-- Keep the existing fish population and world positions; reveal more of them.
local Cast=require("Game.FishingCast")
local V={height=7.2,back=12,xLimit=220,yMin=-120,yMax=160,rodStep=.60}
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
-- A compact camera-relative rod keeps the raised tip inside portrait framing.
-- The real transformed tip is checked again after the segment bends, so narrow
-- screens do not depend on guessed Euler rotation or an unscaled model offset.
function V.RodSeat(aspect,lookY)
 local fov=V.Camera(0,0,aspect);local span=math.tan(fov*.5*rad)
 local lift=clamp(-(lookY or 0)/120,0,1)
 return span*aspect*.95*.70,-span*.95*.88,.95,.46*span/math.tan(40*rad),lift
end
local function ease(k)k=clamp(k,0,1);return k*k*k*(k*(k*6-15)+10)end
-- Anticipation, forward stroke and follow-through have separate durations.
-- The lure leaves during the stroke, while the rod continues settling.
function V.RodPose(aspect,lookY,stage,charge,elapsed)
 local x,y,z,size,lift=V.RodSeat(aspect,lookY)
 local c=clamp(charge or 0,0,1)
 local forward=-23-lift*2
 local raised=-30-lift*2-c*6;local right=24-c*2
 local held=stage=="idle"or stage=="aim"
 local pose={x=x,y=y,z=z,size=size,pitch=held and raised or forward,
  yaw=held and right or 2,roll=0,bend=.035+(held and c*.035 or 0)}
 if stage=="casting"then
  local t=elapsed or (Cast.windupSeconds+Cast.strokeSeconds+Cast.followSeconds)
  local back=ease(t/Cast.windupSeconds)
  local stroke=ease((t-Cast.windupSeconds)/Cast.strokeSeconds)
  local settle=ease((t-Cast.windupSeconds-Cast.strokeSeconds)/Cast.followSeconds)
  pose.pitch=raised-5*back+(forward+5-(raised-5))*stroke-5*settle
  pose.yaw=right+4*back+(-1-(right+4))*stroke+3*settle
  pose.roll=-3*back+6*stroke-3*settle
  pose.x=x+.04*(stroke-settle);pose.y=y+.03*back-.05*stroke+.02*settle
  pose.z=z+.05*(stroke-settle)
  pose.bend=.035+c*.035*(1-stroke)+math.sin(stroke*math.pi)*.055
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
-- Translation in the camera's local plane, derived from the actual tip. Keep
-- enough space around it for the guide dots and above the bottom controls.
function V.RodCorrection(x,y,z,aspect,height,top)
 if z<=.15 then return 0,0 end
 local fov=V.Camera(0,0,aspect);local halfY=z*math.tan(fov*.5*rad);local halfX=halfY*aspect
 local screenX=450*(.5+.5*x/halfX);local screenY=height*(.5-.5*y/halfY)
 local safeTop=math.min(top or 36,height-190)
 local safeX=clamp(screenX,24,414);local safeY=clamp(screenY,safeTop,math.max(safeTop,height-190))
 return (safeX-screenX)*2*halfX/450,-(safeY-screenY)*2*halfY/height
end
-- The crossing swell and slow envelope avoid a single repeating sine.
-- Shared heave lets the eye and held rod ride with the boat.
function V.Bob(heave,pitch,roll,t)
 local h=heave*(.30+.06*math.sin(t*.37))+.022*math.sin(t*.71)+.012*math.sin(t*1.13+.8)
 return h,pitch*.17,roll*.17
end
return V
