-- One invertible map for the ground, shoreline, village anchors and camera.
-- Wide bays/headlands come from low frequencies, not a uniform circular rim.
local I={shape={.16,.4,.09,-1.1,.065,.7},basis={.98,.13,1.06},bed={.14,.12,.014,28}}
function I.Gain(angle)
 local s=I.shape
 return 1+s[1]*math.sin(2*angle+s[2])+s[3]*math.sin(3*angle+s[4])+s[5]*math.cos(5*angle+s[6])
end
function I.Map(x,z)
 if x==0 and z==0 then return 0,0 end
 local k=I.Gain(math.atan(z,x));local b=I.basis
 return (b[1]*x+b[2]*z)*k,b[3]*z*k
end
function I.Unmap(x,z)
 local b=I.basis
 z=z/b[3];x=(x-b[2]*z)/b[1]
 if x==0 and z==0 then return 0,0 end
 local k=I.Gain(math.atan(z,x))
 return x/k,z/k
end
function I.Depth(distance)
 local d=math.max(0,distance);local b=I.bed
 return math.min(b[4],b[1]+b[2]*d+b[3]*d*d)
end
return I
