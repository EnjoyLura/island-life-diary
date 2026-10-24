// Display-encoded top-down glass water. One flat pass, no full-screen wave bands.
shader_type spatial;
render_mode shading_model_unlit, cull_disabled, fog_disabled;
#include "CrescentHomeCoast.shaderinc"
void fragment() {
    vec2 p=UV;float t=ocean_time;float d=max(0.0,home_distance(p));
    float bed=home_noise(p/64.0)*.65+home_noise(p/19.0)*.35;
    float shelf=1.0-smoothstep(10.0,110.0,d);
    float depth=smoothstep(35.0,390.0,d);
    vec3 sand=mix(vec3(.65,.80,.65),vec3(.46,.77,.74),smoothstep(0.0,65.0,d));
    sand+=vec3(.05,.045,.025)*(bed-.5);
    vec3 water=mix(vec3(.11,.70,.82),vec3(.035,.39,.72),depth);
    water=mix(water,sand,shelf*.76);
    // Refracted web highlights on the submerged shelf, warped in two directions.
    vec2 drift=vec2(t*.016,-t*.011);
    float warp=home_noise(p/110.0+drift);
    float cell=home_noise(p/21.0+vec2(warp*1.7,-warp*.9)+drift);
    float caustic=pow(max(0.0,1.0-abs(cell-.52)*9.0),5.0);
    water+=vec3(.10,.14,.105)*caustic*shelf*smoothstep(1.0,15.0,d);
    float ripple=home_noise(p/95.0+vec2(t*.035,-t*.018));
    float detail=home_noise(p/32.0+vec2(-t*.025,t*.013));
    water+=vec3(.018,.033,.040)*((ripple-.5)*.75+(detail-.5)*.25);
    float glint=pow(smoothstep(.78,.97,detail)*smoothstep(.65,.94,ripple),14.0);
    water+=vec3(.02,.025,.03)*glint;
    water=mix(water,vec3(.93,.995,1.0),home_surf(p,d)*.85);
    ALBEDO=clamp(water,vec3(0.0),vec3(1.0));
}
