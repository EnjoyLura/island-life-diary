shader_type spatial;
render_mode shading_model_unlit, cull_disabled, depth_draw_never;
#include "CrescentColor.shaderinc"
uniform float ocean_time = 0.0;
// R: sparse cloud coverage, G: baked body lighting. One continuous sky layer.
uniform sampler2D cloud_data : filter_linear_mipmap, repeat_enable;
void fragment() {
 vec3 direction=normalize(VERTEX-INV_VIEW_MATRIX[3].xyz);
 float up=max(0.0,direction.y);
 // Coastal haze near the horizon, clear blue overhead; no abrupt colour band.
 vec3 horizon=vec3(.67,.83,.93);
 vec3 sky=mix(horizon,vec3(.29,.63,.91),smoothstep(0.0,.24,up));
 sky=mix(sky,vec3(.10,.40,.80),smoothstep(.18,.88,up));
 vec3 sun=normalize(vec3(-.50,.84,-.20));
 float mu=max(dot(direction,sun),0.0);
 float sunHaze=pow(mu,12.0)*.10+pow(mu,80.0)*.16;
 sky=mix(sky,vec3(1.0,.94,.81),sunHaze);
 // A stereographic hemisphere avoids both a polar singularity overhead and
 // the flattened cloud ribbons of an infinite horizontal plane at the horizon.
 // Translate on this continuous layer along one fixed wind vector.
 vec2 cloudUV=direction.xz*(.43/(1.0+up))+vec2(.5);
 vec2 cloud=texture(cloud_data,cloudUV+ocean_time*vec2(.00065,.00024)).rg;
 float opacity=cloud.r*smoothstep(.04,.18,up);
 vec3 cloudColor=mix(vec3(.66,.76,.88),vec3(1.0,.99,.97),cloud.g);
 cloudColor=mix(horizon,cloudColor,smoothstep(.06,.24,up));
 sky=mix(sky,cloudColor,opacity*.93);
 ALBEDO=cel_srgb_to_linear(clamp(sky,vec3(0.0),vec3(1.0)));
}
