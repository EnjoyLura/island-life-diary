shader_type spatial;
render_mode shading_model_unlit, cull_disabled, world_vertex_coords;
#include "CrescentColor.shaderinc"
#include "CrescentCoast.shaderinc"
uniform sampler2D art_map : filter_linear_mipmap, repeat_disable;
void fragment() {
    vec2 uv=mountain_sample_uv(VERTEX.xz);
    // Extend only opaque inland pixels. Never repeat the transparent coast or
    // clamp to the partially transparent outermost image column.
    if(uv.x>.98) {
        uv.x=.98-.13*(1.0-abs(mod((uv.x-.98)/.13,2.0)-1.0));
    }
    vec4 art=texture(art_map,clamp(uv,vec2(0.0),vec2(1.0)));
    ALBEDO=cel_srgb_to_linear(art.rgb);
    ALPHA=art.a;
    ALPHA_SCISSOR_THRESHOLD=.42;
}
