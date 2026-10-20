-- A short world-space history bends the foam behind turns; no wake simulation.
local W={}
function W.New()
 local trail={points={},free={},samples={},result={}}
 for i=1,36 do trail.free[i]={x=0,z=0}end
 for i=1,37 do trail.samples[i]={x=0,z=0}end
 return trail
end
-- The returned array is borrowed until the next Sample call. All coordinates
-- and ribbon vertices match the former allocating path; no update-rate cap.
function W.Sample(trail,x,z,heading,speed)
 local sx,sz=x-math.sin(heading)*1.9,z-math.cos(heading)*1.9
 local points=trail.points;local last=points[1]
 local d=last and math.sqrt((last.x-sx)^2+(last.z-sz)^2) or 0
 if d>12 then
  for i=#points,1,-1 do trail.free[#trail.free+1]=points[i];points[i]=nil end
  last=nil
 end
 if not last or d>.34 then
  local p=#points==36 and table.remove(points)or table.remove(trail.free)
  p.x,p.z=sx,sz;table.insert(points,1,p)
 end
 local result=trail.result;local first=trail.samples[1]
 first.x,first.z=sx,sz;result[1]=first
 local count=1;local length=0;local prev=first
 for _,p in ipairs(points)do
  local segment=math.sqrt((p.x-prev.x)^2+(p.z-prev.z)^2)
  if segment>.015 then
   length=length+segment
   if length>12 then break end
   count=count+1;local sample=trail.samples[count]
   sample.x,sample.z=p.x,p.z;result[count]=sample;prev=p
  end
 end
 if count<2 then
  count=2;local sample=trail.samples[2]
  sample.x,sample.z=sx-math.sin(heading)*.5,sz-math.cos(heading)*.5;result[2]=sample
 end
 for i=#result,count+1,-1 do result[i]=nil end
 return result,math.max(0,math.min(1,(speed-5)/65))
end

function W.Build(mesh,points,opacity)
 local g=mesh.geometry;g:BeginGeometry(0,TRIANGLE_LIST);mesh.count=0
 local length=0
 local function vertex(x,z,u,v,fade)
  g:DefineVertex(Vector3(x,0,z));g:DefineNormal(Vector3.UP)
  g:DefineTexCoord(Vector2(u,v));g:DefineColor(Color(1,1,1,fade*opacity))
 end
 for i=1,#points-1 do
  local a,b=points[i],points[i+1]
  local dx,dz=b.x-a.x,b.z-a.z;local d=math.sqrt(dx*dx+dz*dz)
  if d>.001 then
   local px,pz=-dz/d,dx/d;local endLength=length+d
   -- Two thin diverging ribbons and a restrained central propeller trail.
   for side=-1,1 do
    local w0,w1=.45+length*.14,.45+endLength*.14
    local r0,r1=side==0 and .13+length*.025 or .12,side==0 and .13+endLength*.025 or .12
    local a0,a1,b0,b1=side*w0-r0,side*w0+r0,side*w1-r1,side*w1+r1
    local fade0,fade1=math.max(0,1-length/12),math.max(0,1-endLength/12)
    local v0,v1=length/12,endLength/12
    vertex(a.x+px*a0,a.z+pz*a0,0,v0,fade0)
    vertex(b.x+px*b1,b.z+pz*b1,1,v1,fade1)
    vertex(b.x+px*b0,b.z+pz*b0,0,v1,fade1)
    vertex(a.x+px*a0,a.z+pz*a0,0,v0,fade0)
    vertex(a.x+px*a1,a.z+pz*a1,1,v0,fade0)
    vertex(b.x+px*b1,b.z+pz*b1,1,v1,fade1)
    mesh.count=mesh.count+2
   end
   length=endLength
  end
 end
 g:Commit()
end
return W
