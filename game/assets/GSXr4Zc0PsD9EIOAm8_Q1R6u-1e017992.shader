shader_type spatial;
render_mode shading_model_unlit, cull_disabled, world_vertex_coords;
#include "CrescentColor.shaderinc"
#include "CrescentCoast.shaderinc"
uniform sampler2D shelf_art : filter_linear_mipmap, repeat_disable;
uniform sampler2D sand_art : filter_linear_mipmap, repeat_enable;
uniform sampler2D ocean_data : filter_linear_mipmap, repeat_enable;
// Registered from green-land coverage in the original and extended art.
uniform vec4 art_mapping = vec4(.016111111,.016111111,.51171875,.4921875);
uniform float ocean_time = 0.0;
uniform vec3 shelf_frame = vec3(0.0,0.0,1.0);
varying vec2 shelf_source;
void vertex() {
    // Evaluate the inverse map at mesh vertices, not again for every pixel.
    shelf_source=island_source((VERTEX.xz-shelf_frame.xy)/shelf_frame.z);
    float coast=source_coast(shelf_source);
    VERTEX.y=-home_bed_depth(coast)*shelf_frame.z;
    UV.y=coast/14.0;
}
void fragment() {
    vec2 p=shelf_source;
    float depth=max(0.0,-VERTEX.y);
    vec4 flow=texture(ocean_data,p*.17+vec2(ocean_time*.006,-ocean_time*.004));
    vec2 refract=(flow.rg-vec2(.5))*.018;
    vec2 uv=vec2((p.x+refract.x)*art_mapping.x,-(p.y+refract.y)*art_mapping.y)+art_mapping.zw;
    vec4 art=texture(shelf_art,clamp(uv,vec2(0.0),vec2(1.0)));
    // Sand ridges follow local bays/headlands; no mirrored world-space squares.
    vec3 sand=texture(sand_art,UV+refract/14.0).rgb;
    // The original dry island is retained above this layer. In the few spots
    // where generated land registration differs, continue sand, never grass.
    float grass=smoothstep(.04,.16,art.g-art.r)*smoothstep(.07,.22,art.g-art.b);
    float coverage=art.a*(1.0-grass);
    coverage*=step(0.0,uv.x)*step(0.0,uv.y)*step(uv.x,1.0)*step(uv.y,1.0);
    vec3 base=cel_srgb_to_linear(mix(sand,art.rgb,coverage));
    base*=exp(-depth*vec3(.46,.20,.15)*.75);
    float caustic=smoothstep(.62,.80,flow.b)*(1.0-smoothstep(1.5,8.0,depth));
    base*=1.0+caustic*.08;
    ALBEDO=base;
}
