#ifndef MATERIAL_RIM_SH
#define MATERIAL_RIM_SH
#ifdef USES_RIM
// Godot spatial rim shape. The workflow supplies the weighted color; each light
// supplies color and unshadowed attenuation separately from the ordinary BRDF.
vec3 GetMaterialRimContribution(vec3 rimColor, float perceptualRoughness, vec3 normal, vec3 viewDirection)
{
    float mask = pow(max(0.0001, 1.0 - max(dot(normal, viewDirection), 0.0001)),
        max(0.0, (1.0 - perceptualRoughness) * 16.0));
    return rimColor * mask;
}
#endif
#endif
