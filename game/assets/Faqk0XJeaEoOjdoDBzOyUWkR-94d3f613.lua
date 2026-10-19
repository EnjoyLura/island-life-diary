-- CPU and surface shader share these waves, so floats cannot sit below a swell.
local O={waves={{.25,.40,1.10,.32,0},{-.47,.22,1.55,.16,1.7},{.13,.17,.70,.10,.6}},
 warp={.082,.11,.085,.65}}
function O.Strength(mode)
 return mode=="home" and .17 or mode=="shore" and .12 or mode=="fishing" and 1 or .85
end
function O.Phase(x,z,t,w)
 local q=O.warp
 local bend=x*q[1]+z*q[2]-t*q[3]+w[5]
 return x*w[1]+z*w[2]-t*w[3]+w[5]+math.sin(bend)*q[4],math.cos(bend)*q[4]
end
function O.Height(x,z,t,strength)
 local height=0
 for _,w in ipairs(O.waves)do height=height+math.sin(O.Phase(x,z,t,w))*w[4]end
 return height*(strength or 1)
end
function O.Slope(x,z,t,strength)
 local dx,dz=0,0
 for _,w in ipairs(O.waves)do
  local phase,bend=O.Phase(x,z,t,w);local slope=math.cos(phase)*w[4]
  dx,dz=dx+slope*(w[1]+bend*O.warp[1]),dz+slope*(w[2]+bend*O.warp[2])
 end
 return dx*(strength or 1),dz*(strength or 1)
end
function O.At(x,z,t,mode)
 local k=O.Strength(mode);local dx,dz=O.Slope(x,z,t,k)
 return O.Height(x,z,t,k),dx,dz
end
function O.FloatPose(x,z,t,mode,yaw,length,width)
 local h=O.Height(x,z,t,O.Strength(mode))
 local dx,dz=O.Slope(x,z,t,O.Strength(mode))
 return h,-dz*25,dx*25
end
---@param material Material
function O.Bind(material)
 for i,w in ipairs(O.waves)do material:SetShaderParameter("wave_"..string.char(96+i),Variant(Vector4(w[1],w[2],w[3],w[4])))end
 local q=O.warp;material:SetShaderParameter("wave_warp",Variant(Vector4(q[1],q[2],q[3],q[4])))
end
-- One Cartesian grid with variable spacing, so coarse/fine boundaries share
-- every edge. It reaches the horizon without T-junctions or several water layers.
function O.GridAxis()
 local outer={72,96,132,180,260,380,540,720};local axis={}
 for i=#outer,1,-1 do axis[#axis+1]=-outer[i]end
 for i=-40,40 do axis[#axis+1]=i*1.5 end
 for _,x in ipairs(outer)do axis[#axis+1]=x end
 return axis
end
return O
