shader_type spatial;
render_mode shading_model_unlit, cull_back;
#include "CrescentColor.shaderinc"
uniform sampler2D stone_map : filter_linear_mipmap, repeat_enable;
uniform sampler2D ocean_data : filter_linear_mipmap, repeat_enable;
uniform float ocean_time = 0.0;
void fragment() {
    vec3 n=normalize(NORMAL);
    vec3 weight=pow(abs(n),vec3(5.0));
    weight/=max(.001,weight.x+weight.y+weight.z);
    vec3 p=VERTEX*.32;
    vec3 stone=texture(stone_map,p.yz).rgb*weight.x;
    stone+=texture(stone_map,p.xz).rgb*weight.y;
    stone+=texture(stone_map,p.xy).rgb*weight.z;
    float sun=dot(n,normalize(vec3(-.50,.84,-.20)));
    float lit=smoothstep(-.12,.08,sun)*.23+smoothstep(.48,.72,sun)*.11;
    stone*=vec3(.65,.73,.85)+vec3(1.0,.90,.72)*lit;
    float wet=1.0-smoothstep(-.10,.40,VERTEX.y);
    stone*=mix(vec3(1.0),vec3(.64,.73,.77),wet*.60);
    vec3 base=cel_srgb_to_linear(clamp(stone,vec3(0.0),vec3(1.0)));
    float depth=max(0.0,-VERTEX.y);
    base*=exp(-depth*vec3(.432,.093,.059)*.75);
    vec4 light=texture(ocean_data,VERTEX.xz*.17+vec2(ocean_time*.006,-ocean_time*.004));
    float caustic=smoothstep(.62,.80,light.b)*smoothstep(.12,.5,depth)*(1.0-smoothstep(2.0,7.0,depth));
    base*=1.0+caustic*.22;
    ALBEDO=base;
}
