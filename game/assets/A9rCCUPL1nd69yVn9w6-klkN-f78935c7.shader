// Top-down illustrated ocean. One opaque pass: no screen/depth reads or SSR.
shader_type spatial;
render_mode shading_model_unlit, cull_disabled, fog_disabled;
uniform sampler2D water_art : source_color, filter_linear_mipmap, repeat_enable;
uniform float ocean_time = 0.0;

// Mirror tiling avoids discontinuities even at the original painted tile edges.
vec2 mirror_uv(vec2 p) {
    return vec2(1.0)-abs(mod(p,vec2(2.0))-vec2(1.0));
}
void fragment() {
    vec2 p = UV;
    float t = ocean_time;
    float distance_to_shore = COLOR.r * 720.0;
    float depth = smoothstep(24.0, 540.0, distance_to_shore);
    vec2 swell = vec2(sin(p.y*0.014+t*0.64)+sin(p.x*0.009-t*0.43),
                      cos(p.x*0.012-t*0.55)+sin(p.y*0.011+t*0.37));
    vec2 uv = p/680.0 + swell*0.021;
    vec3 first = texture(water_art, mirror_uv(uv + vec2(t*0.008,-t*0.005))).rgb;
    vec3 second = texture(water_art, mirror_uv(uv.yx*1.43 + vec2(-t*0.006,t*0.004)+vec2(0.37,0.69))).rgb;
    vec3 water = mix(first,second,0.26);
    // Azure open water, cyan shoals, and pale transparent-looking sand shelves.
    water = mix(water,vec3(0.002,0.105,0.39),depth*0.62);
    water = mix(water,vec3(0.17,0.70,0.55), (1.0-depth)*0.26);
    float shallows = 1.0-smoothstep(3.0,60.0,distance_to_shore);
    water = mix(water,vec3(0.54,0.82,0.67),shallows*0.42);
    // Advancing breakers travel TOWARD the island, then break into lacy foam.
    float bend = 7.0*sin(p.x*0.029+p.y*0.018-t*0.46)
               + 4.0*sin(p.y*0.055-p.x*0.021+t*0.31);
    float phase = fract((distance_to_shore + bend + t*14.0)/72.0);
    float crest = smoothstep(0.78,0.88,phase)*(1.0-smoothstep(0.94,1.0,phase));
    float lace = 0.5+0.5*sin(p.x*0.097+swell.x*2.4)*sin(p.y*0.123+swell.y*2.1);
    float foam = crest*(0.52+0.48*lace)*(1.0-smoothstep(35.0,155.0,distance_to_shore));
    float wash = (1.0-smoothstep(3.0,18.0,distance_to_shore+bend*0.4))*(0.35+0.25*sin(t*0.9+p.y*0.02));
    water = mix(water,vec3(0.90,0.99,1.0),clamp(foam+wash,0.0,0.9));
    // Restrained sun glints, not a full-screen sparkling noise layer.
    float glint = pow(max(0.0,sin(p.x*0.046+t*0.65)*cos(p.y*0.062-t*0.72)),18.0);
    ALBEDO = clamp(water+vec3(0.035,0.055,0.06)*glint,vec3(0.0),vec3(1.0));
}
