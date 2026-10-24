-- Approved nautical PNG skin. Uses the UI's existing image cache and NanoVG frame.
-- Source pixels are @2x; destination corners stay at their intended logical size.
local Cache=require("urhox-libs/UI/Core/ImageCache")
local Data=require("Game.UISkinData")
local S={data=Data}
local misses={}
local function image(path,expectedW,expectedH)
 local handle=Cache.Get(path)
 if handle<=0 then
  misses[path]=(misses[path]or 0)+1
  if misses[path]>=120 then Cache.Release(path);misses[path]=0 end
  return nil
 end
 local w,h=Cache.GetSize(path)
 if w~=expectedW or h~=expectedH then return nil end -- async DWP placeholder: paint vector fallback
 return handle,w,h
end
local function patch(v,handle,iw,ih,dx,dy,dw,dh,sx,sy,sw,sh,opacity)
 if dw<=0 or dh<=0 or sw<=0 or sh<=0 then return end
 local kx,ky=dw/sw,dh/sh
 nvgBeginPath(v);nvgRect(v,dx,dy,dw,dh)
 nvgFillPaint(v,nvgImagePattern(v,dx-sx*kx,dy-sy*ky,iw*kx,ih*ky,0,handle,opacity or 1));nvgFill(v)
end
-- Public for the adapter's geometry tests; no graphics state or allocation retained.
function S.Cuts(length,first,last,ratio)
 local a,b=first/ratio,last/ratio
 local scale=math.min(1,length/math.max(.001,a+b))
 return a*scale,b*scale
end
function S.Draw(v,id,x,y,w,h,variant,opacity,logicalScale)
 if w<=0 or h<=0 then return false end
 local family=Data.assets[id];local entry=family and(family[variant or "default"]or family.default)
 if not entry then return false end
 local handle,iw,ih=image(entry.file,entry.width,entry.height)
 if not handle then return false end
 -- PNG coverage already contains antialiasing. Geometry AA on adjacent cells
 -- exposes the backdrop as hairlines at their shared edges (especially @3x).
 nvgSave(v);nvgShapeAntiAlias(v,0)
 local slice=entry.slice
 if not slice then patch(v,handle,iw,ih,x,y,w,h,0,0,iw,ih,opacity);nvgRestore(v);return true end
 local ratio=entry.ratio/(logicalScale or 1)
 local dl,dr=S.Cuts(w,slice[1],slice[3],ratio)
 local dt,db=S.Cuts(h,slice[2],slice[4],ratio)
 local xs={0,slice[1],iw-slice[3],iw};local ys={0,slice[2],ih-slice[4],ih}
 local dx={x,x+dl,x+w-dr,x+w};local dy={y,y+dt,y+h-db,y+h}
 for row=1,3 do for col=1,3 do
  patch(v,handle,iw,ih,dx[col],dy[row],dx[col+1]-dx[col],dy[row+1]-dy[row],xs[col],ys[row],xs[col+1]-xs[col],ys[row+1]-ys[row],opacity)
 end end
 nvgRestore(v)
 return true
end
function S.Icon(v,name,x,y,size,opacity)
 local atlas=Data.atlas;local frame=atlas.frames[name]
 if not frame then return false end
 local handle,iw,ih=image(atlas.file,atlas.width,atlas.height)
 if not handle then return false end
 nvgSave(v);nvgShapeAntiAlias(v,0)
 patch(v,handle,iw,ih,x-size/2,y-size/2,size,size,frame.x,frame.y,frame.width,frame.height,opacity)
 nvgRestore(v)
 return true
end
function S.State(down,hover,disabled,selected)
 return disabled and "disabled"or down and "pressed"or selected and "selected"or hover and "hover"or "default"
end
function S.Button(v,x,y,w,h,tone,down,hover,disabled,family,selected,scale)
 family=family or(tone=="gold"and"BTN-primary"or h>60 and"BTN-nav"or math.abs(w-h)<8 and"BTN-square"or"BTN-secondary")
 return S.Draw(v,family,x,y,w,h,S.State(down,hover,disabled,selected),1,scale)
end
function S.Progress(v,x,y,w,h,value,color)
 if not S.Draw(v,"STA-bar",x,y,w,h)then return false end
 value=math.max(0,math.min(1,value))
 if value>0 then
  nvgSave(v);nvgIntersectScissor(v,x,y,w*value,h)
  S.Draw(v,"STA-bar",x,y,w,h,"fill-"..(color or"blue"))
  nvgRestore(v)
 end
 return true
end
function S.Quality(v,x,y,w,h,quality,selected)
 S.Draw(v,"STA-quality",x,y,w,h,({"default","blue","purple","orange"})[quality]or"default")
 if selected then S.Draw(v,"STA-quality",x,y,w,h,"selected")end
end
return S
