shader_type spatial;
render_mode shading_model_unlit, cull_disabled;
#include "CrescentColor.shaderinc"
uniform sampler2D art_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D coast_data : filter_linear, repeat_disable;
uniform float ocean_time = 0.0;
void fragment() {
    vec4 art=texture(art_map,UV);
    float coast=(texture(coast_data,UV).r-.5)*32.0;
    float wash=sin(ocean_time*.75+VERTEX.x*.06)*.35;
    float wet=smoothstep(-1.25,-.12,coast+wash);
    ALBEDO=cel_srgb_to_linear(art.rgb)*mix(vec3(1.0),vec3(.77,.88,.91),wet*.65);
    ALPHA=art.a;
    ALPHA_SCISSOR_THRESHOLD=.42;
}
