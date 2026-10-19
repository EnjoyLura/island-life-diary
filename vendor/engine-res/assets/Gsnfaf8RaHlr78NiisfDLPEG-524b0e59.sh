#ifndef GI_HEADER_GUARD
#define GI_HEADER_GUARD
#include "MaterialEnvironment.sh"

hfloat GetLightRangeMask(hfloat radius, hfloat distSqr)
{
    hfloat w = 1.0 / radius;
    hfloat lightRadiusMask = Square(saturate(1.0 - Square(distSqr * w * w)));
    return lightRadiusMask;
}

hfloat GI_PointLight_GetAttenAndLightDir(hvec3 worldPos, hvec3 lightPos, hfloat radius, out vec3 lightDirection)
{
    hvec3 toLight = lightPos - worldPos;
    hfloat distSqr = dot(toLight, toLight);
    // <==> normalize(toLight)
    lightDirection = toLight / (sqrt(distSqr) + 1e-7);
    hfloat falloff = 1.0 / max(distSqr, 0.0001);
    return falloff * GetLightRangeMask(radius, distSqr);
}

hfloat GetLightDirectionFalloff(hvec3 L, hvec3 direction, float cosOuterCone, float invCosDiff)
{
    return Square(clamp((dot(direction, -L) - cosOuterCone) * invCosDiff, 0.0, 1.0));
}

#ifdef COMPILEPS
#if defined(ATMOSPHERE_SURFACE_LIGHT) && defined(DIRLIGHT) && defined(DEFERRED)
#include "Sky/SkyAtmosphereCommon.sh"
// Deferred reflections are separate; the view excludes experimental voxel shadows.
SAMPLER2D(u_AtmosphereSurfaceTransmittance5, 5);
uniform hfloat u_AtmosphereSurfaceLight;
#endif
#if !defined(DEFERRED) && !defined(MATERIAL_LIGHT_POSITION)
hvec3 GI_GetLightColor()
{
#if defined(SPOTLIGHT) && !defined(CLUSTER)
    return vSpotPos.w > 0.0 ? texture2DProj(sLightSpotMap, vSpotPos).rgb * cLightColor.rgb : hvec3_init(0.0, 0.0, 0.0);
#elif defined(CUBEMASK) && !defined(CLUSTER) && !defined(URHO3D_MOBILE)
    return textureCube(sLightCubeMap, vCubeMaskVec).rgb * cLightColor.rgb;
#else
    return cLightColor.rgb;
#endif
}
#endif

hvec3 GI_GetLightColor(hvec3 worldPos)
{
#if (defined(DEFERRED) || defined(MATERIAL_LIGHT_POSITION)) && defined(SPOTLIGHT) && !defined(CLUSTER)
    hvec4 spotPosition = mul(hvec4_init(worldPos, 1.0), cLightMatricesPS[0]);
    return spotPosition.w > 0.0 ? texture2DProj(sLightSpotMap, spotPosition).rgb * cLightColor.rgb : hvec3_init(0.0, 0.0, 0.0);
#elif (defined(DEFERRED) || defined(MATERIAL_LIGHT_POSITION)) && defined(CUBEMASK) && !defined(CLUSTER) && !defined(URHO3D_MOBILE)
    hvec3 cubeDirection = mul(worldPos - cLightPosPS.xyz,
                              hmat3_init(cLightMatricesPS[0][0].xyz, cLightMatricesPS[0][1].xyz, cLightMatricesPS[0][2].xyz));
    return textureCube(sLightCubeMap, cubeDirection).rgb * cLightColor.rgb;
#elif defined(ATMOSPHERE_SURFACE_LIGHT) && defined(DIRLIGHT) && defined(DEFERRED)
    if (u_AtmosphereSurfaceLight > 0.5)
        return cLightColor.rgb * SampleAtmosphereSunTransmittance((worldPos - u_AtmospherePlanetCenter.xyz) * 0.001,
            cLightDirPS, u_AtmosphereSurfaceTransmittance5);
    return cLightColor.rgb;
#elif defined(DEFERRED) || defined(MATERIAL_LIGHT_POSITION)
    return cLightColor.rgb;
#else
    return GI_GetLightColor();
#endif
}

hfloat GI_GetAttenAndLightDir(hvec3 worldPos, out vec3 lightDirection)
{
#if defined(DIRLIGHT)
    lightDirection = cLightDirPS;
    return 1.0;
#else
    hvec3 toLight = cLightPosPS.xyz - worldPos;
    hfloat distSqr = dot(toLight, toLight);
    // cLightPosPS.w is 1 / AttenuationRadius
    hfloat lightRadiusMask = Square(saturate(1.0 - Square(distSqr * cLightPosPS.w * cLightPosPS.w)));
    // <==> normalize(toLight)
    lightDirection = toLight / (sqrt(distSqr) + 1e-7);

    #if defined(RECTLIGHT)
        // RectLight: no 1/distSqr here — distance falloff is already in
        // RectIrradianceKaris (baseIrradiance ~ area/r²) and LTC integration.
        hfloat falloff = lightRadiusMask;
        // 单面剔除：cLightDirPS 是 BACK 方向（引擎约定），取反得到发射方向。
        // 二值剔除对齐 UE GetLocalLightAttenuation（dot < 0 ? 0 : mask）；余弦项已含在
        // Karis irradiance 的 saturate(dot(ax2, L)) 内，再乘软余弦会双重衰减
        falloff *= (dot(-cLightDirPS, -lightDirection) > 0.0) ? 1.0 : 0.0;
    #else
        hfloat falloff = lightRadiusMask / max(distSqr, 0.0001);
        #if defined(SPOTLIGHT)
            falloff *= GetLightDirectionFalloff(lightDirection, -cLightDirPS, cLightCosOuterCone, cLightInvCosConeDiff);
        #endif
    #endif

    return falloff;
#endif
}

// RENDER_QUALITY
// RENDER_QUALITY_LOW = 0
// RENDER_QUALITY_MEDIUM = 1
// RENDER_QUALITY_HIGH = 2
// RENDER_QUALITY_FULL = 3
// 注意以上值同C++一一对应
vec3 GI_IndirectDiffuse(vec3 normalDirection, float occlusion)
{
#ifdef MATERIAL_AMBIENT_DISABLED
    return vec3_splat(0.0);
#else
    vec3 indirectDiffuse;
    #if defined(ENVCUBE)
        // 分级                 |                  方案
        // WIN32 平台           | sh diffuse(L0L1L2) + specular cubemap
        // MOBILE 高端机        | sh diffuse(L0L1L2) + specular cubemap (size = 128)
        // MOBILE 中端机        | sh diffuse(L0L1L2) + specular cubemap (size = 64)
        // MOBILE 低端机        |   sh diffuse(L0L1) + specular cubemap (size = 64)
        // 目前来说采样EnvDiffuse已经意义不大了，使用球谐系数就够了
        // #if RENDER_QUALITY < RENDER_QUALITY_FULL
        #if 1
            #if UNITY_SHOULD_SAMPLE_SH
                vec3 cubeN = normalDirection;
                cubeN.zx = vec2(dot(cubeN.zx, vec2(u_SinCosEnvCubeAngle.y, -u_SinCosEnvCubeAngle.x)), dot(cubeN.zx, u_SinCosEnvCubeAngle.xy));
                indirectDiffuse = ShadeSHPerPixel(cubeN, cAmbientColor.rgb, cEnvDiffTextureIntensity);
            #else
                indirectDiffuse = cAmbientColor.rgb;
            #endif
        #else
            vec3 cubeN = normalDirection;
            cubeN.zx = vec2(dot(cubeN.zx, vec2(u_SinCosEnvCubeAngle.y, -u_SinCosEnvCubeAngle.x)), dot(cubeN.zx, u_SinCosEnvCubeAngle.xy));
            vec4 filterLambert = textureCube(sEnvDiffuse, cubeN);
            #ifndef URHO3D_MOBILE
                indirectDiffuse = filterLambert.xyz * cEnvDiffTextureIntensity  + cAmbientColor.xyz; // irradiance
            #else
            // 移动端使用RGBM编码
                indirectDiffuse = filterLambert.xyz * filterLambert.w * 6.0 * cEnvDiffTextureIntensity  + cAmbientColor.xyz; // irradiance
            #endif
        #endif
    #else
        indirectDiffuse = cAmbientColor.rgb;
    #endif

    indirectDiffuse = GetMaterialIrradiance(indirectDiffuse);
    return indirectDiffuse * occlusion * cAmbientOcclusionIntensity;
#endif
}

vec3 GI_IndirectSpecular(vec3 normalDirection, vec3 viewDirection, float perceptualRoughness, float occlusion)
{
#if defined(MATERIAL_AMBIENT_DISABLED) || defined(DEFERRED_REFLECTIONS)
    return vec3_splat(0.0);
#else
    vec3 indirectSpecular;
    #if defined(ENVCUBE)
        perceptualRoughness = perceptualRoughness * (1.7 - 0.7*perceptualRoughness);
        float mip = perceptualRoughness * 6.0; //  perceptualRoughness * UNITY_SPECCUBE_LOD_STEPS

        float NdotV = clamp(dot(normalDirection, viewDirection), 0.0, 1.0);
        vec3 viewReflection = 2.0 * NdotV * normalDirection - viewDirection; // Same as: -reflect(viewDirection, normalDirection);

        #if 1
            vec3 cubeR = viewReflection;
            cubeR.zx = vec2(dot(cubeR.zx, vec2(u_SinCosEnvCubeAngle.w, -u_SinCosEnvCubeAngle.z)), dot(cubeR.zx, u_SinCosEnvCubeAngle.zw));
            vec4 filterGGX = textureCubeLod(sEnvSpecular, cubeR, mip);
            #ifndef URHO3D_MOBILE
                indirectSpecular = filterGGX.xyz * cEnvSpecTextureIntensity + cAmbientColor.xyz; // radiance
            #else
            // 移动端使用RGBM编码
                indirectSpecular = filterGGX.xyz * filterGGX.w * 6.0 * cEnvSpecTextureIntensity + cAmbientColor.xyz; // radiance
            #endif
        #else
            // 渲染质量为RENDER_QUALITY_LOW时，高光使用球谐（粗糙度比较低的时候效果不好）
            indirectSpecular = vec3_splat(0.0);
        #endif
    #else
        indirectSpecular = vec3_splat(0.0);
    #endif

    occlusion = GetMaterialSpecularOcclusion(occlusion, viewDirection);
    indirectSpecular = GetMaterialRadiance(indirectSpecular);
    return indirectSpecular * occlusion * cAmbientOcclusionIntensity;
#endif
}

void GI_Indirect(vec3 normalDirection, vec3 viewDirection, float perceptualRoughness, float occlusion,
    out vec3 indirectDiffuse, out vec3 indirectSpecular)
{
    indirectDiffuse = GI_IndirectDiffuse(normalDirection, occlusion);
    indirectSpecular = GI_IndirectSpecular(normalDirection, viewDirection, perceptualRoughness, occlusion);
}
#endif

#endif // GI_HEADER_GUARD
