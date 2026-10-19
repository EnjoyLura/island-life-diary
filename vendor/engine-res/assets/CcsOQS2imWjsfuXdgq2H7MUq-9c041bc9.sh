#ifndef MATERIAL_ENVIRONMENT_SH
#define MATERIAL_ENVIRONMENT_SH

#ifdef COMPILEPS
// Per-fragment material inputs. The shared GI helpers consume them before AO and BRDF.
#if BGFX_SHADER_DIALECT_HLSL
    static hvec4 materialCustomRadiance = hvec4_init(0.0, 0.0, 0.0, 0.0);
    static hvec4 materialCustomIrradiance = hvec4_init(0.0, 0.0, 0.0, 0.0);
#else
    hvec4 materialCustomRadiance = hvec4_init(0.0, 0.0, 0.0, 0.0);
    hvec4 materialCustomIrradiance = hvec4_init(0.0, 0.0, 0.0, 0.0);
#endif

hfloat GetMaterialSpecularOcclusion(hfloat occlusion, hvec3 viewDirection)
{
    #ifdef MATERIAL_SPECULAR_OCCLUSION_DISABLED
        return 1.0;
    #else
        return occlusion;
    #endif
}

vec3 GetMaterialRadiance(vec3 environment)
{
    #ifdef MATERIAL_CUSTOM_RADIANCE
        return mix(environment, materialCustomRadiance.rgb, materialCustomRadiance.a);
    #else
        return environment;
    #endif
}

vec3 GetMaterialIrradiance(vec3 environment)
{
    #ifdef MATERIAL_CUSTOM_IRRADIANCE
        return mix(environment, materialCustomIrradiance.rgb, materialCustomIrradiance.a);
    #else
        return environment;
    #endif
}
#endif
#endif
