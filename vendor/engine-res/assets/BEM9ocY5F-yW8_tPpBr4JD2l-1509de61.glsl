/*
 * SSR HiZ Trace Shader
 * UE-style screen-space ray cast over the UrhoX HiZ depth chain.
 *
 * SSR_LUMEN_TRACE selects Lumen closest-HZB traversal or the original fixed-step
 * SSRTRayCast-style trace. Ray generation, color sampling and outputs are shared.
 *
 * Output is pre-multiplied SSR color:
 *   RGB = reflected color * confidence
 *   A   = confidence
 */

#include "varying_quad.def.sc"
#include "urho3d_compatibility.sh"

#ifdef COMPILEVS
    $input a_position
    $output vTexCoord, vScreenPos
#endif
#ifdef COMPILEPS
    $input vTexCoord, vScreenPos
#endif

#include "Common/common.sh"
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
// Pull in the shared trace-pass samplers (MotionVector=4, SceneLighting=5,
// TAAHistory=6) and hit reprojection helpers from SSRCommon.sh.
#include "ScreenSpace/SSR/SSRTraceConfig.sh"
#define SSR_TRACE_PASS
#include "ScreenSpace/SSR/SSRCommon.sh"

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS

SAMPLER2D(u_Normal1, 1);
SAMPLER2D(u_GBufferB2, 2);
#ifdef DEFERRED_CLEAR_COAT
SAMPLER2D(u_ClearCoat7, 7);
#endif
#if SSR_LUMEN_TRACE
SAMPLER2D(u_ClosestHiZ9, 9);
// xy = HZB mip 0 texel size, z = last allocated mip.
uniform hvec4 u_SsrHZBParams;
// x = iteration budget, y = relative view-depth thickness.
uniform hvec2 u_LumenTraceParams;
#else
SAMPLER2D(u_FarthestHiZ3, 3);
#endif

uniform hfloat u_MaxDistance;
uniform hfloat u_MaxSteps;
uniform hfloat u_Thickness;
uniform hfloat u_NumRays;
uniform hfloat u_FrameIndex;

// Screen UV -> HZB UV factor (UE HZBUvFactorAndInvFactor semantics).
// The HZB is pow2half sized (RoundUpPow2(viewport)>>1), valid region = uv * factor;
// set by View::ApplyHiZSampleParameters
uniform hvec4 u_HZBUvFactor;

#define UE_SSR_MAX_ROUGHNESS 0.6
#define UE_SSR_ROUGHNESS_MASK_SCALE (-2.0 / UE_SSR_MAX_ROUGHNESS)
#define MAX_SSR_RAYS 12
#define MAX_TRACE_STEPS 64
#define MAX_HIZ_MIP 4.0

hvec3 SampleViewNormal(hvec2 uv)
{
    hvec3 worldNormal = DecodeGBufferNormal(texture2D(u_Normal1, uv).rgb);
    return normalize(mul(hvec4_init(worldNormal.x, worldNormal.y, worldNormal.z, 0.0), cView).xyz);
}

#define StoreSSRTraceResult(color, confusion) \
    gl_FragData[0] = color; \
    gl_FragData[1] = hvec4_init(confusion, 0.0, 0.0, 1.0)

#if SSR_LUMEN_TRACE
#include "ScreenSpace/SSR/LumenScreenTrace.sh"
#else
#include "ScreenSpace/SSR/SSRFixedStepTrace.sh"
#endif

void PS()
{
    hvec2 uv = vTexCoord;

    hfloat depth = texture2D(u_Depth0, uv).r;
    BRANCH
    if (IsSSRFarPlaneDepth(depth))
    {
        StoreSSRTraceResult(hvec4_init(0.0, 0.0, 0.0, 0.0), -1.0);
        return;
    }

    hvec3 normal = SampleViewNormal(uv);
    hvec4 gbufferB = texture2D(u_GBufferB2, uv);
    hfloat roughness = gbufferB.b;
    hfloat coatStrength = 0.0;
#ifdef DEFERRED_CLEAR_COAT
    if (uint(round(gbufferB.a * 255.0)) == SHADINGMODELID_CLEAR_COAT)
    {
        hvec4 coat = texture2D(u_ClearCoat7, uv);
        roughness = GetClearCoatSSRoughness(gbufferB, coat);
        coatStrength = coat.r;
    }
#endif
    hfloat metallic = gbufferB.r;

    hfloat roughnessFade = min(roughness * UE_SSR_ROUGHNESS_MASK_SCALE + 2.0, 1.0);
    BRANCH
    if (roughnessFade <= 0.0)
    {
        StoreSSRTraceResult(hvec4_init(0.0, 0.0, 0.0, 0.0), -1.0);
        return;
    }

    hfloat specular = gbufferB.g;
    BRANCH
    if (metallic < 0.01 && specular < 0.1 && coatStrength <= 0.0)
    {
        StoreSSRTraceResult(hvec4_init(0.0, 0.0, 0.0, 0.0), -1.0);
        return;
    }

    hvec3 viewPos = ReconstructViewPos(uv, depth);
    hvec3 viewDir = normalize(viewPos);
    hvec3 V = -viewDir;
    hfloat alpha = roughness * roughness;
    int baseMaxSteps = int(u_MaxSteps);
    int numRays = int(clamp(u_NumRays, 1.0, 12.0));
    int traceMaxSteps = baseMaxSteps;

    hvec2 pixelCoord = uv / cGBufferInvSize;
    hfloat noiseX = InterleavedGradientNoise(pixelCoord + u_FrameIndex * hvec2_init(32.665, 11.815));
    // UE re-randomizes the Hammersley scramble every frame via
    // Rand3DPCG16(PixelPos, StateFrameIndexMod8) so temporal accumulation converges the
    // GGX lobe. The frame index must be mixed in here, otherwise each pixel traces the
    // same ray directions forever and the noise becomes a static streak pattern.
    hfloat randomX = SsrHash13(hvec3_init(pixelCoord.x, pixelCoord.y, u_FrameIndex));
    hfloat randomY = SsrHash13(hvec3_init(pixelCoord.y + 17.0, pixelCoord.x + 43.0, u_FrameIndex));
    hvec3 tangentV = UEWorldToTangent(V, normal);

    BRANCH
    if (numRays > 1 && roughness < 0.1)
    {
#if !SSR_LUMEN_TRACE
        traceMaxSteps = min(baseMaxSteps * numRays, 24);
#endif
        numRays = 1;
    }

    hvec3 accumulatedRgb = hvec3_init(0.0, 0.0, 0.0);
    hfloat accumulatedAlpha = 0.0;
    hfloat closestHitDistance = 1.0e20;

    LOOP
    for (int rayIndex = 0; rayIndex < MAX_SSR_RAYS; rayIndex++)
    {
        BRANCH
        if (rayIndex >= numRays)
            break;

        hfloat stepOffset = noiseX - 0.5;
        hvec2 xi = HammersleyFloat(rayIndex, numRays, randomX, randomY);
        xi.y *= 1.0 - SSR_GGX_IMPORTANT_SAMPLE_BIAS;
        hvec3 H = UETangentToWorld(ImportanceSampleVisibleGGX(xi, alpha, tangentV), normal);
        hvec3 reflectDir = 2.0 * dot(V, H) * H - V;

        BRANCH
        if (roughness < 0.1)
            reflectDir = reflect(-V, normal);

        hvec2 hitUV;
        hfloat hitDepth;
        hfloat hitDistance;
        hfloat hitConfidence;
#if SSR_LUMEN_TRACE
        bool hit = ScreenSpaceRayCastLumen(viewPos, normal, reflectDir, hitUV, hitDepth, hitDistance, hitConfidence);
#else
        bool hit = ScreenSpaceRayCastUE(viewPos, reflectDir, roughness, traceMaxSteps, stepOffset, hitUV, hitDepth, hitDistance, hitConfidence);
#endif
        BRANCH
        if (hit)
        {
            hvec4 reflectSample = SampleSSRSceneColor(hitUV);
            hfloat sampleConfidence = reflectSample.a * hitConfidence;
            hvec3 sampleRgb = max(reflectSample.rgb, hvec3_init(0.0, 0.0, 0.0)) * hitConfidence;

            BRANCH
            if (numRays > 1)
                sampleRgb *= 1.0 / (1.0 + SsrLuminance(sampleRgb));

            accumulatedRgb += sampleRgb;
            accumulatedAlpha += sampleConfidence;
            closestHitDistance = min(closestHitDistance, hitDistance);
        }
    }

    hfloat invNumRays = 1.0 / hfloat_init(numRays);
    accumulatedRgb *= invNumRays;
    accumulatedAlpha *= invNumRays;

    BRANCH
    if (numRays > 1)
        accumulatedRgb *= 1.0 / max(1.0 - SsrLuminance(accumulatedRgb), 0.001);

    accumulatedRgb *= roughnessFade;
    accumulatedAlpha *= roughnessFade;

    // A traced miss is a valid zero-radiance sample (infinite hit distance -> 1).
    // Only pixels excluded from tracing use -1; otherwise misses erase temporal history.
    hfloat outputConfusion = closestHitDistance < 1.0e19 ? closestHitDistance / max(length(viewPos) + closestHitDistance, 0.0001) : 1.0;
    StoreSSRTraceResult(hvec4_init(accumulatedRgb.x, accumulatedRgb.y, accumulatedRgb.z, accumulatedAlpha), outputConfusion);
}

#endif
