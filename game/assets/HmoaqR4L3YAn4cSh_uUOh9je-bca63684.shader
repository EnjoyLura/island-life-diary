shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never, world_vertex_coords;
#include "CrescentColor.shaderinc"
#include "CrescentLegacyWaves.shaderinc"
#include "CrescentCoast.shaderinc"
uniform sampler2D ocean_data : filter_linear_mipmap, repeat_enable;
uniform sampler2D wave_art : filter_linear_mipmap, repeat_enable;
uniform float chart_mode = 0.0;
// Four shifted samples fade to zero at their own tile seams. The result is
// periodic without reflecting the wave shapes into closed oily-looking cells.
vec3 ocean_paint(vec2 uv) {
    vec2 q=fract(uv);
    vec2 w=16.0*q*q*(vec2(1.0)-q)*(vec2(1.0)-q);
    vec3 a=texture(wave_art,q).rgb;
    vec3 b=texture(wave_art,fract(q+vec2(.5,0.0))).rgb;
    vec3 c=texture(wave_art,fract(q+vec2(0.0,.5))).rgb;
    vec3 d=texture(wave_art,fract(q+vec2(.5,.5))).rgb;
    return mix(mix(d,c,w.x),mix(b,a,w.x),w.y);
}
void vertex() {
    float shore_damping=1.0;
    if(reef_mode>.5) { shore_damping=mix(.14,1.0,smoothstep(.1,6.0,bay_coast(VERTEX.xz))); }
    VERTEX.y += ocean_height(VERTEX.xz)*shore_damping;
}
void fragment() {
    vec2 p=VERTEX.xz;
    float t=ocean_time;
    float coast=32.0;
    vec3 reef=vec3(32.0,32.0,28.0);
    if(home_mode>.5) { coast=island_coast(p); }
    if(reef_mode>.5) { reef=reef_coast(p); }
    float depth=water_depth(p,coast,reef);
    if(reef_mode>.5) {
        // Reuse each distance sample for both foam and depth transmission.
        float home_coast=bay_home_coast(p);
        float mountain=mountain_coast(p);
        coast=min(home_coast*bay_home.z,mountain);
        depth=min(depth,min(home_bed_depth(home_coast)*bay_home.z,home_bed_depth(mountain)));
    }
    vec4 flow=texture(ocean_data,p*.025+vec2(t*.002,-t*.001));
    vec4 small=texture(ocean_data,p*.13+vec2(-t*.004,t*.003));
    // Broad low swells with ample clean blue. Small advection, not the strong
    // viscous-looking refraction of a high-contrast painted contour network.
    vec2 warp=(flow.rg-vec2(.5))*.28;
    vec2 uv=(p-vec2(t*1.0,t*1.6)+warp)/64.0;
    vec3 art=ocean_paint(uv);
    // Cross the existing swells with a slower, rotated layer. Navigation needs
    // quiet open water, so tiny painted lines never compete with chart symbols.
    if(chart_mode>.5) {
        vec2 q=vec2(p.x*.83-p.y*.56,p.x*.56+p.y*.83)/83.0+vec2(t*.003,-t*.002);
        art=mix(art,ocean_paint(q),.48);
    }
    float painted_cap=smoothstep(.72,.95,min(art.r,art.g));
    vec3 body=mix(art,vec3(.035,.43,.80),painted_cap*.95);
    // Keep V11's accepted average blue, while compressing contrast around it.
    vec3 blue=vec3(.025,.415,.855)+(body-vec3(.01,.395,.875))*.55;
    float swell=.5+.5*sin(ocean_phase(p,wave_a,0.0));
    blue*=.97+.05*swell;
    blue=mix(blue,vec3(.025,.415,.855)+(blue-vec3(.025,.415,.855))*.55,chart_mode);
    float cap_life=smoothstep(.42,.76,flow.a*.64+small.b*.36);
    float caps=painted_cap*cap_life*.60*mix(1.0,.42,home_mode)*mix(1.0,.40,chart_mode);
    vec2 slope=ocean_slope(p)+(small.gr-vec2(.5))*.018;
    vec3 n=normalize(vec3(-slope.x,1.0,-slope.y));
    vec3 view=normalize(CAMERA_POSITION_WORLD-VERTEX);
    float fresnel=.020+.98*pow(1.0-max(dot(n,view),0.0),5.0);
    // A grazing view reflects the sky. Looking down transmits the real bed;
    // there is no cyan fill or additive light centred on rocks/island.
    blue=mix(blue,vec3(.29,.59,.83),fresnel*.32);
    float shore_zone=1.0-smoothstep(1.0,5.0,depth);
    float cycle=fract(t*.095+flow.b*.16);
    float front=2.2-cycle*2.5+(small.r-.5)*.24;
    float swash=(1.0-smoothstep(.055,.19,abs(coast-front)))*sin(cycle*3.14159);
    float retreat=(1.0-smoothstep(.035,.11,abs(coast-front-.48)))*.19;
    float shore_foam=(swash+retreat)*smoothstep(-.10,.18,coast)*max(home_mode,reef_mode);
    shore_foam*=smoothstep(.30,.64,small.a)*.76;
    float contact=.12+.15*sin(t*1.3+flow.b*6.0);
    float rock_foam=(1.0-smoothstep(.055,.26,abs(reef.x-contact)));
    rock_foam*=smoothstep(-.05,.10,reef.x)*reef_mode*(.25+.75*cap_life);
    float foam=clamp(caps*(1.0-shore_zone*.60)+shore_foam+rock_foam*.92,0.0,.96);
    blue=mix(blue,vec3(.89,.97,1.0),foam);
    float opacity=.12+(1.0-exp(-depth*.12))*.86;
    ALBEDO=cel_srgb_to_linear(clamp(blue,vec3(0.0),vec3(1.0)));
    ALPHA=clamp(opacity+fresnel*.14+foam*.62,.15,.985);
    if(reef_mode>.5) { ALPHA*=smoothstep(-.25,.02,coast); }
}

