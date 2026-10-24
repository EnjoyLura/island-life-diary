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
 float patches=sin(VERTEX.z*.21+sin(VERTEX.x*.37))*1.8+sin(VERTEX.z*.63)*.7;
 float growth=smoothstep(21.0,30.0,distance+patches);
 vec3 ground=mix(vec3(.39,.48,.24),vec3(.51,.57,.29),grain);
 vec3 grass=mix(dry,ground,growth);
 vec3 color=mix(grass,dry*vec3(.78,.82,.83),wet*.62);
 // Recently washed sand stays darker after the water drains away.
 float washed=1.0-smoothstep(beach_runup(VERTEX.z),2.6,distance);
 color=mix(color,color*vec3(.85,.88,.90),washed*.38);
 ALBEDO=pow(color,vec3(2.2));
 ROUGHNESS=mix(.94,.65,wet);SPECULAR=.18;AO=1.0;
}
