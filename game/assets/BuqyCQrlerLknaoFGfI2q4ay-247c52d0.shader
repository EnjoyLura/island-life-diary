shader_type spatial;
render_mode shading_model_pbr, cull_back;
uniform sampler2D sand_art : filter_linear_mipmap, repeat_enable;
uniform float beach_time = 0.0;
void fragment() {
 float coast=-9.0+2.0*sin(VERTEX.z*.055)+.8*sin(VERTEX.z*.17);
 float distance=VERTEX.x-coast;
 float grain=texture(sand_art,UV*.21).r;
 float wet=1.0-smoothstep(-.2,3.4,distance);
 vec3 dry=vec3(.91,.82,.65)*( .86+grain*.23 );
 vec3 grass=mix(dry,vec3(.40,.48,.22),smoothstep(21.0,29.0,distance));
 vec3 color=mix(grass,dry*vec3(.78,.82,.83),wet*.62);
 float wash=.45+.4*sin(beach_time*.72+VERTEX.z*.045);
 float edge=1.0-smoothstep(.025,.09,abs(distance-wash));
 color=mix(color,vec3(.89,.95,.93),edge*.64);
 ALBEDO=pow(color,vec3(2.2));
 ROUGHNESS=mix(.94,.65,wet);SPECULAR=.18;AO=1.0;
}
