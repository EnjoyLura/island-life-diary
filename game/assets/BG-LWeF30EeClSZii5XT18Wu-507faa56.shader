shader_type spatial;
render_mode shading_model_unlit, cull_disabled;
#include "CrescentColor.shaderinc"
uniform sampler2D sand_art : filter_linear_mipmap, repeat_enable;
uniform sampler2D ocean_data : filter_linear_mipmap, repeat_enable;
uniform float ocean_time = 0.0;
void fragment() {
    float depth=max(0.0,-VERTEX.y);
    vec2 p=VERTEX.xz;
    vec4 flow=texture(ocean_data,p*.17+vec2(ocean_time*.006,-ocean_time*.004));
    vec2 refract=(flow.rg-vec2(.5))*.055;
    vec2 tile=1.0-abs(fract((p+refract)/14.0)*2.0-1.0);
    vec3 sand=texture(sand_art,tile).rgb;
    vec3 base=cel_srgb_to_linear(sand);
    float light=.77+.23*max(dot(normalize(NORMAL),normalize(vec3(-.50,.84,-.20))),0.0);
    // Selective light absorption, on the actual tilted sand below the water.
    // Red disappears faster than green/blue; the substrate keeps its detail.
    base*=light*exp(-depth*vec3(.74,.115,.035));
    float caustic=smoothstep(.62,.80,flow.b)*(1.0-smoothstep(1.5,8.0,depth));
    base*=1.0+caustic*.15;
    base=mix(base,cel_srgb_to_linear(vec3(.025,.30,.52)),1.0-exp(-depth*.045));
    ALBEDO=base;
}
