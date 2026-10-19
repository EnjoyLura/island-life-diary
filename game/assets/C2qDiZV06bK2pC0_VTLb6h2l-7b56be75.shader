shader_type spatial;
render_mode shading_model_unlit, cull_disabled, depth_draw_never;
#include "CrescentColor.shaderinc"
uniform float ocean_time = 0.0;
uniform sampler2D ocean_data : filter_linear_mipmap, repeat_enable;
void fragment() {
    vec3 direction=normalize(VERTEX-INV_VIEW_MATRIX[3].xyz);
    float up=max(0.0,direction.y);
    // A narrow, airy horizon and a saturated blue dome, rather than a broad
    // pale cyan band occupying almost the entire portrait sky.
    float gradient=pow(clamp(up/.75,0.0,1.0),.42);
    vec3 sky=mix(vec3(.60,.82,.95),vec3(.12,.43,.84),gradient);
    vec3 sun=normalize(vec3(-.45,.75,.40));
    float mu=max(dot(direction,sun),0.0);
    sky+=vec3(1.0,.86,.62)*(pow(mu,18.0)*.07+pow(mu,110.0)*.14);
    vec2 p=direction.xz/(up+.16)*.31+vec2(ocean_time*.0016,ocean_time*.0007);
    vec4 shape=texture(ocean_data,p);
    vec4 detail=texture(ocean_data,p*2.13+vec2(.17,.41));
    vec4 edge=texture(ocean_data,p*4.07+vec2(.63,.29));
    float density=shape.b*.64+detail.a*.26+edge.a*.10;
    float silhouette=smoothstep(.52,.64,density)*smoothstep(.025,.13,up);
    // Cool shaded body and bright sunlit lobes give the drifting cloud masses
    // thickness, while retaining a clean illustrated silhouette.
    float lobe=smoothstep(.41,.72,detail.b+up*.12);
    vec3 cloud=mix(vec3(.62,.76,.89),vec3(.99,.985,.94),lobe);
    cloud=mix(cloud,vec3(1.0,.985,.93),smoothstep(.53,.61,density)*.27);
    sky=mix(sky,cloud,silhouette*.94);
    ALBEDO=cel_srgb_to_linear(clamp(sky,vec3(0.0),vec3(1.0)));
}
