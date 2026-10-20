-- Rock clusters and their water-contact contours share one authored mesh.
-- The offline coast-data bake imports this pure layout; it never guesses circles.
local R={}
local sin,cos,pi=math.sin,math.cos,math.pi
local profile={{0,.70},{.16,1},{.48,.90},{.74,.72},{.91,.49},{1,.25}}

function R.Layout(reefs)
 local out={}
 for i,reef in ipairs(reefs)do
  local x,z,r=(reef.x-1000)*.04,-(reef.y-1200)*.04,reef.radius*.04
  local yaw=i*1.73;local co,si=cos(yaw),sin(yaw)
  local function add(ox,oz,rx,rz,bottom,height,seed)
   out[#out+1]={x=x+(ox*co-oz*si)*r,z=z+(ox*si+oz*co)*r,
    rx=rx*r,rz=rz*r,bottom=bottom,height=height,yaw=yaw+seed*.61,seed=seed}
  end
  add(.08,.08,.53,.42,-2.1,4.6+i%3*.28,i*17)
  add(-.42,.24,.36,.42,-1.8,3.7+i%2*.36,i*17+1)
  add(.49,-.24,.30,.25,-1.6,2.8,i*17+2)
  add(-.19,-.49,.25,.25,-1.7,2.4,i*17+3)
  -- Asymmetric submerged shelves, rather than a turquoise spotlight disc.
  for j=1,8 do
   local a=j*2.399+i*.4;local d=.74+(j%3)*.31
   add(cos(a)*d,sin(a)*d,.25+j%3*.08,.18+j%2*.09,
    -3.9-j%3*.38,2.5+j%2*.30,i*17+3+j)
  end
 end
 return out
end

-- Plain coordinate tables make geometry available to both Lua and the data baker.
function R.Rings(rock)
 local rings={};local n=10;local co,si=cos(rock.yaw),sin(rock.yaw)
 for row,p in ipairs(profile)do
  local ring={}
  for j=0,n-1 do
   local a=j*2*pi/n
   local jag=1+.12*sin(j*2.71+rock.seed)+.055*cos(j*4.12+rock.seed*.43)
   local lean=p[1]*.14
   local xx=(cos(a)*p[2]*jag+lean)*rock.rx
   local zz=(sin(a)*p[2]*jag-lean*.4)*rock.rz
   local yy=rock.bottom+rock.height*(p[1]+(row>2 and .026*sin(j*1.83+rock.seed) or 0))
   ring[#ring+1]={x=rock.x+xx*co-zz*si,y=yy,z=rock.z+xx*si+zz*co}
  end
  rings[#rings+1]=ring
 end
 return rings
end

function R.Triangles(rock)
 local rings=R.Rings(rock);local triangles={}
 local function tri(a,b,c)triangles[#triangles+1]={a,b,c}end
 for row=1,#rings-1 do for j=1,#rings[row]do
  local nextj=j%#rings[row]+1
  local a,b,c,d=rings[row][j],rings[row+1][j],rings[row+1][nextj],rings[row][nextj]
  tri(a,b,c);tri(a,c,d)
 end end
 local top={x=rock.x+cos(rock.yaw)*rock.rx*.14,y=rock.bottom+rock.height*1.035,z=rock.z+sin(rock.yaw)*rock.rx*.14}
 local bottom={x=rock.x,y=rock.bottom,z=rock.z}
 for j=1,#rings[1]do
  local nextj=j%#rings[1]+1
  tri(top,rings[#rings][nextj],rings[#rings][j])
  tri(bottom,rings[1][j],rings[1][nextj])
 end
 return triangles
end

function R.Build(parent,name,material,layout)
 local mesh=require("Game.Mesh").new(parent,name,material)
 mesh.geometry.castShadows=false
 for _,rock in ipairs(layout)do
  local tint=.94+(rock.seed%4)*.025
  for _,triangle in ipairs(R.Triangles(rock))do
   local a,b,c=table.unpack(triangle)
   mesh:tri(Vector3(a.x,a.y,a.z),Vector3(b.x,b.y,b.z),Vector3(c.x,c.y,c.z),{tint,tint,tint,1})
  end
 end
 mesh:finish();return mesh
end

function R.HomeLayout()
 local _,underwater=require("Game.CoastalShelf").Rocks()
 return underwater
end

-- These triangulated banks are also rasterized into ReefData.B offline.
-- Water transparency therefore follows the actual submerged sand/rock height,
-- rather than a pale distance halo around each reef.
function R.BankTriangles(reefs)
 local out={};local rings={{0,1.2},{.55,1.6},{1.05,2.8},{1.5,5.4},{2.1,12},{3,28}}
 for i,reef in ipairs(reefs)do
  local x,z,r=(reef.x-1000)*.04,-(reef.y-1200)*.04,reef.radius*.04
  local rows={}
  for k,row in ipairs(rings)do
   rows[k]={}
   for j=0,23 do
    local a=j*2*pi/24
    local edge=1+.11*sin(a*3+i*.9)+.07*cos(a*5-i)
    rows[k][j+1]={x=x+cos(a)*row[1]*r*edge,z=z+sin(a)*row[1]*r*edge*.84,
     y=-row[2]-(k<5 and .16*sin(a*2+i) or 0)}
   end
  end
  local centre={x=x,y=-1.2,z=z}
  for k=2,#rows do for j=1,24 do local nextj=j%24+1
   local a,b,c,d=rows[k-1][j],rows[k-1][nextj],rows[k][nextj],rows[k][j]
   if k==2 then out[#out+1]={centre,c,d}
   else out[#out+1]={a,b,c};out[#out+1]={a,c,d}end
  end end
 end
 return out
end
function R.BuildBanks(parent,material,reefs)
 local mesh=require("Game.Mesh").new(parent,"SubmergedReefSandBanks",material)
 mesh.geometry.castShadows=false
 for _,t in ipairs(R.BankTriangles(reefs))do
  local a,b,c=table.unpack(t)
  mesh:tri(Vector3(a.x,a.y,a.z),Vector3(b.x,b.y,b.z),Vector3(c.x,c.y,c.z),{1,1,1})
 end
 mesh:finish();return mesh
end
return R
