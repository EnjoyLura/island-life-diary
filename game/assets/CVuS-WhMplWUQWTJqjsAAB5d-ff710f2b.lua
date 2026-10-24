-- Model nose is +Z. Heading comes from the derivative of the SAME patrol,
-- in logical sea coordinates (+Y is south), never from the animation clock.
local P={}
function P.Sample(shark,phase)
 local dx=shark.rx*math.cos(phase)*shark.rate
 local dy=-shark.ry*math.sin(phase)*shark.rate
 return shark.cx+shark.rx*math.sin(phase),shark.cy+shark.ry*math.cos(phase),math.atan(dx,-dy)
end
function P.New(cx,cy,rx,ry,phase,rate)
 local s={cx=cx,cy=cy,rx=rx,ry=ry,phase=phase,rate=rate,cooldown=0}
 s.x,s.y,s.heading=P.Sample(s,phase)
 return s
end
function P.Step(shark,dt)
 shark.phase=shark.phase+dt*shark.rate
 shark.x,shark.y,shark.heading=P.Sample(shark,shark.phase)
 shark.cooldown=math.max(0,shark.cooldown-dt)
end
return P
