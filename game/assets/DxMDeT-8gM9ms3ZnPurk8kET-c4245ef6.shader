shader_type spatial;
render_mode shading_model_pbr, cull_disabled;
uniform float surface_roughness = 0.72;
uniform float surface_metallic = 0.0;
void fragment() {
    ALBEDO = pow(max(COLOR.rgb,vec3(0.0)),vec3(2.2));
    ROUGHNESS = surface_roughness;
    METALLIC = surface_metallic;
    SPECULAR = 0.35;
    AO = 1.0;
}
// Warm key, cool ambient fill, and real shadows; desktop and Web compatible.
void light() {
    float wrap = smoothstep(-0.18,0.78,dot(NORMAL,LIGHT));
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * wrap * 0.78;
    vec3 half_direction = normalize(LIGHT+VIEW);
    float shine = pow(max(dot(NORMAL,half_direction),0.0),mix(90.0,14.0,ROUGHNESS));
    SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * shine * (1.0-ROUGHNESS) * 0.24;
}
