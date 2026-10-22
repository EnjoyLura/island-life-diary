shader_type spatial;
render_mode shading_model_pbr, cull_back;
varying vec3 bark_pos;
void vertex(){bark_pos=VERTEX;}
void fragment(){
 float ribs=sin((bark_pos.x+bark_pos.z*.63)*34.0+sin(bark_pos.y*2.7)*1.7);
 float grain=sin(bark_pos.y*7.0+bark_pos.x*21.0)*sin(bark_pos.z*19.0+bark_pos.y*3.0);
 float fissure=smoothstep(.56,.93,ribs)*(.65+.35*sin(bark_pos.y*1.3));
 vec3 color=COLOR.rgb*(1.04-fissure*.20+grain*.035);
 float moss=(1.0-smoothstep(.2,1.8,bark_pos.y)) * smoothstep(.1,.6,grain);
 color=mix(color,vec3(.29,.37,.19),moss*.35);
 ALBEDO=pow(color,vec3(2.2));ROUGHNESS=.98;SPECULAR=.06;
}
