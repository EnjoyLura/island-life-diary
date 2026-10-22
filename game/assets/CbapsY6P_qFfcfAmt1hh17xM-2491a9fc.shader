shader_type spatial;
render_mode shading_model_unlit, cull_back;
uniform sampler2D ripples : filter_linear_mipmap, repeat_enable;
uniform float flow_time = 0.0;
void vertex(){
 VERTEX.y+=sin(VERTEX.z*2.0+flow_time*2.2)*.009*COLOR.r;
}
void fragment(){
 vec4 ripple=texture(ripples,UV*.24+vec2(.02*flow_time,.31*flow_time));
 float depth=COLOR.r;
 vec3 bottom=vec3(.38,.53,.39)*(.90+ripple.b*.15);
 vec3 water=mix(bottom,vec3(.055,.355,.34),smoothstep(.02,.86,depth));
 vec2 slope=(ripple.rg*2.0-1.0)*.08;
 vec3 n=normalize(vec3(slope.x,1.0,slope.y));
 vec3 view=normalize(INV_VIEW_MATRIX[3].xyz-VERTEX);
 float fresnel=.08+.30*pow(1.0-max(0.0,dot(n,view)),4.0);
 water=mix(water,vec3(.53,.73,.78),fresnel);
 float thread=sin(UV.y*4.3+flow_time*3.5+sin(UV.x*2.4)*1.7);
 thread=pow(max(0.0,thread),16.0)*smoothstep(.57,.78,ripple.a);
 float edge=(1.0-smoothstep(.0,.08,depth))*smoothstep(.37,.64,ripple.b);
 water=mix(water,vec3(.84,.91,.84),thread*.23+edge*.34);
 ALBEDO=pow(water,vec3(2.2));
}
