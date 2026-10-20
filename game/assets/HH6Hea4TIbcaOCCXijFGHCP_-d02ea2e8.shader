shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never, world_vertex_coords;
#include "CrescentColor.shaderinc"
#include "CrescentWaves.shaderinc"
#include "CrescentWaterLight.shaderinc"
uniform sampler2D water_field : filter_linear, repeat_disable;
uniform float field_span = 160.0;
void vertex() {
    vec2 p=VERTEX.xz;
    float damping=UV.x*UV.y;
    vec3 displacement;
    vec3 surface_normal;
    ocean_surface(p,damping,displacement,surface_normal);
    // SurfaceShader requires an explicit vertex assignment to classify varyings.
    water_normal=surface_normal;
    water_crest=displacement.y;
    VERTEX+=displacement;
}
void fragment() {
    vec2 p=VERTEX.xz;
    float coast=16.0;
    float depth=28.0;
    // Uniform branch: fishing has an analytic shelf, so skip the field texture.
    if(fishing_mode>.5) {
        depth=10.0+smoothstep(6.0,60.0,length(p-vec2(0.0,-9.0)))*16.0;
    } else {
        vec2 uv=vec2(p.x/field_span+.5,.5-p.y/field_span);
        vec4 field=texture(water_field,(clamp(uv,vec2(0.0),vec2(1.0))*512.0+.5)/513.0);
        coast=(field.r-.5)*32.0;
        depth=field.g*32.0;
    }
    vec2 foam_data;
    vec4 lit=water_light(VERTEX,water_normal,water_crest,CAMERA_POSITION_WORLD,depth,foam_data);
    float foam=0.0;
    if(fishing_mode<.5) {
        // Local phase/breakup reuses the two light samples. Both fronts fade at
        // the cycle wrap, so the retreat cannot pop back to the outer shoreline.
        float cycle=fract(ocean_time*.115+foam_data.y*.28);
        float envelope=4.0*cycle*(1.0-cycle);
        float front=2.0-cycle*2.4;
        float aa=max(.035,fwidth(coast));
        float noise_width=max(.04,fwidth(foam_data.x));
        float break_up=.12+.88*smoothstep(.40-noise_width,.64+noise_width,foam_data.x);
        float swash=1.0-smoothstep(.07,.17+aa,abs(coast-front));
        float retreat=(1.0-smoothstep(.025,.09+aa,abs(coast-front-.37)))*.17;
        foam=(swash+retreat)*envelope*break_up*smoothstep(-.08,.18,coast);
    }
    float opacity=mix(.07,.79,1.0-exp(-depth*.13));
    // Both partitions converge before their shared geometry edge.
    opacity=mix(opacity,1.0,smoothstep(13.0,19.0,depth));
    vec3 blue=mix(lit.rgb,vec3(.88,.97,.98),foam*.86);
    ALBEDO=cel_srgb_to_linear(blue);
    ALPHA=clamp(opacity+lit.a*.25+foam*.65,0.0,1.0)*smoothstep(-.18,.02,coast);
}
