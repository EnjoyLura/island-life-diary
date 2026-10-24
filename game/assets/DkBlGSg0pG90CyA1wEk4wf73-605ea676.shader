shader_type spatial;
render_mode shading_model_unlit, cull_disabled, fog_disabled;

// This isolated RT goes straight to NanoVG, with no GammaCorrection/Tonemap quad.
// Sample authored sRGB bytes as data and output them unchanged. The regular
// CrescentSprite shader decodes to linear for its different, gamma-corrected path.
uniform sampler2D art_map : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float wind_time = 0.0;
uniform float wind_strength = 0.0;
uniform float use_vertex_color = 0.0;

void vertex() {
    // Verbatim CrescentSprite.shader wind. COLOR.r = phase radians / 13;
    // COLOR.a = max(0, (t-.18)/.82)^2. Houses/ground/docks have zero strength.
    float gust=sin(wind_time*1.25+COLOR.r*13.0);
    float flutter=sin(wind_time*2.9+VERTEX.x*2.3+VERTEX.y*1.7)*.24;
    VERTEX.x += (gust+flutter)*COLOR.a*wind_strength;
    VERTEX.y += sin(wind_time*1.1+COLOR.r*13.0)*COLOR.a*wind_strength*.16;
}

void fragment() {
    vec4 art=texture(art_map,UV);
    if (use_vertex_color > .5) {
        art=vec4(COLOR.rgb,1.0);
    }
    ALBEDO=art.rgb;
    // Match the original .42 cutout threshold, then write opaque covered pixels.
    // Fractional atlas alpha must not overwrite ground alpha beneath a leaf/roof.
    // Empty texels discard (including depth); untouched RT pixels stay RGBA zero.
    ALPHA=step(.42,art.a);
    ALPHA_SCISSOR_THRESHOLD=.5;
}
