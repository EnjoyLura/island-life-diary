// Shared legacy additive fog; cloud composition reuses the scene evaluator.
#ifndef VOLUMETRIC_FOG_INTEGRATION_SH
#define VOLUMETRIC_FOG_INTEGRATION_SH
uniform hvec4 u_VolumetricFogParams;            // density, height, height falloff, start distance
uniform hvec4 u_VolumetricFogParams2;           // view distance, max opacity, phase g, use shadow
uniform hvec4 u_VolumetricFogParams3;           // shaft contrast, edge threshold, edge softness, occlusion threshold
uniform hvec4 u_VolumetricFogParams4;           // ground fade height, ground fade range, distance fade length, surface fade range
uniform hvec4 u_VolumetricFogScatteringColor;   // rgb
uniform hvec4 u_VolumetricFogAbsorption;        // rgb, intensity
uniform hvec4 u_FroxelSkySH[3];                 // packed RGB L0+L1 diffuse irradiance SH
uniform hvec4 u_FroxelSkyParams;                // x = volumetric intensity, y = sin angle, z = cos angle
uniform hfloat u_FrameIndex;
uniform hvec2 u_JitterOffset;
uniform hmat4 u_InvViewProj;

#ifdef CLOUD_SHADOW
// CloudShadow is a pass-local sampler stage. It is intentionally separate from
// the regular CSM sampler and carries a light-aligned world projection.
SAMPLER2D(u_CloudShadow6, 6);
uniform hmat4 u_CloudShadowWorldToUV;
uniform hvec4 u_CloudShadowParams;
#include "Volumetric/VolumetricCloudShadowCommon.sh"
#endif

#define VOLUMETRIC_FOG_STEPS 32

#ifdef VSM_SHADOW
hfloat VolumetricReduceLightBleeding(hfloat minValue, hfloat pMax)
{
    return clamp((pMax - minValue) / (1.0 - minValue), 0.0, 1.0);
}

hfloat VolumetricChebyshev(hvec2 moments, hfloat depth)
{
    hfloat p = step(depth, moments.x);
    hfloat variance = max(moments.y - moments.x * moments.x, cVSMShadowParams.x);
    hfloat d = depth - moments.x;
    hfloat pMax = variance / (variance + d * d);
    pMax = VolumetricReduceLightBleeding(cVSMShadowParams.y, pMax);
    return max(p, pMax);
}
#endif

hfloat VolumetricSampleShadow(hvec4 shadowPos)
{
#ifndef MOBILE_SHADOW
    #if defined(SIMPLE_SHADOW)
        return shadow2DProj(sShadowMap, shadowPos);
    #elif defined(PCF_SHADOW)
        hvec2 offsets = cShadowMapInvSize * shadowPos.w;
        hvec4 inLight = hvec4_init(
            shadow2DProj(sShadowMap, shadowPos),
            shadow2DProj(sShadowMap, hvec4_init(shadowPos.x + offsets.x, shadowPos.yzw)),
            shadow2DProj(sShadowMap, hvec4_init(shadowPos.x, shadowPos.y + offsets.y, shadowPos.zw)),
            shadow2DProj(sShadowMap, hvec4_init(shadowPos.xy + offsets.xy, shadowPos.zw))
        );
        return dot(inLight, hvec4_init(0.25, 0.25, 0.25, 0.25));
    #elif defined(VSM_SHADOW)
        hvec2 samples = texture2D(sShadowMap, shadowPos.xy / shadowPos.w).rg;
        return VolumetricChebyshev(samples, shadowPos.z / shadowPos.w);
    #else
        return 1.0;
    #endif
#else
    #if defined(SIMPLE_SHADOW)
        return shadow2DProj(sShadowMap, shadowPos) * shadowPos.w > shadowPos.z ? 1.0 : 0.0;
    #elif defined(PCF_SHADOW)
        hvec2 offsets = cShadowMapInvSize;
        hvec4 inLight = hvec4_init(
            shadow2DProj(sShadowMap, shadowPos),
            shadow2DProj(sShadowMap, hvec4_init(shadowPos.x + offsets.x, shadowPos.yzw)),
            shadow2DProj(sShadowMap, hvec4_init(shadowPos.x, shadowPos.y + offsets.y, shadowPos.zw)),
            shadow2DProj(sShadowMap, hvec4_init(shadowPos.xy + offsets.xy, shadowPos.zw))
        );
        return dot(inLight, hvec4_init(0.25, 0.25, 0.25, 0.25));
    #elif defined(VSM_SHADOW)
        hvec2 samples = texture2D(sShadowMap, shadowPos.xy / shadowPos.w).rg;
        return VolumetricChebyshev(samples, shadowPos.z / shadowPos.w);
    #else
        return 1.0;
    #endif
#endif
}

hfloat VolumetricDirShadowFade(hfloat inLight, hfloat depth)
{
    return min(inLight + max((depth - cShadowDepthFade.z) * cShadowDepthFade.w, 0.0), 1.0);
}

#ifdef TEMPORAL_CSM
#include "TemporalShadow.sh"
#endif

hfloat VolumetricDirShadow(hvec4 worldPos, hfloat depth)
{
#ifndef SHADOW
    return 1.0;
#elif defined(TEMPORAL_CSM)
    if (u_TemporalShadowBlendEnd.w < 1.0)
        return 1.0;
    int split;
    hfloat weight;
    TemporalShadowSelect(depth, split, weight);
    hvec4 first = mul(worldPos, cLightMatricesPS[split]);
    bool firstValid = TemporalShadowPositionValid(first, split);
    hfloat visibility = firstValid ? VolumetricSampleShadow(first) : 1.0;
    if (weight > 0.0)
    {
        hvec4 second = mul(worldPos, cLightMatricesPS[split + 1]);
        bool secondValid = TemporalShadowPositionValid(second, split + 1);
        hfloat secondVisibility = secondValid ? VolumetricSampleShadow(second) : 1.0;
        visibility = TemporalShadowBlendVisibility(visibility, secondVisibility, firstValid, secondValid, weight);
    }
    return VolumetricDirShadowFade(visibility, depth);
#else
#if defined(DESKTOP_SHADOW_CASCADE)
    hvec4 shadowPos;
    if (depth < cShadowSplits.x)
        shadowPos = mul(worldPos, cLightMatricesPS[0]);
    else if (depth < cShadowSplits.y)
        shadowPos = mul(worldPos, cLightMatricesPS[1]);
    else if (depth < cShadowSplits.z)
        shadowPos = mul(worldPos, cLightMatricesPS[2]);
    else
        shadowPos = mul(worldPos, cLightMatricesPS[3]);
#elif defined(MOBILE_SHADOW_CASCADE)
    hvec4 shadowPos;
    if (depth < cShadowSplits.x)
        shadowPos = mul(worldPos, cLightMatricesPS[0]);
    else
        shadowPos = mul(worldPos, cLightMatricesPS[1]);
#else
    hvec4 shadowPos = mul(worldPos, cLightMatricesPS[0]);
#endif

    return VolumetricDirShadowFade(VolumetricSampleShadow(shadowPos), depth);
#endif
}

hfloat VolumetricShadowOcclusion(hfloat shadow)
{
    return saturate(1.0 - shadow);
}

#ifdef CLOUD_SHADOW
hfloat VolumetricCloudShadow(hvec3 worldPos)
{
    return SampleCloudShadow(worldPos, u_CloudShadowWorldToUV, u_CloudShadowParams.x, u_CloudShadow6);
}
#endif

#ifdef VOLUMETRIC_FOG_SHAFT
hfloat VolumetricReceiverFade(hvec3 samplePos, hvec3 receiverPos, hvec3 lightTravelDir, hfloat fadeRange)
{
    if (fadeRange <= 0.0001)
        return 1.0;

    hfloat receiverDistance = max(dot(receiverPos - samplePos, lightTravelDir), 0.0);
    return smoothstep(0.0, fadeRange, receiverDistance);
}
#endif

hvec4 ReconstructWorldPosition(hvec2 uv, hfloat depth)
{
    hvec4 clipPos = ScreenUVToClip(uv, depth);
    hvec4 worldPos = mul(clipPos, u_InvViewProj);
    return worldPos / worldPos.w;
}

hfloat VolumetricHeightDensity(hvec3 worldPos)
{
    hfloat heightTerm = (u_VolumetricFogParams.y - worldPos.y) * u_VolumetricFogParams.z;
    return u_VolumetricFogParams.x * exp2(clamp(heightTerm, -20.0, 20.0));
}

hfloat HenyeyGreenstein(hfloat cosTheta, hfloat g)
{
    hfloat g2 = g * g;
    hfloat denom = max(1.0 + g2 - 2.0 * g * cosTheta, 0.0001);
    return (1.0 - g2) / (12.5663706144 * denom * sqrt(denom));
}

hvec3 VolumetricEvaluateSkyLight(hvec3 rayDir, hfloat phaseG)
{
    if (u_FroxelSkyParams.x <= 0.0)
        return hvec3_init(0.0, 0.0, 0.0);

    hvec3 skyDirection = rayDir * -phaseG;
    skyDirection.zx = hvec2_init(
        dot(skyDirection.zx, hvec2_init(u_FroxelSkyParams.z, -u_FroxelSkyParams.y)),
        dot(skyDirection.zx, u_FroxelSkyParams.yz));
    hvec4 shDirection = hvec4_init(skyDirection, 1.0);
    hvec3 skyLighting = hvec3_init(
        dot(u_FroxelSkySH[0], shDirection),
        dot(u_FroxelSkySH[1], shDirection),
        dot(u_FroxelSkySH[2], shDirection));
    return max(skyLighting, hvec3_init(0.0, 0.0, 0.0)) * u_FroxelSkyParams.x;
}

/// Evaluate the existing additive fullscreen fog at a caller-supplied receiver.
hvec3 EvaluateLegacyVolumetricFog(hvec2 uv, hvec3 cameraPos, hvec3 scenePosition)
{
    hvec3 ray = scenePosition - cameraPos;
    hfloat sceneDistance = length(ray);
    if (sceneDistance <= 0.0001)
        return hvec3_init(0.0, 0.0, 0.0);
    hvec3 rayDir = ray / sceneDistance;
    hfloat startDistance = min(u_VolumetricFogParams.w, sceneDistance);
    hfloat endDistance = min(sceneDistance, u_VolumetricFogParams2.x);
    hfloat rayLength = endDistance - startDistance;
    if (rayLength <= 0.0001)
    {
        return hvec3_init(0.0, 0.0, 0.0);
    }

    hvec2 pixelCoord = uv / cGBufferInvSize + u_JitterOffset;
    hfloat jitter = InterleavedGradientNoise(pixelCoord + hvec2_init(u_FrameIndex * 17.0, u_FrameIndex * 29.0));
    hfloat stepLength = rayLength / hfloat_init(VOLUMETRIC_FOG_STEPS);
    hfloat phase = 0.0;
    hfloat useShadow = 0.0;
#ifdef DIRLIGHT
    hfloat cosTheta = dot(normalize(cLightDirPS), rayDir);
    phase = HenyeyGreenstein(cosTheta, u_VolumetricFogParams2.z);
    useShadow = u_VolumetricFogParams2.w;
#endif
#ifdef VOLUMETRIC_FOG_SHAFT
    hfloat shaftContrast = saturate(u_VolumetricFogParams3.x);
    hfloat shaftGroundFadeHeight = u_VolumetricFogParams4.x;
    hfloat shaftGroundFadeRange = max(u_VolumetricFogParams4.y, 0.0);
    hfloat shaftDistanceFadeLength = max(u_VolumetricFogParams4.z, 0.0);
    hfloat shaftSurfaceFadeRange = max(u_VolumetricFogParams4.w, 0.0);
    hfloat shaftEdgeThreshold = saturate(u_VolumetricFogParams3.y);
    hfloat shaftEdgeSoftness = max(u_VolumetricFogParams3.z, 0.0001);
    hfloat shaftOcclusionThreshold = saturate(u_VolumetricFogParams3.w);
#endif

    hvec3 transmittance = hvec3_init(1.0, 1.0, 1.0);
    hvec3 scattering = hvec3_init(0.0, 0.0, 0.0);
    hvec3 skyScattering = hvec3_init(0.0, 0.0, 0.0);
    hvec3 scatteringColor = hvec3_init(0.0, 0.0, 0.0);
#ifdef DIRLIGHT
    scatteringColor = u_VolumetricFogScatteringColor.rgb * cLightColor.rgb;
#endif
    hvec3 skyScatteringColor =
        u_VolumetricFogScatteringColor.rgb * VolumetricEvaluateSkyLight(rayDir, u_VolumetricFogParams2.z);
    hvec3 absorptionColor = u_VolumetricFogAbsorption.rgb * u_VolumetricFogAbsorption.w;
#ifdef VOLUMETRIC_FOG_SHAFT
    hfloat shadowOcclusionMin = 1.0;
    hfloat shadowOcclusionMax = 0.0;
    hfloat shadowOcclusionSum = 0.0;
    hfloat receiverFadeRange = shaftDistanceFadeLength;
    hfloat shaftRunFadeRange = shaftSurfaceFadeRange;
    hvec3 lightTravelDir = -normalize(cLightDirPS);
    hfloat shaftLitRun = shaftRunFadeRange;
#endif

    // Keep four depth-edge evaluations from expanding all shadow taps in FXC.
    LOOP for (int i = 0; i < VOLUMETRIC_FOG_STEPS; ++i)
    {
        hfloat sampleDistance = startDistance + (hfloat_init(i) + jitter) * stepLength;
        hvec3 samplePos = cameraPos + rayDir * sampleDistance;
        hfloat density = VolumetricHeightDensity(samplePos);

        hfloat shadow = 0.0;
#ifdef DIRLIGHT
        hvec4 sampleWorld = hvec4_init(samplePos.x, samplePos.y, samplePos.z, 1.0);
        hfloat viewDepth01 = saturate(sampleDistance / max(cFarClipPS, 0.0001));
        shadow = lerp(1.0, VolumetricDirShadow(sampleWorld, viewDepth01), useShadow);
#ifdef CLOUD_SHADOW
        shadow *= VolumetricCloudShadow(samplePos);
#endif
#endif
#ifdef VOLUMETRIC_FOG_SHAFT
        hfloat shadowOcclusion = VolumetricShadowOcclusion(shadow);
        shadowOcclusion = lerp(0.0, shadowOcclusion, useShadow);
        shadowOcclusionMin = min(shadowOcclusionMin, shadowOcclusion);
        shadowOcclusionMax = max(shadowOcclusionMax, shadowOcclusion);
        shadowOcclusionSum += shadowOcclusion;
#endif

        hvec3 extinction = hvec3_init(density, density, density) + absorptionColor * density;
        hvec3 stepTransmittance = exp(-extinction * stepLength);
#ifdef VOLUMETRIC_FOG_SHAFT
        hfloat shaftGroundFade = 1.0;
        if (shaftGroundFadeRange > 0.0001)
            shaftGroundFade = smoothstep(shaftGroundFadeHeight, shaftGroundFadeHeight + shaftGroundFadeRange, samplePos.y);
        hfloat shaftDistanceFade = 1.0;
        if (receiverFadeRange > 0.0001)
            shaftDistanceFade = VolumetricReceiverFade(samplePos, scenePosition, lightTravelDir, receiverFadeRange);
        if (shaftRunFadeRange > 0.0001)
        {
            hfloat shadowReset = smoothstep(shaftOcclusionThreshold, shaftOcclusionThreshold + shaftEdgeSoftness, shadowOcclusion);
            shaftLitRun = lerp(shaftLitRun + stepLength, 0.0, shadowReset);
            hfloat shaftRunFade = 1.0 - smoothstep(shaftRunFadeRange * 0.25, shaftRunFadeRange, shaftLitRun);
            shaftDistanceFade = min(shaftDistanceFade, shaftRunFade);
        }
        hfloat shaftFadeWeight = shaftContrast * useShadow;
        hfloat sampleShaftFade = 1.0 + shaftFadeWeight * (shaftGroundFade * shaftDistanceFade - 1.0);
#endif

#ifdef VOLUMETRIC_FOG_SHAFT
        scattering += transmittance * scatteringColor * (density * phase * shadow * stepLength * sampleShaftFade);
#else
        scattering += transmittance * scatteringColor * (density * phase * shadow * stepLength);
#endif

        skyScattering += transmittance * skyScatteringColor * (density * stepLength);
        transmittance *= stepTransmittance;
    }

#ifdef VOLUMETRIC_FOG_SHAFT
    // MC-like shafts need shadow variation along the ray. Uniformly lit outdoor fog is suppressed here.
    hfloat shadowOcclusionRange = max(shadowOcclusionMax - shadowOcclusionMin, 0.0);
    hfloat shadowOcclusionMean = shadowOcclusionSum / hfloat_init(VOLUMETRIC_FOG_STEPS);
    hfloat mixedShadowAmount = min(shadowOcclusionMean, 1.0 - shadowOcclusionMean);
    hfloat edgeMask = smoothstep(shaftEdgeThreshold, shaftEdgeThreshold + shaftEdgeSoftness, shadowOcclusionRange);
    hfloat mixedMask = smoothstep(shaftOcclusionThreshold, shaftOcclusionThreshold + shaftEdgeSoftness * 0.5, mixedShadowAmount);
    hfloat shaftMask = lerp(1.0, edgeMask * mixedMask, useShadow);
    scattering *= lerp(1.0, shaftMask, shaftContrast);
#endif
    scattering += skyScattering;
    scattering *= u_VolumetricFogParams2.y;
    return scattering;
}
#endif
