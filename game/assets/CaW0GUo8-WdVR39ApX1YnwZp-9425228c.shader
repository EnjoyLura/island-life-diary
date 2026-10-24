shader_type spatial;
render_mode shading_model_pbr, cull_disabled;
uniform float wind_time = 0.0;
varying vec3 leaf_pos;
void vertex() {
 // Opaque crowns in spatial batches: no alpha cards or per-tree Lua updates.
 leaf_pos=VERTEX;
 float sway=sin(wind_time*.85+VERTEX.z*.31+VERTEX.x*.18)*.018;
 VERTEX.x+=sway*max(0.0,VERTEX.y-3.5);
}
void fragment() {
 // Soft overlapping leaf marks without cutout cards or extra image assets.
 vec2 p=leaf_pos.xz*7.2+vec2(leaf_pos.y*.7,leaf_pos.y*.9);
 float leaves=sin(p.x+sin(p.y*.7)) * sin(p.y+sin(p.x*.6));
 float veins=smoothstep(.57,.88,leaves);
 vec3 color=COLOR.rgb*(.97+leaves*.025+veins*.045);
 ALBEDO=pow(color,vec3(2.2));ROUGHNESS=.95;SPECULAR=.08;AO=1.0;
}
