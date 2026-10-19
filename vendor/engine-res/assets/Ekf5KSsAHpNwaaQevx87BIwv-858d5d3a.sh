#ifndef TOON_SPECULAR_SH
#define TOON_SPECULAR_SH
#include "Toon/ToonUniforms.sh"

// Forward / Forward+：只有 litbase 带 AMBIENT，用它认出写底那一次。
// Deferred：每盏 Light Volume 都带 AMBIENT，改用 DIRLIGHT；平行光 Replace 覆盖，与旧链路一致。
// CLUSTER_BASE 是无真实太阳时的黑色载体，直接光已被关掉，不能当太阳。
#if defined(DIRLIGHT) && !defined(CLUSTER_BASE) && !defined(LIGHTVOLUME_BASE_ONLY) && (defined(AMBIENT) || defined(DEFERRED))
    #define TOON_FULL_SHADE
#endif

vec3 GetToonMainLightFactor(vec3 lightColor, float attenuation)
{
    vec3 factor = max(lightColor * attenuation, vec3_splat(0.0));
    return min(factor, max(cToonMainLightMax, vec3_splat(0.0)))
        * max(cToonMainLightMul, vec3_splat(0.0));
}

vec3 GetToonDirectSpecular(vec3 specularColor, float roughness, float perceptualRoughness,
    vec3 normalDirection, vec3 viewDirection, vec3 lightDirection)
{
    float NdotV = abs(dot(normalDirection, viewDirection));
    return GetSpecularColor(specularColor, roughness, perceptualRoughness,
        normalDirection, viewDirection, lightDirection, NdotV);
}

#endif
