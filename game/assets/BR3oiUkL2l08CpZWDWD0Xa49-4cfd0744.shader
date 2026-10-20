// Sailing schools are surface-projected silhouettes. Preserve visibility over
// opaque deep water, without an offscreen pass or revealing the whole seabed.
shader_type spatial;
render_mode shading_model_unlit, blend_mix, depth_draw_never, cull_disabled, world_vertex_coords;
#include "CrescentColor.shaderinc"
#include "CrescentWaves.shaderinc"
uniform sampler2D water_field : filter_linear, repeat_disable;
varying float fish_coverage;
void vertex() {
    vec2 uv=vec2(VERTEX.x/256.0+.5,.5-VERTEX.z/256.0);
    vec4 f=texture(water_field,(clamp(uv,vec2(0.0),vec2(1.0))*512.0+.5)/513.0);
    float coast=(f.r-.5)*32.0;
    float damping=.10+.90*smoothstep(0.0,5.0,coast)*clamp(f.g*16.0,0.0,1.0);
    VERTEX.y=ocean_height_at(VERTEX.xz,damping)+.075;
    fish_coverage=smoothstep(.3,1.3,coast);
}
void fragment() {
    ALBEDO=cel_srgb_to_linear(vec3(.035,.235,.35));
    ALPHA=.56*fish_coverage;
}
