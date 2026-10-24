shader_type spatial;
render_mode shading_model_pbr, cull_back;
uniform sampler2D sand_art : filter_linear_mipmap, repeat_enable;
void fragment() {
 float grain=texture(sand_art,UV*.28).r;
 // Trail junctions, wet banks and canopy shade are baked per terrain vertex.
 vec3 color=COLOR.rgb*(.84+grain*.28);
 ALBEDO=pow(color,vec3(2.2));ROUGHNESS=.98;SPECULAR=.08;AO=1.0;
}
