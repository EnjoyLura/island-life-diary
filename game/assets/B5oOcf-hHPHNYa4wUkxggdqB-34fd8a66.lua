-- V46: map coordinates follow the ORIGINAL 910x1728 transparent image.
-- No old image, water rectangle, or resampled version is used.
local D={width=1600,height=1600*1728/910,
 image="image/HomeIslandV46/island.png",treesImage="image/HomeIslandV46/trees.png",
 waterImage="image/HomeIslandV46/water.png"}
-- Ground coastline, excluding the overhanging roofs, piers and fishing boat.
-- The island sprite covers the inside of this contour; water extends indefinitely.
local outline={
 {.45,.055},{.51,.052},{.58,.095},{.63,.12},{.71,.145},{.77,.19},
 {.81,.22},{.85,.195},{.88,.225},{.94,.255},{.96,.30},{.94,.33},
 {.965,.375},{.94,.42},{.89,.45},{.90,.49},{.89,.53},{.86,.555},
 {.84,.60},{.86,.63},{.86,.67},{.81,.715},{.78,.75},{.745,.785},
 {.715,.815},{.68,.835},{.62,.845},{.57,.855},{.51,.845},{.46,.835},
 {.40,.81},{.35,.80},{.30,.76},{.30,.73},{.25,.70},{.225,.665},
 {.21,.63},{.18,.61},{.115,.595},{.08,.59},{.065,.56},{.09,.53},
 {.16,.505},{.16,.48},{.195,.455},{.21,.42},{.225,.39},{.195,.36},
 {.15,.345},{.12,.325},{.13,.30},{.105,.275},{.115,.25},{.16,.23},
 {.19,.20},{.22,.16},{.27,.125},{.33,.11},{.38,.075}}
D.coast={}
for i,p in ipairs(outline)do D.coast[i]={x=p[1]*D.width,y=p[2]*D.height}end
function D.Distance(x,y)
 local best=math.huge
 for i,a in ipairs(D.coast)do
  local b=D.coast[i%#D.coast+1];local dx,dy=b.x-a.x,b.y-a.y
  local t=math.max(0,math.min(1,((x-a.x)*dx+(y-a.y)*dy)/(dx*dx+dy*dy)))
  local ex,ey=x-a.x-t*dx,y-a.y-t*dy;best=math.min(best,ex*ex+ey*ey)
 end
 return math.sqrt(best)
end
-- Independent trees on forest/lawn patches. Base position, size and species.
-- Avoid entrances, roofs, paths and the beach. Sorted once, never per frame.
local positions={
 {.39,.116,135,3},{.45,.145,120,1},{.60,.162,126,3},{.66,.19,112,1},
 {.28,.183,125,1},{.25,.214,120,3},{.37,.235,98,1},{.46,.225,135,3},
 {.64,.255,110,1},{.69,.28,118,2},{.24,.29,108,1},{.39,.285,103,4},
 {.31,.319,110,1},{.50,.305,94,3},{.58,.32,104,1},{.30,.36,112,2},
 {.23,.38,108,2},{.62,.345,95,1},{.65,.382,108,2},{.69,.405,88,1},
 {.265,.44,95,2},{.40,.449,88,4},{.58,.454,100,2},{.76,.454,116,2},
 {.79,.494,108,2},{.385,.51,86,4},{.53,.53,94,2},{.17,.548,115,2},
 {.38,.574,86,4},{.65,.59,100,2},{.745,.618,104,2},{.31,.631,106,2},
 {.45,.641,90,4},{.20,.624,88,1},{.59,.689,88,2},{.73,.696,98,2},
 {.435,.735,110,2},{.64,.734,106,2},{.46,.78,98,2},{.61,.795,93,2}}
D.trees={}
for i,p in ipairs(positions)do D.trees[i]={x=p[1]*D.width,y=p[2]*D.height,size=p[3],kind=p[4],phase=i*2.399,mirror=i%3==0}end
table.sort(D.trees,function(a,b)return a.y<b.y end)
return D
