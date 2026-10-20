shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never, world_vertex_coords;
#include "CrescentColor.shaderinc"
#include "CrescentWaves.shaderinc"
uniform sampler2D water_field : filter_linear, repeat_disable;
uniform float field_span = 512.0;
uniform float field_size = 1025.0;
void vertex() {
    vec2 uv=vec2(VERTEX.x/field_span+.5,.5-VERTEX.z/field_span);
    vec4 f=texture(water_field,(clamp(uv,vec2(0.0),vec2(1.0))*(field_size-1.0)+.5)/field_size);
    float damping=.10+.90*smoothstep(0.0,5.0,(f.r-.5)*32.0)*clamp(f.g*16.0,0.0,1.0);
    VERTEX.y=ocean_height_at(VERTEX.xz,damping)+.09;
}
void fragment() {
    float edge=1.0-smoothstep(.10,.49,abs(UV.x-.5));
    float flow=.48+.52*smoothstep(-.45,.65,sin(UV.y*78.0-ocean_time*7.0+UV.x*12.0));
    ALBEDO=cel_srgb_to_linear(vec3(.79,.94,1.0));
    ALPHA=edge*flow*COLOR.a*.72;
}
