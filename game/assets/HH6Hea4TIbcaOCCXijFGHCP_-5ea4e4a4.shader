shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never, world_vertex_coords;
#include "CrescentColor.shaderinc"
#include "CrescentWaves.shaderinc"
#include "CrescentWaterLight.shaderinc"
uniform sampler2D water_field : filter_linear, repeat_disable;
uniform float field_span = 160.0;
// One engine-provided opaque colour/depth copy, shared by every shallow tile.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float screen_y_sign = -1.0;
void vertex() {
    vec2 p=VERTEX.xz;
    float damping=UV.x*UV.y;
    vec3 displacement;
    vec3 surface_normal;
    ocean_surface(p,damping,displacement,surface_normal);
    // SurfaceShader requires an explicit vertex assignment to classify varyings.
    water_normal=surface_normal;
    water_crest=displacement.y;
    // Project two view-axis points once per vertex; retain native depth mapping.
    vec4 clip_origin=PROJECTION_MATRIX*vec4(0.0,0.0,0.0,1.0);
    vec4 clip_step=PROJECTION_MATRIX*vec4(0.0,0.0,1.0,1.0);
    water_depth_plane=vec4(clip_step.z-clip_origin.z,clip_origin.z,clip_step.w-clip_origin.w,clip_origin.w);
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
    vec3 foam_data;
    vec3 optical_normal;
    vec4 lit=water_light(VERTEX,water_normal,water_crest,CAMERA_POSITION_WORLD,depth,foam_data,optical_normal);
    // Keep the actual seabed/rock path continuous across every shallow tile.
    // Deep geometry is admitted only where the full light path is opaque.
    vec3 radiance=lit.rgb;
    {
        vec3 view=water_view.xyz;
        if(water_view.w<.5) { view=normalize(CAMERA_POSITION_WORLD-VERTEX); }
        float water_z=abs((VIEW_MATRIX*vec4(VERTEX,1.0)).z);
        float scene_raw=texture(depth_texture,SCREEN_UV).r;
        float scene_clip=screen_y_sign>0.0?scene_raw*2.0-1.0:scene_raw;
        float scene_z=water_view_depth(scene_clip,water_depth_plane);
        vec3 view_normal=(VIEW_MATRIX*vec4(optical_normal,0.0)).xyz;
        vec2 offset=view_normal.xy*vec2(1.0,screen_y_sign)*.012
            *clamp((scene_z-water_z)/1.2,0.0,1.0)/max(1.0,water_z*.07);
        // Fade the offset into screen edges, and reject foreground silhouettes.
        vec2 edge=min(SCREEN_UV,vec2(1.0)-SCREEN_UV);
        offset*=smoothstep(0.0,.025,min(edge.x,edge.y));
        vec2 refract_uv=clamp(SCREEN_UV+offset,vec2(.001),vec2(.999));
        float refract_raw=texture(depth_texture,refract_uv).r;
        float refract_clip=screen_y_sign>0.0?refract_raw*2.0-1.0:refract_raw;
        float refract_z=water_view_depth(refract_clip,water_depth_plane);
        if(refract_z<water_z+.02) { refract_uv=SCREEN_UV;refract_z=scene_z; }
        vec3 source=texture(screen_texture,refract_uv).rgb;
        vec3 refracted_ray=refract(-view,optical_normal,1.0/1.333);
        float down=-refracted_ray.y;
        // Use the sampled object depth, not the vertical atlas depth at this pixel.
        // They differ across sloping reef banks in an oblique view.
        float path_length=water_path_length(refract_z,water_z,view.y,down);
        vec3 transmitted=water_transmission(source,path_length);
        // The opaque ocean is not an underwater object; do not refract it twice.
        float bottom_visible=smoothstep(.02,.22,refract_z-water_z);
        radiance+=(transmitted-water_scatter())*(1.0-lit.a)*(1.0-foam_data.z)*bottom_visible;
    }
    float foam=0.0;
    if(fishing_mode<.5) {
        // Local phase/breakup reuses the two light samples. Both fronts fade at
        // the cycle wrap, so the retreat cannot pop back to the outer shoreline.
        float cycle=fract(ocean_time*.13+foam_data.y*.22);
        float envelope=4.0*cycle*(1.0-cycle);
        float front=1.3-cycle*1.65;
        float aa=max(.035,fwidth(coast));
        float noise_width=max(.04,fwidth(foam_data.x));
        // Disconnected foam flecks replace the permanent pale outline at rocks.
        float break_up=smoothstep(.48-noise_width,.70+noise_width,foam_data.x);
        float swash=1.0-smoothstep(.06,.22+aa,abs(coast-front));
        float retreat=(1.0-smoothstep(.025,.09+aa,abs(coast-front-.30)))*.12;
        foam=(swash+retreat)*envelope*break_up*smoothstep(-.08,.18,coast);
    }
    ALBEDO=mix(radiance,cel_srgb_to_linear(vec3(.78,.92,.92)),foam*.58);
    // Transmission is already composed above; alpha only covers the shoreline.
    ALPHA=smoothstep(-.18,.02,coast);
}
