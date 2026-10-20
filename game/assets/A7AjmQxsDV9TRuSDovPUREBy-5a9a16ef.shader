shader_type spatial;
render_mode shading_model_unlit, cull_disabled;
#include "CrescentColor.shaderinc"
uniform sampler2D art_map : filter_linear_mipmap, repeat_disable;
uniform float wind_time = 0.0;
uniform float wind_strength = 0.0;
void vertex() {
    // COLOR.a is a per-vertex branch weight: the root stays fixed.
    float gust=sin(wind_time*1.25+COLOR.r*13.0);
    float flutter=sin(wind_time*2.9+VERTEX.x*2.3+VERTEX.y*1.7)*.24;
    VERTEX.x += (gust+flutter)*COLOR.a*wind_strength;
    VERTEX.y += sin(wind_time*1.1+COLOR.r*13.0)*COLOR.a*wind_strength*.16;
}
void fragment() {
    vec4 art=texture(art_map,UV);
    ALBEDO=cel_srgb_to_linear(art.rgb);
    ALPHA=art.a;
    ALPHA_SCISSOR_THRESHOLD=.42;
}
