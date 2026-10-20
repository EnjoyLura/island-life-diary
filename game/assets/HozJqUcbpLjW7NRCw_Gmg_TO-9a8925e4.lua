-- Species geometry in metres, +Z nose, -Z tail. All fins are part of the same
-- deformable mesh, so rear-body motion stays continuous into the caudal fin.
local Mesh=require("Game.Mesh")
local Catalog=require("Game.Catalog")
local F={}
local pi,sin,cos=math.pi,math.sin,math.cos
local function v(x,y,z)return Vector3(x,y,z)end
function F.Dimensions(species)
 local shape=species.shape
 local wide,tall,length=.16,.26,1.15
 if shape=="slender" or shape=="small" then wide,tall,length=.12,.15,1.28
 elseif shape=="bass" then wide,tall,length=.18,.23,1.50
 elseif shape=="grouper" then wide,tall,length=.23,.27,1.36
 elseif shape=="flat" then wide,tall,length=.085,.39,.96
 elseif shape=="tuna" or shape=="long" then wide,tall,length=.22,.27,1.65
 elseif shape=="ribbon" then wide,tall,length=.07,.14,2.25 end
 if shape=="small" then length=length*.72;wide=wide*.75;tall=tall*.75 end
 return wide,tall,length
end
function F.Nose(species)local _,_,length=F.Dimensions(species);return length*.56 end
function F.Build(s,parent,name,species,index)
 species=species or Catalog.fish[(index-1)%#Catalog.fish+1]
 local speciesIndex=1
 for i,entry in ipairs(Catalog.fish)do if entry.id==species.id then speciesIndex=i;break end end
 -- Packed vertex colours are RGBA8: keep species and slot in separate nibbles.
 local phase=(speciesIndex*16+math.max(1,math.min(15,index or 1)))/255
 local function c(rgb)return {rgb[1],rgb[2],rgb[3],phase}end
 local color=species.color
 local back=c({color[1]/255*.72,color[2]/255*.82,color[3]/255*.88})
 local side=c({color[1]/255,color[2]/255,color[3]/255})
 local belly=c({.85,.90,.85})
 local fin=c(species.id=="yellowfin_bream" and {.92,.73,.20} or {.24,.43,.47})
 local dark=c({.035,.10,.13});local rim=c({.70,.73,.51})
 local shape=species.shape
 local wide,tall,length=F.Dimensions(species)
 local root=parent:CreateChild(name)
 local m=Mesh.new(root,"Species_"..species.id,s.fishMat)
 local sections={{-.58,.04},{-.47,.20},{-.30,.60},{-.08,.93},{.15,1},{.34,.82},{.46,.52},{.53,.30},{.56,.03}}
 for j=1,#sections-1 do for i=0,19 do
  local a,b=i*pi/10,(i+1)*pi/10;local l,r=sections[j],sections[j+1]
  local function point(sec,angle)return v(cos(angle)*wide*sec[2],sin(angle)*tall*sec[2],sec[1]*length)end
  local function normal(sec,angle)return v(cos(angle)/wide,sin(angle)/tall,sec[1]*1.7):Normalized()end
  local shade=sin((a+b)*.5)>.40 and back or sin((a+b)*.5)<-.25 and belly or side
  m:smoothTri(point(l,a),point(r,b),point(r,a),normal(l,a),normal(r,b),normal(r,a),shade)
  m:smoothTri(point(l,a),point(l,b),point(r,b),normal(l,a),normal(l,b),normal(r,b),shade)
 end end
 -- Vertical tail and paired pectoral/pelvic fins: distinct readable anatomy.
 local stock=-.56*length;local tailEnd=stock-.32*length
 for _,sign in ipairs({-1,1})do
  m:tri(v(0,0,stock),v(0,sign*tall*1.2,tailEnd),v(0,sign*tall*.46,tailEnd+.07),fin)
  m:tri(v(0,0,stock),v(0,sign*tall*.46,tailEnd+.07),v(0,0,tailEnd+.14),side)
  m:tri(v(sign*wide*.7,-.01,.20*length),v(sign*(wide+.22),-.08,-.08*length),v(sign*wide*.7,-.06,-.12*length),fin)
  m:tri(v(sign*wide*.45,-tall*.65,-.03),v(sign*wide*.9,-tall*1.15,-.25),v(0,-tall*.7,-.20),fin)
  local eyeX=wide*.67;local eyeZ=.44*length
  m:ellipsoid(sign*eyeX,tall*.21,eyeZ,.026,.030,.030,rim,10,6)
  m:ellipsoid(sign*(eyeX+.020),tall*.21,eyeZ+.006,.014,.021,.021,dark,10,6)
  m:ellipsoid(sign*(eyeX+.028),tall*.24,eyeZ+.013,.005,.006,.006,c({1,1,.94}),6,4)
  m:tube(v(sign*wide*.91,tall*.15,.30*length),v(sign*wide*.83,-tall*.45,.24*length),.006,.005,fin,6)
 end
 local dorsal=shape=="bream" or shape=="grouper" or shape=="spiny"
 if dorsal then
  for i=0,8 do local z=.26*length-i*.055*length
   m:tri(v(0,tall*.80,z+.03),v(0,tall*(1.45-i*.035),z),v(0,tall*.80,z-.06),fin)
  end
 else m:tri(v(0,tall*.8,.10),v(0,tall*1.6,-.12),v(0,tall*.65,-.32),fin)end
 -- A dark mouth slit shares the body buffer; the bite shader opens its lower lip.
 m:ellipsoid(0,-tall*.07,.545*length,wide*.23,tall*.075,.028,dark,8,4)
 m:finish();m.geometry.castShadows=false
 return root
end
return F
