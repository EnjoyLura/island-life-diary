shader_type spatial;
render_mode shading_model_pbr, cull_disabled;
uniform float wind_time = 0.0;
void vertex() {
 // Opaque crowns in spatial batches: no alpha cards or per-tree Lua updates.
 float sway=sin(wind_time*1.1+VERTEX.z*.31+VERTEX.x*.18)*.035;
 VERTEX.x+=sway*max(0.0,VERTEX.y-2.8);
}
void fragment() {
 ALBEDO=pow(COLOR.rgb,vec3(2.2));ROUGHNESS=.95;SPECULAR=.12;AO=1.0;
}
