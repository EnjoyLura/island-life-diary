shader_type spatial;
render_mode shading_model_unlit, cull_back;
#include "CrescentColor.shaderinc"
uniform sampler2D sand_art : filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_data : filter_linear_mipmap, repeat_enable;
uniform float beach_time = 0.0;
void vertex() {
 float coast=-9.0+2.0*sin(VERTEX.z*.055)+.8*sin(VERTEX.z*.17);
 float deep=smoothstep(.6,9.0,coast-VERTEX.x);
 VERTEX.y+=deep*(sin(VERTEX.x*.25+VERTEX.z*.11-beach_time*.83)*.045+sin(VERTEX.z*.43-beach_time*1.1)*.018);
}
void fragment() {
 float coast=-9.0+2.0*sin(VERTEX.z*.055)+.8*sin(VERTEX.z*.17);
 float distance=max(0.0,coast-VERTEX.x);
 vec2 a=texture(wave_data,UV*.047+vec2(beach_time*.008,-beach_time*.004)).rg*2.0-1.0;
 vec2 b=texture(wave_data,UV*.083+vec2(-beach_time*.005,beach_time*.006)).rg*2.0-1.0;
 vec2 slope=a*.13+b*.07;
 float depth=distance*.14;
 float sand=texture(sand_art,UV*.21+slope*.07).r;
 vec3 bottom=vec3(.66,.79,.67)*(.88+sand*.17);
 vec3 sea=mix(bottom,vec3(.055,.47,.54),1.0-exp(-depth*.64));
 sea=mix(sea,vec3(.045,.28,.45),1.0-exp(-depth*.08));
 vec3 n=normalize(vec3(slope.x,1.0,slope.y));
 vec3 view=normalize(INV_VIEW_MATRIX[3].xyz-VERTEX);
 float fresnel=.035+.32*pow(1.0-max(0.0,dot(n,view)),4.0);
 sea=mix(sea,vec3(.58,.76,.85),fresnel);
 float glint=pow(max(0.0,dot(n,normalize(view+vec3(-.50,.84,-.20)))),72.0);
 sea+=vec3(.96,.92,.77)*glint*.10;
 // Fine, broken shore wash: no full-screen stripes, screen copies or noise loops.
 float crest=.9+.4*sin(beach_time*.72+VERTEX.z*.045);
 float foam=(1.0-smoothstep(.035,.17,abs(distance-crest)))*(.55+.45*a.x);
 sea=mix(sea,vec3(.90,.96,.94),foam*.68);
 ALBEDO=cel_srgb_to_linear(clamp(sea,vec3(0.0),vec3(1.0)));
}
