shader_type spatial;
render_mode shading_model_unlit, cull_disabled, fog_disabled;

// This isolated RT goes straight to NanoVG, with no GammaCorrection/Tonemap quad.
// Sample authored sRGB bytes as data and output them unchanged. The regular
// CrescentSprite shader decodes to linear for its different, gamma-corrected path.
uniform sampler2D art_map : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D art_south : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D join_data : hint_default_white, filter_linear, repeat_disable;
uniform float ground_mode = 0.0;
// width, total height, individual tile height, south offset, all map units.
uniform vec4 tile_layout = vec4(2000.0,3760.0,2000.0,1760.0);
uniform vec2 tile_blend = vec2(1790.0,1970.0);
uniform float south_crop = 220.0;
#include "CrescentHomeCoast.shaderinc"
uniform float wind_time = 0.0;
uniform float wind_strength = 0.0;
uniform float use_vertex_color = 0.0;

void vertex() {
    // Verbatim CrescentSprite.shader wind. COLOR.r = phase radians / 13;
    // COLOR.a = max(0, (t-.18)/.82)^2. Houses/ground/docks have zero strength.
    float gust=sin(wind_time*1.25+COLOR.r*13.0);
    float flutter=sin(wind_time*2.9+VERTEX.x*2.3+VERTEX.y*1.7)*.24;
    VERTEX.x += (gust+flutter)*COLOR.a*wind_strength;
    VERTEX.y += sin(wind_time*1.1+COLOR.r*13.0)*COLOR.a*wind_strength*.16;
}

void fragment() {
    vec4 art=texture(art_map,UV);
    if (ground_mode > .5) {
        vec2 p=UV*tile_layout.xy;
        float blend=smoothstep(tile_blend.x,tile_blend.y,p.y);
        vec2 sourceX=vec2(UV.x);
        if (p.y>tile_blend.x && p.y<tile_blend.y) {
            float v=(p.y-tile_layout.w)/(tile_layout.z-tile_layout.w);
            v=v*(511.0/512.0)+.5/512.0;
            vec4 ne=texture(join_data,vec2(.25,v));
            vec4 se=texture(join_data,vec2(.75,v));
            vec2 n=vec2(dot(ne.rg,vec2(65280.0,255.0)),dot(ne.ba,vec2(65280.0,255.0)))/65535.0;
            vec2 s=vec2(dot(se.rg,vec2(65280.0,255.0)),dot(se.ba,vec2(65280.0,255.0)))/65535.0;
            vec2 edges=mix(n,s,blend);
            float u=(UV.x-edges.x)/max(.001,edges.y-edges.x);
            sourceX=vec2(mix(n.x,n.y,u),mix(s.x,s.y,u));
        }
        vec4 north=texture(art_map,vec2(sourceX.x,p.y/tile_layout.z));
        vec4 south=texture(art_south,vec2(sourceX.y,(p.y-tile_layout.w+south_crop)/tile_layout.z));
        north.a*=1.0-step(tile_layout.z,p.y);
        south.a*=step(tile_layout.w,p.y);
        float na=north.a*(1.0-blend),sa=south.a*blend;
        art=vec4((north.rgb*na+south.rgb*sa)/max(.0001,na+sa),na+sa);
        float d=home_distance(p);
        float sand=step(art.g*.95,art.r)*step(art.b*1.06,art.g);
        float wet=smoothstep(-28.0,-4.0,d)*sand;
        art.rgb=mix(art.rgb,art.rgb*vec3(.78,.88,.89),wet*.42);
        art.rgb=mix(art.rgb,vec3(.95,.995,1.0),home_surf(p,d)*sand*.73);
    }
    if (use_vertex_color > .5) {
        art=vec4(COLOR.rgb,1.0);
    }
    ALBEDO=art.rgb;
    // Match the original .42 cutout threshold, then write opaque covered pixels.
    // Fractional atlas alpha must not overwrite ground alpha beneath a leaf/roof.
    // Empty texels discard (including depth); untouched RT pixels stay RGBA zero.
    ALPHA=step(.42,art.a);
    ALPHA_SCISSOR_THRESHOLD=.5;
}
