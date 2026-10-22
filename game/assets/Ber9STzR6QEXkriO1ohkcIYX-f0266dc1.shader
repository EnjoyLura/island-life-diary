shader_type spatial;
render_mode shading_model_pbr, cull_back;
uniform sampler2D sand_art : filter_linear_mipmap, repeat_enable;
void fragment() {
 float grain=texture(sand_art,UV*.28).r;
 float trail=abs(VERTEX.x-3.6*sin(VERTEX.z*.115));
 float path=1.0-smoothstep(1.35,3.6,trail);
 float glade=1.0-smoothstep(2.0,5.8,length(VERTEX.xz-vec2(9.0,29.0)));
 vec3 grass=mix(vec3(.29,.40,.19),vec3(.42,.52,.25),grain);
 vec3 earth=mix(vec3(.56,.43,.27),vec3(.74,.62,.42),grain);
 vec3 color=mix(grass,earth,max(path,glade*.70))*COLOR.rgb;
 ALBEDO=pow(color,vec3(2.2));ROUGHNESS=.98;SPECULAR=.08;AO=1.0;
}
