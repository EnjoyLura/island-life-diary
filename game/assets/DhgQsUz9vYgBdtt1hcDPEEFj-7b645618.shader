shader_type spatial;
render_mode shading_model_unlit, cull_disabled, world_vertex_coords;
#include "CrescentColor.shaderinc"
#include "CrescentWaves.shaderinc"
#include "CrescentWaterLight.shaderinc"
void vertex() {
    vec2 p=VERTEX.xz;
    float damping=UV.x*UV.y;
    vec3 displacement=ocean_offset(p,damping);
    water_normal=ocean_normal(p,damping);
    water_crest=displacement.y;
    VERTEX+=displacement;
}
void fragment() { ALBEDO=cel_srgb_to_linear(water_light(VERTEX,water_normal,water_crest,CAMERA_POSITION_WORLD).rgb); }
