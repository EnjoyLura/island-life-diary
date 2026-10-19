-- One village/harbour layout for the original island and its sea-map position.
local Shape=require("Game.IslandShape")
local L={buildings={{cell=1,x=1.1,z=1.1,size=9},{cell=2,x=-7,z=-8.6,size=7.1},
 {cell=1,x=-12.4,z=-3.2,size=5.5},{cell=3,x=-17.2,z=14,size=7.6},
 {cell=4,x=8.6,z=-8.6,size=7}}}
function L.Harbour()
 local x,z=Shape.Map(9,-19);local xx,zz=Shape.Map(9,-20)
 local yaw=math.atan(x-xx,z-zz)
 return x,z,yaw,x-math.sin(yaw)*8.16,z-math.cos(yaw)*8.16
end
return L
