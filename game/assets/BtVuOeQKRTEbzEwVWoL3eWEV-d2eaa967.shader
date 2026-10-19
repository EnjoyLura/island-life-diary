shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never, world_vertex_coords;
#include "CrescentColor.shaderinc"
#include "CrescentWaves.shaderinc"
#include "CrescentWaterLight.shaderinc"
uniform sampler2D water_field : filter_linear, repeat_disable;
uniform float field_span = 160.0;
void vertex() {
    vec2 p=VERTEX.xz;
    float damping=UV.x*UV.y;
    vec3 displacement=ocean_offset(p,damping);
    water_normal=ocean_normal(p,damping);
    water_crest=displacement.y;
    VERTEX+=displacement;
}
void fragment() {
    vec2 p=VERTEX.xz;
    vec2 uv=vec2(p.x/field_span+.5,.5-p.y/field_span);
    vec4 field=texture(water_field,(clamp(uv,vec2(0.0),vec2(1.0))*512.0+.5)/513.0);
    float coast=(field.r-.5)*32.0;
    float depth=field.g*32.0;
    if(fishing_mode>.5) { coast=16.0;depth=10.0+smoothstep(6.0,60.0,length(p-vec2(0.0,-9.0)))*16.0; }
    vec4 lit=water_light(VERTEX,water_normal,water_crest,CAMERA_POSITION_WORLD);
    // Signed distance advances toward each local shore, including coves/reefs.
    vec2 tangent=vec2(-(field.a*2.0-1.0),field.b*2.0-1.0);
    float cycle=fract(ocean_time*.115);
    float front=2.0-cycle*2.4;
    float break_up=.68+.32*sin(dot(p,tangent)*2.7+ocean_time*.31);
    float aa=max(.035,fwidth(coast));
    float swash=(1.0-smoothstep(.07,.17+aa,abs(coast-front)))*sin(cycle*3.14159);
    float retreat=(1.0-smoothstep(.025,.09+aa,abs(coast-front-.37)))*.17;
    float foam=(swash+retreat)*break_up*smoothstep(-.08,.18,coast)*(1.0-fishing_mode);
    float opacity=mix(.07,.79,1.0-exp(-depth*.13));
    // Both partitions converge before their shared geometry edge.
    opacity=mix(opacity,1.0,smoothstep(13.0,19.0,depth));
    vec3 blue=mix(lit.rgb,vec3(.88,.97,.98),foam*.86);
    ALBEDO=cel_srgb_to_linear(blue);
    ALPHA=clamp(opacity+lit.a*.25+foam*.65,0.0,1.0)*smoothstep(-.18,.02,coast);
}
