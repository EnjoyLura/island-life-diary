shader_type spatial;
render_mode shading_model_unlit, cull_back;
#include "CrescentColor.shaderinc"
#include "CrescentBeachSurf.shaderinc"
uniform sampler2D sand_art : filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_data : filter_linear_mipmap, repeat_enable;
void vertex() {
 float d=beach_coast(VERTEX.z)-VERTEX.x;
 vec3 wave=beach_wave(d,VERTEX.z);
 float swash=.095*beach_runup(VERTEX.z)+.095;
 // Keep troughs above the shared sand bed; the run-up mask clips the wet front.
 // Otherwise triangles near the low-tide edge can expose diagonal sand slivers.
 float bed=.08-d*(d>=0.0?.14:.095);
 VERTEX.y=max(bed+.025,mix(swash,wave.x,smoothstep(.0,2.0,d)));
}
void fragment() {
 float d=beach_coast(UV.y)-UV.x;
 float runup=beach_runup(UV.y);
 if(-d>runup) discard;
 vec4 texA=texture(wave_data,UV*.19+vec2(beach_time*.026,-beach_time*.014));
 vec4 texB=texture(wave_data,UV*.37+vec2(-beach_time*.017,beach_time*.021));
 vec2 slope=(texA.rg*2.0-1.0)*.13+(texB.rg*2.0-1.0)*.07;
 vec3 wave=beach_wave(max(d,0.0),UV.y);
 float depth=max(0.0,d*.14+VERTEX.y-.08);
 float sand=texture(sand_art,UV*.21+slope*.07).r;
 vec3 bottom=vec3(.66,.79,.67)*(.88+sand*.17);
 vec3 sea=mix(bottom,vec3(.055,.47,.54),1.0-exp(-depth*.64));
 sea=mix(sea,vec3(.045,.28,.45),1.0-exp(-depth*.08));
 float coastSlope=.11*cos(UV.y*.055)+.136*cos(UV.y*.17);
 vec3 n=normalize(vec3(slope.x+wave.y,1.0,slope.y-wave.y*coastSlope));
 vec3 view=normalize(INV_VIEW_MATRIX[3].xyz-VERTEX);
 float fresnel=.035+.32*pow(1.0-max(0.0,dot(n,view)),4.0);
 sea=mix(sea,vec3(.58,.76,.85),fresnel);
 float glint=pow(max(0.0,dot(n,normalize(view+vec3(-.50,.84,-.20)))),72.0);
 sea+=vec3(.96,.92,.77)*glint*.10;
 // Broad whitewater breaks up into moving bubbles instead of a painted line.
 float bubbles=smoothstep(.29,.67,texA.a*.6+texB.b*.4);
 float shoreEdge=1.0-smoothstep(.06,.32,abs(d+runup));
 float backwash=(1.0-smoothstep(.0,4.0,max(d,0.0)))*smoothstep(.48,.74,texB.a)*.26;
 float foam=clamp(wave.z*(.35+bubbles*.65)+shoreEdge*(.60+bubbles*.40)+backwash,0.0,1.0);
 sea=mix(sea,vec3(.91,.96,.95),foam*.94);
 ALBEDO=cel_srgb_to_linear(clamp(sea,vec3(0.0),vec3(1.0)));
}
