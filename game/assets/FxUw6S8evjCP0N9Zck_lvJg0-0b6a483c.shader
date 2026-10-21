shader_type spatial;
render_mode shading_model_pbr, cull_back;
#include "CrescentBeachSurf.shaderinc"
uniform sampler2D sand_art : filter_linear_mipmap, repeat_enable;
void fragment() {
 float coast=beach_coast(VERTEX.z);
 float distance=VERTEX.x-coast;
 float grain=texture(sand_art,UV*.21).r;
 float wet=1.0-smoothstep(-.2,3.4,distance);
 vec3 dry=vec3(.91,.82,.65)*( .86+grain*.23 );
 vec3 grass=mix(dry,vec3(.40,.48,.22),smoothstep(21.0,29.0,distance));
 vec3 color=mix(grass,dry*vec3(.78,.82,.83),wet*.62);
 // Recently washed sand stays darker after the water drains away.
 float washed=1.0-smoothstep(beach_runup(VERTEX.z),2.6,distance);
 color=mix(color,color*vec3(.85,.88,.90),washed*.38);
 ALBEDO=pow(color,vec3(2.2));
 ROUGHNESS=mix(.94,.65,wet);SPECULAR=.18;AO=1.0;
}
