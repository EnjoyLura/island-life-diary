-- Matching hand-drawn inventory silhouettes; drawn by existing UI widgets.
local A=require("Game.Art")
local F={}
function F.Draw(v,s,x,y,size,known)
 local c=known and s.color or {133,148,140,255}
 nvgSave(v);nvgTranslate(v,x,y);nvgScale(v,size/90,size/90)
 if s.shape=="mushroom"then
  A.rect(v,-6,-3,12,30,{237,215,165,255},4,A.ink,1.5)
  A.ellipse(v,0,-7,29,18,c,A.ink,2)
  A.ellipse(v,-10,-12,4,3,A.cream);A.ellipse(v,10,-5,5,3,A.cream)
 elseif s.shape=="berry"then
  A.line(v,{-13,17,2,-16,18,-22},A.ink,3)
  A.ellipse(v,-10,-13,15,5,{97,151,76,255});A.ellipse(v,17,-20,13,5,{119,165,78,255})
  for _,p in ipairs({{-11,0},{4,-5},{18,2},{0,12},{13,16}})do
   A.circle(v,p[1],p[2],8,c,A.ink,1.3);A.circle(v,p[1]-2,p[2]-3,2,A.cream)
  end
 elseif s.shape=="wood"then
  A.line(v,{-25,20,21,-19},c,14);A.line(v,{1,-1,0,-25},c,7)
  A.circle(v,-25,20,7,{220,187,134,255},A.ink,1.3)
 else
  A.line(v,{0,25,0,-24},A.ink,2)
  for k=1,3 do for side=-1,1,2 do
   local y=20-k*11
   A.poly(v,{0,y,side*22,y-15,side*24,y-4,side*10,y+3},c,A.ink,1)
  end end
  if s.quality>=3 then A.circle(v,0,-25,8,{239,197,88,255},A.ink,1)end
 end
 nvgRestore(v)
end
return F
