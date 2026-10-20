-- One camera/gesture contract for the fishing observation window.
-- Keep the existing fish population and world positions; reveal more of them.
local V={height=7.2,back=12,xLimit=220,yMin=-120,yMax=80}
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
return V
