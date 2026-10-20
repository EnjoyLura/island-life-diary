shader_type spatial;
render_mode shading_model_unlit, cull_disabled, depth_draw_never;
#include "CrescentColor.shaderinc"
uniform float ocean_time = 0.0;
// R: cumulus volume, G: baked body lighting, B: thin high-cloud wisps.
uniform sampler2D cloud_data : filter_linear_mipmap, repeat_enable;
void fragment() {
 vec3 direction=normalize(VERTEX-INV_VIEW_MATRIX[3].xyz);
 float up=max(0.0,direction.y);
 // Coastal haze near the horizon, clear blue overhead; no abrupt colour band.
 vec3 horizon=vec3(.70,.84,.92);
 vec3 sky=mix(horizon,vec3(.32,.62,.88),smoothstep(0.0,.26,up));
 sky=mix(sky,vec3(.11,.38,.76),smoothstep(.18,.88,up));
 vec3 sun=normalize(vec3(-.50,.84,-.20));
 float mu=max(dot(direction,sun),0.0);
 float sunHaze=pow(mu,12.0)*.10+pow(mu,80.0)*.16;
 sky=mix(sky,vec3(1.0,.94,.81),sunHaze);
 vec2 planar=direction.xz/(up+.23);
 // Just two filtered fetches. Shapes, small lobes and body shading are baked.
 float cirrus=texture(cloud_data,planar*.18+vec2(.31+ocean_time*.00035,.57)).b;
 sky=mix(sky,vec3(.88,.94,.98),cirrus*.045*smoothstep(.12,.45,up));
 vec2 wind=vec2(ocean_time*.00065,ocean_time*.00023);
 vec2 cloud=texture(cloud_data,planar*.36+wind).rg;
 float opacity=smoothstep(.08,.46,cloud.r)*smoothstep(.025,.14,up);
 float body=smoothstep(.35,1.0,cloud.g);
 vec3 cloudColor=mix(vec3(.63,.74,.85),vec3(1.0,.99,.96),body);
 cloudColor=mix(horizon,cloudColor,smoothstep(.02,.25,up));
 sky=mix(sky,cloudColor,opacity*.93);
 ALBEDO=cel_srgb_to_linear(clamp(sky,vec3(0.0),vec3(1.0)));
}
