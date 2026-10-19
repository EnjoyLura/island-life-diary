-- Three gentle Gerstner waves. CPU inversion and GPU deformation share data.
local O={waves={{.19,.26,1.07,.34,0},{-.32,.18,1.22,.15,1.7},{.12,-.17,.81,.10,.6}},steepness=.38}
local Field=require("Game.OceanField")
function O.Strength(mode)
 return mode=="home" and .17 or mode=="shore" and .12 or mode=="fishing" and 1 or .85
end
-- Surface parameter -> actual horizontal position, height and Jacobian.
function O.Surface(x,z,t,strength)
 local px,pz,h,xx,xz,zz,hx,hz=x,z,0.0,1.0,0.0,1.0,0.0,0.0
 for _,w in ipairs(O.waves)do
  local k=math.sqrt(w[1]*w[1]+w[2]*w[2]);local dx,dz=w[1]/k,w[2]/k
  local phase=x*w[1]+z*w[2]-t*w[3]+w[5]
  local a=w[4]*(strength or 1);local s,c=math.sin(phase),math.cos(phase)
  px,pz,h=px+O.steepness*a*dx*c,pz+O.steepness*a*dz*c,h+a*s
  local q=O.steepness*a*k*s
  xx,xz,zz=xx-q*dx*dx,xz-q*dx*dz,zz-q*dz*dz
  hx,hz=hx+a*w[1]*c,hz+a*w[2]*c
 end
 return px,pz,h,xx,xz,zz,hx,hz
end
function O.Sample(x,z,t,strength)
 local u,v=x,z
 -- Contraction < .08 for these coefficients. Four iterations are sub-mm.
 for _=1,4 do local xx,zz=O.Surface(u,v,t,strength);u,v=u+x-xx,v+z-zz end
 local _,_,h,xx,xz,zz,hx,hz=O.Surface(u,v,t,strength)
 local det=xx*zz-xz*xz
 return h,(hx*zz-hz*xz)/det,(hz*xx-hx*xz)/det
end
function O.Height(x,z,t,strength)local h=O.Sample(x,z,t,strength);return h end
function O.Slope(x,z,t,strength)local _,dx,dz=O.Sample(x,z,t,strength);return dx,dz end
function O.At(x,z,t,mode)
 return O.Sample(x,z,t,O.Strength(mode)*Field.Damping(x,z,mode))
end
function O.FloatPose(x,z,t,mode,yaw,length,width)
 local dx,dz=math.sin(yaw),math.cos(yaw)
 local h=O.At(x,z,t,mode)
 local bow=O.At(x+dx*length*.5,z+dz*length*.5,t,mode)
 local stern=O.At(x-dx*length*.5,z-dz*length*.5,t,mode)
 local right=O.At(x+dz*width*.5,z-dx*width*.5,t,mode)
 local left=O.At(x-dz*width*.5,z+dx*width*.5,t,mode)
 return h,-math.atan((bow-stern)/length)*180/math.pi,math.atan((right-left)/width)*180/math.pi
end
---@param material Material
function O.Bind(material)
 for i,w in ipairs(O.waves)do material:SetShaderParameter("wave_"..string.char(96+i),Variant(Vector4(w[1],w[2],w[3],w[4])))end
 material:SetShaderParameter("wave_steepness",Variant(O.steepness))
end
function O.GridAxis()
 local outer={96,120,160,220,320,460,600,720};local axis={}
 for i=#outer,1,-1 do axis[#axis+1]=-outer[i]end
 for i=-40,40 do axis[#axis+1]=i*2 end
 for _,x in ipairs(outer)do axis[#axis+1]=x end
 return axis
end
return O
