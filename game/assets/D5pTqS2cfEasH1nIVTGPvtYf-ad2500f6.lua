-- One camera/gesture contract for the fishing observation window.
-- Keep the existing fish population and world positions; reveal more of them.
local V={height=7.2,back=12,xLimit=220,yMin=-120,yMax=160}
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
-- A camera-relative reel seat: the rear grip continues below the screen, while
-- the tip stays ahead of the eye. FOV/aspect compensation keeps portrait poses
-- consistent without a second camera or another rendering pass.
function V.RodSeat(aspect,lookY)
 local fov=V.Camera(0,0,aspect);local span=math.tan(fov*.5*rad)
 local lift=clamp(-(lookY or 0)/120,0,1)
 return span*aspect*.8*.86,-span*.8*.92+.28*lift,.8,.52*span/math.tan(40*rad),lift
end
-- A held rod rests in the upper right. The cast's brief forward stroke ends
-- in the existing water-facing pose, which also defines the release preview.
function V.RodPose(aspect,lookY,stage,charge,flick)
 local x,y,z,size,lift=V.RodSeat(aspect,lookY)
 local held=stage=="idle"or stage=="aim"
 local k=stage=="casting"and clamp(flick or 1,0,1)or 1;k=k*k*(3-2*k)
 local rest=held and 1 or stage=="casting"and 1-k or 0
 local c=clamp(charge or 0,0,1)
 return {x=x,y=y,z=z,size=size,pitch=-20-lift*10+rest*(-26-c*14),
  yaw=-20+rest*(40-c*4),bend=.035+rest*c*.035}
end
function V.RodTip(bend)return 0,-bend*81*.025,6.48 end
-- The crossing swell and slow envelope avoid a single repeating sine.
-- Shared heave lets the eye and held rod ride with the boat.
function V.Bob(heave,pitch,roll,t)
 local h=heave*(.30+.06*math.sin(t*.37))+.022*math.sin(t*.71)+.012*math.sin(t*1.13+.8)
 return h,pitch*.17,roll*.17
end
return V
