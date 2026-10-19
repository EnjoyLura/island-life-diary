-- Nautical cel-shaded drawing primitives. Used inside UI.Widget:Render only.
local UI = require("urhox-libs/UI")
local A = {}
A.ink = {20,40,65,255}
A.cream = {255,247,218,255}
A.teal = {24,143,161,255}
A.gold = {255,193,65,255}
A.quality = {{78,179,116,255},{70,145,222,255},{166,103,213,255},{244,162,53,255}}
A.qualityNames = {"普通","稀有","史诗","传说"}
function A.color(c,alpha) return nvgRGBA(c[1],c[2],c[3],alpha or c[4] or 255) end
function A.rect(v,x,y,w,h,c,r)
 nvgBeginPath(v);nvgRoundedRect(v,x,y,w,h,r or 0);nvgFillColor(v,A.color(c));nvgFill(v)
end
function A.line(v,points,c,width,closed)
 nvgBeginPath(v);nvgMoveTo(v,points[1],points[2])
 for i=3,#points,2 do nvgLineTo(v,points[i],points[i+1]) end
 if closed then nvgClosePath(v) end
 nvgStrokeColor(v,A.color(c));nvgStrokeWidth(v,width or 2);nvgStroke(v)
end
function A.poly(v,p,c,stroke,width)
 nvgBeginPath(v);nvgMoveTo(v,p[1],p[2]);for i=3,#p,2 do nvgLineTo(v,p[i],p[i+1]) end;nvgClosePath(v)
 nvgFillColor(v,A.color(c));nvgFill(v)
 if stroke then nvgStrokeColor(v,A.color(stroke));nvgStrokeWidth(v,width or 2);nvgStroke(v) end
end
function A.circle(v,x,y,r,c,stroke,width)
 nvgBeginPath(v);nvgCircle(v,x,y,r);nvgFillColor(v,A.color(c));nvgFill(v)
 if stroke then nvgStrokeColor(v,A.color(stroke));nvgStrokeWidth(v,width or 2);nvgStroke(v) end
end
function A.ellipse(v,x,y,rx,ry,c,stroke,width)
 nvgBeginPath(v);nvgEllipse(v,x,y,rx,ry);nvgFillColor(v,A.color(c));nvgFill(v)
 if stroke then nvgStrokeColor(v,A.color(stroke));nvgStrokeWidth(v,width or 2);nvgStroke(v) end
end
function A.text(v,x,y,t,size,c,align,bold)
 nvgFontFace(v,UI.Theme.FontFace("sans",bold==false and "normal" or "bold"))
 nvgFontSize(v,size or 16);nvgTextAlign(v,(align or NVG_ALIGN_LEFT)+NVG_ALIGN_MIDDLE)
 nvgFillColor(v,A.color(c or A.ink));nvgText(v,x,y,tostring(t))
end
function A.plate(v,x,y,w,h,tone,pressed)
 local top,bottom={255,251,231,255},{237,221,176,255}
 if tone=="gold" then top,bottom={255,221,106,255},{242,163,40,255}
 elseif tone=="blue" then top,bottom={65,184,211,255},{32,126,165,255}
 elseif tone=="green" then top,bottom={105,205,137,255},{39,151,105,255}
 elseif tone=="dark" then top,bottom={38,67,88,245},{23,43,66,245}
 elseif tone=="danger" then top,bottom={255,143,106,255},{211,83,66,255} end
 local off=pressed and 1 or 4
 A.rect(v,x,y+off,w,h,A.ink,8)
 nvgBeginPath(v);nvgRoundedRect(v,x,y,w,h-2,8)
 nvgFillPaint(v,nvgLinearGradient(v,x,y,x,y+h,A.color(top),A.color(bottom)));nvgFill(v)
 nvgStrokeColor(v,A.color(A.ink));nvgStrokeWidth(v,2.5);nvgStroke(v)
 A.line(v,{x+10,y+4,x+w-10,y+4},{255,255,246,180},1.5)
 if w>80 and h>35 then
  for _,p in ipairs({{x+6,y+7},{x+w-6,y+7},{x+6,y+h-10},{x+w-6,y+h-10}}) do A.circle(v,p[1],p[2],1.4,{159,129,75,255}) end
 end
end
function A.bar(v,x,y,w,h,value,c)
 A.rect(v,x,y,w,h,{20,44,61,240},h/2)
 A.rect(v,x+2,y+2,math.max(0,(w-4)*math.max(0,math.min(1,value))),h-4,c,h/2)
 A.line(v,{x+7,y+4,x+math.max(7,(w-10)*math.max(0,math.min(1,value))),y+4},{255,255,255,95},1.5)
end
function A.icon(v,name,x,y,size,c)
 c=c or A.ink
 nvgSave(v);nvgTranslate(v,x,y);nvgScale(v,size/32,size/32)
 local gold={251,187,50,255};local blue={89,177,215,255};local white={255,251,226,255};local brown={165,102,50,255}
 if name=="coin" then
  A.circle(v,0,0,14,{211,135,32,255},A.ink,1.5);A.circle(v,-1,-1,11,gold,{255,233,129,255},2)
  A.poly(v,{0,-9,3,-3,9,-3,4,2,6,9,0,5,-6,9,-4,2,-9,-3,-3,-3}, {255,223,104,255},{192,124,27,255},1)
 elseif name=="energy" then
  A.poly(v,{-2,-16,11,-16,4,-3,13,-3,-6,17,-2,3,-12,3},gold,A.ink,2)
 elseif name=="bread" then
  A.ellipse(v,0,2,15,10,{188,100,42,255},A.ink,1.5);A.ellipse(v,-1,-1,14,10,{242,169,74,255})
  A.line(v,{-8,-6,-3,-2},{255,231,162,255},2);A.line(v,{-2,-8,3,-4},{255,231,162,255},2);A.line(v,{4,-7,9,-3},{255,231,162,255},2)
 elseif name=="book" then
  A.poly(v,{-15,-12,-2,-13,0,-10,3,-13,15,-11,14,13,1,11,-14,13},white,A.ink,2)
  A.line(v,{0,-10,0,11},brown,2);A.ellipse(v,6,0,5,3,blue);A.poly(v,{10,0,14,-4,14,4},blue,A.ink,1)
  A.line(v,{-11,-5,-4,-6},brown,1);A.line(v,{-11,0,-4,-1},brown,1);A.line(v,{-11,5,-4,4},brown,1)
 elseif name=="bag" or name=="bucket" then
  A.poly(v,{-13,-9,13,-9,10,14,-10,14},name=="bag" and brown or blue,A.ink,2)
  A.line(v,{-9,-7,-7,-16,7,-16,9,-7},A.ink,2);A.rect(v,-5,-4,10,7,gold,1)
 elseif name=="fish" then
  A.ellipse(v,-3,0,12,8,blue,A.ink,2);A.poly(v,{7,0,15,-8,15,8},blue,A.ink,2);A.circle(v,-9,-2,1.5,A.ink)
 elseif name=="back" then
  A.poly(v,{-15,0,0,-13,0,-6,14,-6,14,7,0,7,0,13},white,A.ink,2)
 elseif name=="home" then
  A.poly(v,{-12,-1,-12,13,12,13,12,-1},white,A.ink,2);A.poly(v,{-17,-1,0,-16,17,-1},gold,A.ink,2);A.rect(v,-3,3,6,10,brown,1)
 elseif name=="anchor" then
  A.circle(v,0,-11,4,white,A.ink,2);A.line(v,{0,-7,0,13,-10,8,-14,2},c,3);A.line(v,{0,13,10,8,14,2},c,3);A.line(v,{-7,-2,7,-2},c,3)
 elseif name=="compass" then
  A.circle(v,0,0,14,white,A.ink,2);A.poly(v,{-6,10,0,-12,7,8,0,4},gold,A.ink,1.5)
 elseif name=="gear" then
  for i=0,7 do local a=i*math.pi/4;A.circle(v,math.cos(a)*10,math.sin(a)*10,4,c) end
  A.circle(v,0,0,11,c);A.circle(v,0,0,5,white)
 elseif name=="lock" then
  A.line(v,{-7,-1,-7,-9,-3,-13,3,-13,7,-9,7,-1},c,3);A.rect(v,-11,-2,22,17,gold,3);A.circle(v,0,5,2,c);A.rect(v,-1,5,2,5,c)
 elseif name=="fuel" then
  A.rect(v,-10,-12,16,25,gold,2);A.rect(v,-7,-9,10,7,white,1);A.line(v,{6,-5,12,-2,12,10,16,10,16,-8,12,-12},c,2)
 elseif name=="hull" then
  A.poly(v,{-15,-4,15,-4,9,11,-8,11},brown,A.ink,2);A.line(v,{-5,-5,-5,-13,7,-13,7,-5},c,2);A.line(v,{-17,14,-7,16,2,14,12,16,18,14},blue,2)
 elseif name=="salt" then
  A.rect(v,-10,-12,20,25,white,3);A.rect(v,-10,-16,20,6,blue,2);A.text(v,0,2,"盐",13,A.ink,NVG_ALIGN_CENTER)
 elseif name=="shovel" then
  A.line(v,{-8,-16,-8,-9,-3,-4,3,-8,3,-16,-8,-16},brown,3);A.line(v,{-3,-6,5,7},brown,4);A.poly(v,{0,5,13,3,15,13,8,18,0,12},blue,A.ink,2)
 elseif name=="video" then
  A.rect(v,-14,-10,28,21,c,4);A.poly(v,{-4,-6,7,1,-4,7},white)
 elseif name=="plus" then A.line(v,{-9,0,9,0},c,3);A.line(v,{0,-9,0,9},c,3)
 elseif name=="minus" then A.line(v,{-9,0,9,0},c,3)
 elseif name=="close" then A.line(v,{-8,-8,8,8},c,3);A.line(v,{8,-8,-8,8},c,3)
 elseif name=="check" then A.line(v,{-11,0,-3,8,12,-9},c,4)
 elseif name=="rod" then
  A.line(v,{-13,14,9,-13},brown,4);A.line(v,{9,-13,14,-8,14,11,9,14,5,11},c,1.5);A.circle(v,-5,6,4,gold,A.ink,1.5)
 elseif name=="chest" then
  A.rect(v,-14,-5,28,20,brown,3);A.rect(v,-14,-13,28,14,gold,4);A.rect(v,-3,-2,6,8,white,1)
 elseif name=="shell" then
  A.poly(v,{0,13,-14,1,-12,-10,-3,-15,8,-14,15,-4,13,4},white,A.ink,2)
  for i=-2,2 do A.line(v,{0,11,i*5,-8},brown,1) end
 elseif name=="boat" then
  A.poly(v,{0,-17,12,-6,10,13,0,17,-10,13,-12,-6},brown,A.ink,2);A.line(v,{-8,-1,8,-1},gold,4);A.rect(v,-5,7,10,5,blue,1)
 end
 nvgRestore(v)
end
return A
