"""Bake the supplied front-facing eagle using a weighted triangle mesh.

This is deterministic deformation of the original artwork, not generated poses.
Requires Python 3, Pillow and NumPy. Does not load or modify the game.
"""
from __future__ import annotations

import argparse
import base64
import json
import math
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw


FRAME_COUNT = 16
FPS = 20
SIZE = 512
TAU = 2 * math.pi


def smooth(a, b, value):
    t = np.clip((value - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def cutout(image):
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # Green-screen extraction is only authoring; exported frames have real alpha.
    alpha = np.clip((50 - (g - np.maximum(r, b))) / 40, 0, 1)
    rgb[..., 1] = np.minimum(g, np.maximum(r, b) * .95 + 5)
    rgb[alpha == 0] = 0
    return np.dstack((rgb / 255, alpha)).astype(np.float32)


def deform(points, phase, part="body"):
    x, y = points[..., 0], points[..., 1]
    radius = np.abs(x - 768)
    px, py = x.copy(), y.copy()
    # The second harmonic varies stroke speed; tune its sign for stroke timing.
    flap = .18 - .68 * math.cos(phase) + .08 * math.sin(2 * phase)
    trailing = -.10 * math.cos(phase - .50)
    if part != "body":
        side = -1 if part == "left" else 1
        u, v = side*(x-768)-64, y-460
        distance = np.sqrt(u*u+v*v)
        # Radial twist around each shoulder preserves area continuously. Unlike
        # a global y-mask, it permits a full downstroke without folded triangles.
        angle = smooth(35, 200, distance)*(flap+trailing*smooth(260,470,distance))
        c, s = np.cos(angle), np.sin(angle)
        px = 768 + side*(64+u*c-v*s)
        py = 460+u*s+v*c
    # All parts share the body lift; tail/feet have a small delayed follow-through.
    py += 8 * math.cos(phase - .60)
    body = 1 - smooth(80, 150, radius)
    py += body * smooth(555, 730, y) * 4 * math.sin(phase - .75)
    px += body * smooth(620, 735, y) * 2 * math.sin(phase - 1.0)
    return np.stack((px, py), axis=-1)


def separate_layers(texture):
    yy, xx = np.indices(texture.shape[:2])
    radius = np.abs(xx-768)
    body_width = 90+25*smooth(550,610,yy)
    body = 1-smooth(body_width-7,body_width+7,radius)
    wing_height = 1-smooth(563,590,yy)
    layers = []
    # Overlapping shoulder masks stay under the body. No painted pixels are
    # invented: all layers are sampled from this one original cutout.
    for name, mask in (("left",smooth(65,85,768-xx)*wing_height),
                       ("right",smooth(65,85,xx-768)*wing_height),
                       ("body",body)):
        rgba = texture.copy()
        rgba[...,3] *= mask
        points, triangles = mesh_for(rgba)
        rgba[...,:3] *= rgba[...,3:4]
        layers.append((name,rgba,points,triangles))
    return layers


def sample_bilinear(texture, x, y):
    h, w = texture.shape[:2]
    x, y = np.clip(x, 0, w - 1.001), np.clip(y, 0, h - 1.001)
    ix, iy = x.astype(np.int32), y.astype(np.int32)
    fx, fy = (x - ix)[..., None], (y - iy)[..., None]
    return ((texture[iy, ix] * (1-fx) + texture[iy, ix+1] * fx) * (1-fy)
            + (texture[iy+1, ix] * (1-fx) + texture[iy+1, ix+1] * fx) * fy)


def mesh_for(texture):
    ys, xs = np.where(texture[..., 3] > .02)
    # Restrict the geometry to the artwork, with a transparent sampling margin.
    x0, x1, y0, y1 = xs.min()-8, xs.max()+8, ys.min()-8, ys.max()+8
    gx = np.linspace(x0, x1, 65)
    gy = np.linspace(y0, y1, 41)
    xx, yy = np.meshgrid(gx, gy)
    points = np.stack((xx, yy), axis=-1).reshape(-1, 2)
    triangles = []
    for j in range(40):
        for i in range(64):
            xa, xb = max(0, int(gx[i])-1), min(texture.shape[1], int(gx[i+1])+2)
            ya, yb = max(0, int(gy[j])-1), min(texture.shape[0], int(gy[j+1])+2)
            if not np.any(texture[ya:yb, xa:xb, 3] > 0):
                continue
            a = j * 65 + i
            triangles.extend(((a, a+1, a+66), (a, a+66, a+65)))
    return points, np.asarray(triangles, dtype=np.int32)


def raster(texture, source, destination, triangles, size):
    # Premultiplied filtering prevents green/dark halos around feather tips.
    canvas = np.zeros((size, size, 4), dtype=np.float32)
    minimum_area = float("inf")
    for tri in triangles:
        p, q, r = destination[tri]
        area = (q[0]-p[0])*(r[1]-p[1]) - (q[1]-p[1])*(r[0]-p[0])
        minimum_area = min(minimum_area, float(area))
        if area <= 0:
            raise ValueError("Wing mesh folded; reduce the flap angle or change weights")
        lo = np.maximum(np.floor(np.minimum(np.minimum(p, q), r)).astype(int), 0)
        hi = np.minimum(np.ceil(np.maximum(np.maximum(p, q), r)).astype(int), size-1)
        if np.any(hi < lo):
            continue
        xx, yy = np.meshgrid(np.arange(lo[0], hi[0]+1)+.5,
                             np.arange(lo[1], hi[1]+1)+.5)
        b = ((xx-p[0])*(r[1]-p[1]) - (yy-p[1])*(r[0]-p[0])) / area
        c = ((q[0]-p[0])*(yy-p[1]) - (q[1]-p[1])*(xx-p[0])) / area
        inside = (b >= -1e-6) & (c >= -1e-6) & (b+c <= 1+1e-6)
        if not np.any(inside):
            continue
        sp, sq, sr = source[tri]
        uv = sp + b[..., None]*(sq-sp) + c[..., None]*(sr-sp)
        sampled = sample_bilinear(texture, uv[..., 0], uv[..., 1])
        tile = canvas[lo[1]:hi[1]+1, lo[0]:hi[0]+1]
        tile[inside] = sampled[inside]
    rgba = np.zeros_like(canvas)
    rgba[..., :3] = canvas[..., :3] / np.maximum(canvas[..., 3:4], 1e-6)
    rgba[..., 3] = canvas[..., 3]
    image = Image.fromarray(np.uint8(np.clip(rgba, 0, 1)*255 + .5))
    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS), minimum_area


def manifest(sheet, size, pivot):
    return {
        "frames": {f"eagle-flight-{i:02d}.png": {
            "frame": {"x": i%4*size, "y": i//4*size, "w": size, "h": size},
            "rotated": False, "trimmed": False,
            "spriteSourceSize": {"x": 0, "y": 0, "w": size, "h": size},
            "sourceSize": {"w": size, "h": size},
            "pivot": {"x": float(pivot[0]), "y": float(pivot[1])},
            "duration": 50,
        } for i in range(FRAME_COUNT)},
        "meta": {
            "image": sheet, "format": "RGBA8888", "size": {"w": 4*size, "h": 4*size},
            "scale": "1", "frameCount": FRAME_COUNT, "fps": FPS, "loop": True,
            "durationMs": 800, "order": "row-major", "alphaMode": "straight",
            "animation": "front-flight", "directions": 1,
            "animations": {"fly": [f"eagle-flight-{i:02d}.png" for i in range(FRAME_COUNT)]},
        },
    }


def write_preview(out, atlas):
    encoded = base64.b64encode(atlas.read_bytes()).decode()
    template = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>老鹰 · 飞行循环</title>
<style>*{box-sizing:border-box}body{margin:0;background:#101923;color:#e4ebf1;font:16px system-ui,sans-serif}
main{max-width:1000px;margin:30px auto;padding:24px}h1{font-size:26px;margin:0 0 8px}p{color:#aab9c6;line-height:1.6}
.stage{display:grid;place-items:center;min-height:400px;border-radius:18px;background:#213a4b;overflow:hidden}
canvas{display:block;width:min(100%,650px);height:auto}nav{display:flex;align-items:center;flex-wrap:wrap;gap:16px;margin:24px 0}
button,select{font:inherit;padding:10px 16px;border:1px solid #536976;border-radius:8px;background:#1c303e;color:#fff}
input{flex:1;min-width:170px}output{font-variant-numeric:tabular-nums;min-width:75px}a{color:#9bdbe8}</style>
<main><h1>老鹰 · 飞行循环</h1><p>原画网格变形烘焙 · 16 帧 · 20 FPS · 0.8 秒循环 · 正面行进</p>
<section class="stage"><canvas width="768" height="650" aria-label="老鹰拍翅动画"></canvas></section>
<nav><button id="play">暂停</button><select id="speed" aria-label="播放速度"><option value="1">正常速度</option><option value=".5">半速</option><option value=".25">四分之一速</option></select>
<select id="background" aria-label="背景"><option value="#213a4b">深蓝背景</option><option value="#d5e9ea">浅色背景</option><option value="checker">透明棋盘</option></select>
<input id="frame" aria-label="帧" type="range" min="0" max="15" value="0"><output id="label">01 / 16</output></nav>
<p>拖动滑块可逐帧检查。首尾按周期连续采样，无重复停顿帧；角色在画布内起伏，行进位移由游戏控制。</p>
<p><a href="runtime/eagle-flight-512.png">512 图集</a> · <a href="runtime/eagle-flight-256.png">256 图集</a> · <a href="preview.gif">GIF 预览</a></p></main>
<script>
const sheet=new Image(),canvas=document.querySelector('canvas'),ctx=canvas.getContext('2d');
const play=document.querySelector('#play'),speed=document.querySelector('#speed'),background=document.querySelector('#background');
const slider=document.querySelector('#frame'),label=document.querySelector('#label');let playing=true,phase=0,last=performance.now();
sheet.src='data:image/png;base64,ATLAS';
play.onclick=()=>{playing=!playing;play.textContent=playing?'暂停':'播放'};
slider.oninput=()=>{playing=false;play.textContent='播放';phase=Number(slider.value)};
document.addEventListener('visibilitychange',()=>{last=performance.now()});
function draw(now){const dt=Math.min(.1,(now-last)/1000);last=now;if(playing&&!document.hidden)phase=(phase+dt*20*Number(speed.value))%16;
const f=Math.floor(phase);slider.value=f;label.textContent=String(f+1).padStart(2,'0')+' / 16';
ctx.fillStyle=background.value==='checker'?'#e0e4e5':background.value;ctx.fillRect(0,0,768,650);
if(background.value==='checker'){ctx.fillStyle='#bec7ca';for(let y=0;y<650;y+=24)for(let x=0;x<768;x+=24)if((x/24+y/24)%2===0)ctx.fillRect(x,y,24,24)}
if(sheet.complete&&sheet.naturalWidth)ctx.drawImage(sheet,f%4*512,Math.floor(f/4)*512,512,512,64,5,640,640);requestAnimationFrame(draw)}requestAnimationFrame(draw);
</script></html>'''
    (out / "preview.html").write_text(template.replace("ATLAS", encoded), encoding="utf-8")


def bake(source_path, out):
    out.mkdir(parents=True, exist_ok=True)
    for folder in ("source", "frames", "runtime"):
        (out/folder).mkdir(exist_ok=True)
    image = Image.open(source_path).convert("RGB")
    if image.size != (1536, 1024):
        raise ValueError("This rig is authored for the supplied 1536×1024 reference")
    if source_path.resolve() != (out/"source/input.png").resolve():
        shutil.copy2(source_path, out/"source/input.png")
    texture = cutout(image)
    Image.fromarray(np.uint8(texture*255+.5)).save(out/"source/eagle-cutout.png")
    layers = separate_layers(texture)
    # One shared camera/crop for every frame, including between-frame extrema.
    poses = np.concatenate([np.concatenate([deform(p,i/128*TAU,name) for i in range(128)])
                            for name,_,p,_ in layers])
    low, high = poses.min(axis=0), poses.max(axis=0)
    scale = min((SIZE-48)/(high-low))
    offset = np.array([SIZE/2, SIZE/2]) - (low+high)/2*scale
    pivot = (np.array([768, 520])*scale+offset)/SIZE
    frames, areas, bounds = [], [], []
    for i in range(FRAME_COUNT):
        frame = Image.new("RGBA", (SIZE,SIZE))
        for name,rgba,points,triangles in layers:
            dest = (deform(points, i/FRAME_COUNT*TAU,name)*scale+offset)*2
            rendered, area = raster(rgba, points, dest, triangles, SIZE*2)
            frame.alpha_composite(rendered)
            areas.append(area)
        frame.save(out/f"frames/eagle-flight-{i:02d}.png", optimize=True)
        frames.append(frame); bounds.append(frame.getbbox())
        print(f"Baked {i+1}/{FRAME_COUNT}", flush=True)
    for size in (512, 256):
        sheet = Image.new("RGBA", (size*4, size*4))
        for i, frame in enumerate(frames):
            sheet.paste(frame.resize((size,size), Image.Resampling.LANCZOS), (i%4*size,i//4*size))
        name = f"eagle-flight-{size}"
        sheet.save(out/f"runtime/{name}.png", optimize=True)
        (out/f"runtime/{name}.json").write_text(json.dumps(manifest(name+".png", size, pivot), ensure_ascii=False, indent=2), encoding="utf-8")
    preview = []
    for frame in frames:
        bg = Image.new("RGBA", (512,512), (33,58,75,255))
        bg.alpha_composite(frame)
        preview.append(bg.convert("RGB"))
    palette = Image.new("RGB", (512*4,512*4))
    for i, frame in enumerate(preview):
        palette.paste(frame,(i%4*512,i//4*512))
    shared_palette = palette.quantize(colors=240)
    gifs = [f.quantize(palette=shared_palette, dither=Image.Dither.NONE) for f in preview]
    gifs[0].save(out/"preview.gif", save_all=True, append_images=gifs[1:], duration=50, loop=0, disposal=2, optimize=False)
    frames[0].save(out/"preview.apng", format="PNG", save_all=True, append_images=frames[1:], duration=50, loop=0, disposal=0, blend=0)
    contact = Image.new("RGB", (1024,1080), (23,36,46))
    draw = ImageDraw.Draw(contact)
    for i, frame in enumerate(preview):
        x,y = i%4*256,i//4*270
        contact.paste(frame.resize((256,256),Image.Resampling.LANCZOS),(x,y))
        draw.text((x+12,y+252),f"{i+1:02d}   {i*50:03d} ms",fill=(215,231,235))
    contact.save(out/"contact-sheet.jpg",quality=93)
    write_preview(out, out/"runtime/eagle-flight-512.png")
    # Same-period check is a geometry check, not a duplicated endpoint in the atlas.
    loop_error = max(float(np.max(np.abs(deform(p,0,name)-deform(p,TAU,name))))
                     for name,_,p,_ in layers)
    evidence = {"sourceSize":list(image.size),"frameCount":FRAME_COUNT,"fps":FPS,"durationMs":800,
                "meshVertices":sum(len(p) for _,_,p,_ in layers),
                "activeTriangles":sum(len(t) for _,_,_,t in layers),"minimumTriangleArea":min(areas),
                "periodicGeometryMaxError":loop_error,"frameBounds":bounds,
                "pivotNormalized":pivot.tolist(),"alpha":"RGBA straight","directions":1,
                "technique":"Original artwork, weighted triangle mesh, offline supersampled baking"}
    (out/"validation.json").write_text(json.dumps(evidence,indent=2),encoding="utf-8")
    return evidence


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(bake(args.source,args.out),indent=2))
