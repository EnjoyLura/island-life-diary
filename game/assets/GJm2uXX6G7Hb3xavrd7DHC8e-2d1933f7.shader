shader_type spatial;
render_mode shading_model_pbr, cull_back;
#include "CrescentColor.shaderinc"
uniform sampler2D stone_map : filter_linear_mipmap, repeat_enable;
void fragment() {
 vec3 n=normalize(NORMAL);
 vec3 w=pow(abs(n),vec3(4.0));w/=max(.001,w.x+w.y+w.z);
 vec3 p=VERTEX*.53;
 // One shared existing stone texture; no normal map or screen-space pass.
 vec3 stone=texture(stone_map,p.yz).rgb*w.x;
 stone+=texture(stone_map,p.xz).rgb*w.y;
 stone+=texture(stone_map,p.xy).rgb*w.z;
 float base=smoothstep(.02,.32,COLOR.a);
 stone*=mix(vec3(.69,.73,.70),vec3(.97,.97,.94),base)*COLOR.rgb;
 ALBEDO=cel_srgb_to_linear(clamp(stone,vec3(0.0),vec3(1.0)));
 ROUGHNESS=.92;SPECULAR=.16;AO=mix(.76,1.0,base);
}
