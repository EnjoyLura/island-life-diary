shader_type spatial;
render_mode shading_model_unlit, cull_back;
uniform sampler2D ripples : filter_linear_mipmap, repeat_enable;
uniform sampler2D bed_art : filter_linear_mipmap, repeat_enable;
uniform float flow_time = 0.0;
varying vec2 stream_uv;
void vertex() {
 // Bend the flow coordinate with the same centreline as ForestWorld.Stream.
 // Calculate here, never run the river layout trigonometry per pixel.
 float centre=17.0+4.2*sin(VERTEX.z*.065)+2.0*sin(VERTEX.z*.143);
 stream_uv=vec2(VERTEX.x-centre,VERTEX.z);
 VERTEX.y+=sin(VERTEX.z*2.0+flow_time*2.2)*.008*COLOR.r;
}
void fragment() {
 // RG are signed slopes, B height, A crest breakup. This is wave data,
 // not the ocean's island-distance/shore-normal lookup used before V39.
 vec4 a=texture(ripples,stream_uv*vec2(.19,.07)+vec2(0.0,flow_time*.035));
 vec4 b=texture(ripples,stream_uv*vec2(.38,.18)+vec2(.29-flow_time*.011,.13+flow_time*.052));
 float detail=1.0-smoothstep(.10,.65,length(fwidth(stream_uv)));
 vec2 slope=((a.rg-.5)*.16+(b.rg-.5)*.08)*detail;
 float depth=COLOR.r*.5;
 float grain=texture(bed_art,UV*.42+slope*.16).r;
 vec3 bottom=vec3(.55,.62,.43)*(.79+grain*.28);
 vec3 water=mix(bottom,vec3(.055,.38,.39),smoothstep(.025,.48,depth)*.84);
 vec3 n=normalize(vec3(slope.x,1.0,slope.y-.0045));
 vec3 view=normalize(INV_VIEW_MATRIX[3].xyz-VERTEX);
 float fresnel=.025+.53*pow(1.0-max(0.0,dot(n,view)),5.0);
 vec3 reflected=reflect(-view,n);
 vec3 sky=mix(vec3(.35,.49,.38),vec3(.49,.72,.82),smoothstep(.04,.65,reflected.y));
 water=mix(water,sky,fresnel);
 float glint=pow(max(0.0,dot(n,normalize(view+vec3(-.50,.84,-.20)))),64.0);
 water+=vec3(.93,.96,.85)*glint*.16*detail;
 // Broken wisps travel downstream. Fine detail fades with pixel footprint
 // instead of turning into sparkling specks at distant bends.
 float thread=pow(max(0.0,sin(stream_uv.x*5.8+a.b*4.0)),12.0);
 float foam=thread*smoothstep(.48,.72,b.a)*smoothstep(.05,.19,depth)*.095*detail;
 float edge=(1.0-smoothstep(.012,.075,depth))*smoothstep(.42,.69,b.a)*.19;
 water=mix(water,vec3(.85,.92,.86),foam+edge);
 water*=.82+.18*COLOR.b;
 ALBEDO=pow(clamp(water,vec3(0.0),vec3(1.0)),vec3(2.2));
}
