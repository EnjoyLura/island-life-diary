shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never, world_vertex_coords;
#include "CrescentColor.shaderinc"
#include "CrescentLegacyWaves.shaderinc"
void vertex() {
    VERTEX.y=ocean_height(VERTEX.xz)+.055;
}
void fragment() {
    float edge=1.0-smoothstep(.10,.49,abs(UV.x-.5));
    float flow=.48+.52*smoothstep(-.45,.65,sin(UV.y*78.0-ocean_time*7.0+UV.x*12.0));
    ALBEDO=cel_srgb_to_linear(vec3(.79,.94,1.0));
    ALPHA=edge*flow*COLOR.a*.72;
}

