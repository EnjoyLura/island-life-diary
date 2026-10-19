#ifndef __FOG_SH__
#define __FOG_SH__

#if COMPILEPS
vec3 GetFog(vec3 color, float fogFactor)
{
#ifdef MATERIAL_FOG_DISABLED
    return color;
#else
    return mix(cFogColor, color, fogFactor);
#endif
}

// A material override replaces distance/height fog. Additive light passes transmit
// their contribution; only the base pass contributes the fog color.
vec3 GetMaterialFog(vec3 color, float fogFactor, vec4 materialFog, bool additive)
{
#ifdef MATERIAL_FOG_DISABLED
    return color;
#elif defined(MATERIAL_CUSTOM_FOG)
    return color * (1.0 - materialFog.a) + (additive ? vec3_splat(0.0) : materialFog.rgb * materialFog.a);
#else
    return GetFog(color, fogFactor);
#endif
}

vec3 GetLitFog(vec3 color, float fogFactor)
{
#ifdef MATERIAL_FOG_DISABLED
    return color;
#else
    return color * fogFactor;
#endif
}
// fogfactor 是1-fog 的权重
// fogParams(depthFogStart, depthFogRange, depthFogDensity, 0.0);
// fogParams2(fogFalloff * fogScale / 100.0, fogHeight, fog.heightFogDensity_, 0.0);
float GetFogFactor(float distance)
{
#ifdef MATERIAL_FOG_DISABLED
    return 1.0;
#else
    vec3 param = cFogParams.xyz;
    float factor = clamp((distance - param.x)/param.y, 0.0, 1.0);
    return 1.0 - factor * param.z;
#endif
}

float GetHeightFogFactor(float distance, float height)
{
#ifdef MATERIAL_FOG_DISABLED
    return 1.0;
#else
    vec3 param = cFogParams2.xyz;
    float fogFactor = GetFogFactor(distance);
    float heightFogFactor = (height - param.y) * param.x;
    heightFogFactor = 1.0 - param.z *clamp(exp(-(heightFogFactor * heightFogFactor)),step(height, param.y) - 0.00001, 1.0);
    return min(heightFogFactor, fogFactor);
#endif
}

#endif

#endif

