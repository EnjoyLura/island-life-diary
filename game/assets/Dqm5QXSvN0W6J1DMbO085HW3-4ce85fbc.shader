shader_type spatial;
render_mode shading_model_unlit, cull_disabled, world_vertex_coords;
#include "CrescentColor.shaderinc"
#include "CrescentWaves.shaderinc"
#include "CrescentWaterLight.shaderinc"
void vertex() {
    vec2 p=VERTEX.xz;
    float damping=UV.x*UV.y;
    vec3 displacement;
    vec3 surface_normal;
    ocean_surface(p,damping,displacement,surface_normal);
    // SurfaceShader requires an explicit vertex assignment to classify varyings.
    water_normal=surface_normal;
    water_crest=displacement.y;
    VERTEX+=displacement;
}
void fragment() {
    vec2 foam_data;
    ALBEDO=cel_srgb_to_linear(water_light(VERTEX,water_normal,water_crest,CAMERA_POSITION_WORLD,28.0,foam_data).rgb);
}
