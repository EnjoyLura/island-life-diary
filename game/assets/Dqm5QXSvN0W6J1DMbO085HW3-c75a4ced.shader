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
    // Project two view-axis points once per vertex; retain native depth mapping.
    vec4 clip_origin=PROJECTION_MATRIX*vec4(0.0,0.0,0.0,1.0);
    vec4 clip_step=PROJECTION_MATRIX*vec4(0.0,0.0,1.0,1.0);
    water_depth_plane=vec4(clip_step.z-clip_origin.z,clip_origin.z,clip_step.w-clip_origin.w,clip_origin.w);
    VERTEX+=displacement;
}
void fragment() {
    vec3 foam_data;
    vec3 optical_normal;
    ALBEDO=water_light(VERTEX,water_normal,water_crest,CAMERA_POSITION_WORLD,28.0,foam_data,optical_normal).rgb;
}
