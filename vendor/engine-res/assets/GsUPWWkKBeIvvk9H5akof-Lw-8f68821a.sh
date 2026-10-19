/*
 * SSR Common Functions
 * Shared utilities for Screen Space Reflections
 *
 * All computations use full precision (hfloat/hvec*) to avoid fp16 artifacts.
 */

#ifndef SSR_COMMON_SH
#define SSR_COMMON_SH

#include "ScreenSpace/ScreenSpaceCommon.sh"

#ifdef COMPILEPS
// Current/previous projection jitter in pixels. Velocity itself excludes jitter.
uniform hvec4 u_SsrJitterOffset;

hvec4 SsrRasterJitterUV()
{
    hvec4 jitter = u_SsrJitterOffset * cGBufferInvSize.xyxy;
#if !BGFX_SHADER_LANGUAGE_GLSL
    jitter.y = -jitter.y;
    jitter.w = -jitter.w;
#endif
    return jitter;
}
#endif

// Screen edge mask (UE4 ScreenSpaceReflections.usf)
// Applied to hit UV to fade reflections found near screen borders.
hfloat CalculateEdgeFade(hvec2 uv)
{
    hvec2 edgeDist = min(uv, 1.0 - uv);
    hfloat edge = min(edgeDist.x, edgeDist.y);
    return saturate(edge * 6.0);
}

// Roughness-based fade
hfloat CalculateRoughnessFade(hfloat roughness, hfloat maxRoughness)
{
    return 1.0 - saturate(roughness / maxRoughness);
}

// Spatial hash noise for temporal jitter (step offset along ray)
hfloat SsrSpatialHash(hvec2 screenPos)
{
    hvec3 p3 = fract(hvec3_init(screenPos.x, screenPos.y, screenPos.x + screenPos.y) * hvec3_init(0.1031, 0.1030, 0.0973));
    p3 += hvec3_init(dot(p3, p3.yzx + 33.33), dot(p3, p3.yzx + 33.33), dot(p3, p3.yzx + 33.33));
    return fract((p3.x + p3.y) * p3.z);
}

// ============================================================
// UE-style Monte Carlo helpers (MonteCarlo.ush / RandomPCG.ush)
// ============================================================

void GetUETangentBasis(hvec3 tangentZ, out hvec3 tangentX, out hvec3 tangentY)
{
    hfloat signZ = tangentZ.z >= 0.0 ? 1.0 : -1.0;
    hfloat a = -1.0 / (signZ + tangentZ.z);
    hfloat b = tangentZ.x * tangentZ.y * a;

    tangentX = hvec3_init(1.0 + signZ * a * tangentZ.x * tangentZ.x, signZ * b, -signZ * tangentZ.x);
    tangentY = hvec3_init(b, signZ + a * tangentZ.y * tangentZ.y, -tangentZ.y);
}

hvec3 UETangentToWorld(hvec3 value, hvec3 tangentZ)
{
    hvec3 tangentX;
    hvec3 tangentY;
    GetUETangentBasis(tangentZ, tangentX, tangentY);
    return tangentX * value.x + tangentY * value.y + tangentZ * value.z;
}

hvec3 UEWorldToTangent(hvec3 value, hvec3 tangentZ)
{
    hvec3 tangentX;
    hvec3 tangentY;
    GetUETangentBasis(tangentZ, tangentX, tangentY);
    return hvec3_init(dot(value, tangentX), dot(value, tangentY), dot(value, tangentZ));
}

// UE SSDPublic.ush GGX_IMPORTANT_SAMPLE_BIAS: truncating the top 10% of the GGX tail
// removes the outlier ray directions responsible for most of the sparkle noise, at the
// cost of a slightly narrower lobe.
#define SSR_GGX_IMPORTANT_SAMPLE_BIAS 0.1

// [Hoskins 2014, "Hash without Sine"] Float-only hashes (no uint bit ops, see
// HammersleyFloat below). Much lower pixel/frame correlation than sin-based hashes,
// which matters for TAA convergence of the stochastic ray directions.
hfloat SsrHash12(hvec2 p)
{
    hvec3 p3 = fract(hvec3_init(p.x, p.y, p.x) * 0.1031);
    p3 += dot(p3, hvec3_init(p3.y, p3.z, p3.x) + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

hfloat SsrHash13(hvec3 p)
{
    hvec3 p3 = fract(p * 0.1031);
    p3 += dot(p3, hvec3_init(p3.z, p3.y, p3.x) + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

hfloat RadicalInverseBase2Small(int index)
{
    hfloat value = 0.0;

    BRANCH
    if (index == 1) value = 0.5;
    else if (index == 2) value = 0.25;
    else if (index == 3) value = 0.75;
    else if (index == 4) value = 0.125;
    else if (index == 5) value = 0.625;
    else if (index == 6) value = 0.375;
    else if (index == 7) value = 0.875;
    else if (index == 8) value = 0.0625;
    else if (index == 9) value = 0.5625;
    else if (index == 10) value = 0.3125;
    else if (index == 11) value = 0.8125;

    return value;
}

// Float-only Hammersley variant to avoid DXBC parser issues with uint bit ops.
hvec2 HammersleyFloat(int index, int numSamples, hfloat randomX, hfloat randomY)
{
    hfloat e1 = fract(hfloat_init(index) / hfloat_init(numSamples) + randomX);
    hfloat e2 = fract(RadicalInverseBase2Small(index) + randomY);
    return hvec2_init(e1, e2);
}

// GGX/Trowbridge-Reitz NDF importance sampling.
hvec3 ImportanceSampleGGX(hvec2 xi, hfloat roughness)
{
    hfloat a = roughness * roughness;
    hfloat a2 = a * a;

    hfloat phi = 2.0 * 3.14159265 * xi.x;
    hfloat cosTheta = sqrt((1.0 - xi.y) / (1.0 + (a2 - 1.0) * xi.y));
    hfloat sinTheta = sqrt(max(1.0 - cosTheta * cosTheta, 0.0));

    return hvec3_init(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

// UE 5.5 MonteCarlo.ush ImportanceSampleVisibleGGX, scalar alpha variant.
hvec3 ImportanceSampleVisibleGGX(hvec2 xi, hfloat alpha, hvec3 viewDirTangent)
{
    hvec3 vh = normalize(hvec3_init(alpha * viewDirTangent.x, alpha * viewDirTangent.y, viewDirTangent.z));

    hfloat phi = 2.0 * 3.14159265 * xi.x;
    hfloat a = saturate(alpha);
    hfloat s = 1.0 + length(viewDirTangent.xy);
    hfloat a2 = a * a;
    hfloat s2 = s * s;
    hfloat k = (s2 - a2 * s2) / (s2 + a2 * viewDirTangent.z * viewDirTangent.z);

    hfloat z = mix(1.0, -k * vh.z, xi.y);
    hfloat sinTheta = sqrt(saturate(1.0 - z * z));
    hfloat x = sinTheta * cos(phi);
    hfloat y = sinTheta * sin(phi);
    hvec3 h = hvec3_init(x, y, z) + vh;

    return normalize(hvec3_init(alpha * h.x, alpha * h.y, max(0.0, h.z)));
}

// Backward-compatible name used by older SSR code.
hvec3 TangentToWorld(hvec3 value, hvec3 tangentZ)
{
    return UETangentToWorld(value, tangentZ);
}

// Relative luminance of linear RGB.
hfloat SsrLuminance(hvec3 color)
{
    return dot(color, hvec3_init(0.2126, 0.7152, 0.0722));
}

// Project a view-space position to (uv, deviceZ), matching the depth buffer convention.
hvec3 ProjectViewToUVZ(hvec3 viewPos)
{
    hvec4 clipPos = mul(hvec4_init(viewPos.x, viewPos.y, viewPos.z, 1.0), cProj);
    hvec3 ndc = clipPos.xyz / clipPos.w;
    hvec2 uv = ndc.xy * 0.5 + 0.5;
#if !BGFX_SHADER_LANGUAGE_GLSL
    uv.y = 1.0 - uv.y;
#endif
#if BGFX_SHADER_LANGUAGE_GLSL
    ndc.z = ndc.z * 0.5 + 0.5;
#endif
    return hvec3_init(uv.x, uv.y, ndc.z);
}

bool IsSSRFarPlaneDepth(hfloat deviceZ)
{
    return IsSceneFarDepth(deviceZ, 0.0001);
}

hfloat ClipRayToScreen(hvec2 originUV, hvec2 rayUV)
{
    hfloat t = 1.0;

    BRANCH
    if (rayUV.x > 0.0001)
        t = min(t, (1.0 - originUV.x) / rayUV.x);
    else if (rayUV.x < -0.0001)
        t = min(t, -originUV.x / rayUV.x);

    BRANCH
    if (rayUV.y > 0.0001)
        t = min(t, (1.0 - originUV.y) / rayUV.y);
    else if (rayUV.y < -0.0001)
        t = min(t, -originUV.y / rayUV.y);

    return saturate(t);
}

// UE SSRTRayCast.ush ComputeHitVignetteFromScreenPos, in UV space.
// Shared by the trace passes and the HCB reduction (SSRTPrevFrameReduction.usf:210).
hfloat ComputeHitVignette(hvec2 uv)
{
    hvec2 screen = uv * 2.0 - 1.0;
    hvec2 vignette = saturate(abs(screen) * 5.0 - 4.0);
    return saturate(1.0 - dot(vignette, vignette));
}

// ============================================================
// Trace-pass shared resources (SSRHiZTrace / SSRLinearTrace)
// Guarded so the denoise passes that include this header don't inherit the
// sampler bindings. Trace shaders must `#define SSR_TRACE_PASS` before including,
// and the render path must bind MotionVector=4, SceneLighting=5, TAAHistory=6.
// ============================================================
#if defined(COMPILEPS) && defined(SSR_TRACE_PASS)

SAMPLER2D(u_Depth0, 0);
SAMPLER2D(u_MotionVector4, 4);
SAMPLER2D(u_SceneLighting5, 5);
SAMPLER2D(u_PrevSceneColor6, 6);
SAMPLER2D(u_SceneDepthHistory10, 10);
// x = depth + TAA color validity, yz = previous raster jitter in UV units,
// w = relative previous-view depth tolerance. The depth history itself is effect-independent.
uniform hvec4 u_SceneDepthHistoryParams;
uniform hmat4 u_SceneDepthClipToPrevClip;
uniform hmat4 u_SceneDepthHistoryInvProj;

uniform hfloat u_PrevSceneColorPreExposureCorrection;
// 反射取色源开关（View::ApplySSRParameters 从 Zone.ssrUsePrevFrameColor 下发）：
// 1（默认，UE 行为）= 上一帧 TAA 输出——时域滤波过、噪声低、有反射中反射，
//   但运动物体倒影有拖影反馈环（SSR 拖影→SceneColor→TAAHistory→下帧再取色）；
// 0 = 统一反射合成前的当前帧 SceneLighting，保留逐命中点回退，
//   代价是亮环境反射噪声/闪烁增加（无 AA、无时域预滤波）、无反射中反射。
// 取证与权衡：docs/plans/temporal-ghosting-ue5-solutions.md §5.3.5
uniform hfloat u_SSRUsePrevFrameColor;

// Lumen-style historical hit validation adapted to UrhoX's RG velocity.
// MotionVector stores unjittered current UV - previous UV.
// Return confidence directly: nested bool returns break HLSLcc in the complete trace shader.
hfloat ReprojectHitToPrevSceneColor(hvec2 hitUV, out hvec2 prevUV)
{
    hvec2 motion = texture2DLod(u_MotionVector4, hitUV, 0.0).rg;
    // The hit is on the current raster grid, but TAAHistory is unjittered.
    prevUV = hitUV - SsrRasterJitterUV().xy - motion;

    hfloat vignette = min(ComputeHitVignette(hitUV), ComputeHitVignette(prevUV));
    // Keep early rejection explicit before sampling history.
    BRANCH
    if (u_SceneDepthHistoryParams.x < 0.5 || vignette <= 0.0)
        return 0.0;

    hvec2 unjitteredUV = hitUV - SsrRasterJitterUV().xy;
    hfloat surfaceZ = texture2DLod(u_Depth0, hitUV, 0.0).r;
    hvec4 previousClip = mul(ScreenUVToClip(unjitteredUV, surfaceZ), u_SceneDepthClipToPrevClip);
    BRANCH
    if (previousClip.w <= 1.0e-6)
        return 0.0;
    hvec3 previousNdc = previousClip.xyz / previousClip.w;
    hvec2 cameraPreviousUV = previousNdc.xy * 0.5 + 0.5;
#if (BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC)
    previousNdc.z = previousNdc.z * 0.5 + 0.5;
#else
    cameraPreviousUV.y = 1.0 - cameraPreviousUV.y;
#endif
    // RG velocity has no previous device Z. Reject detected object motion rather
    // than applying a static-world depth prediction to a moving surface.
    hvec2 objectPixels = (prevUV - cameraPreviousUV) / cGBufferInvSize;
    BRANCH
    if (dot(objectPixels, objectPixels) > 0.0625 || previousNdc.z < 0.0 || previousNdc.z > 1.0)
        return 0.0;
    hvec2 previousJitter = u_SceneDepthHistoryParams.yz;
#if !(BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC)
    previousJitter.y = -previousJitter.y;
#endif
    hvec2 depthUV = prevUV + previousJitter;
    BRANCH
    if (any(lessThan(depthUV, hvec2_init(0.0, 0.0))) || any(greaterThanEqual(depthUV, hvec2_init(1.0, 1.0))))
        return 0.0;
    hfloat historyZ = texture2DLod(u_SceneDepthHistory10, depthUV, 0.0).r;
    hvec4 expected = mul(ScreenUVToClip(prevUV, previousNdc.z), u_SceneDepthHistoryInvProj);
    hvec4 actual = mul(ScreenUVToClip(prevUV, historyZ), u_SceneDepthHistoryInvProj);
    BRANCH
    if (abs(expected.w) < 1.0e-8 || abs(actual.w) < 1.0e-8)
        return 0.0;
    hfloat expectedZ = expected.z / expected.w;
    hfloat actualZ = actual.z / actual.w;
    return expectedZ > 0.0 && abs(actualZ - expectedZ) <= u_SceneDepthHistoryParams.w * expectedZ ? vignette : 0.0;
}

// Hit color，按 u_SSRUsePrevFrameColor 二选一（见上方 uniform 注释与文档 §5.3.5）：
// - prev 路径：hit 点通过历史深度验证后采上一帧 TAA 输出，失败使用下方 current 路径
// - current 路径：反射合成前的 SceneLighting（直接光+自发光；
//   IBL diffuse 在 SSGI 关闭时已并入 SceneLighting，SSGI 开启时缺失属已知取舍）
hvec4 SampleSSRSceneColor(hvec2 hitUV)
{
    BRANCH
    if (u_SSRUsePrevFrameColor > 0.5)
    {
        hvec2 prevUV;
        hfloat vignette = ReprojectHitToPrevSceneColor(hitUV, prevUV);
        BRANCH
        if (vignette > 0.0)
        {
            hvec3 color = texture2D(u_PrevSceneColor6, prevUV).rgb * u_PrevSceneColorPreExposureCorrection;
            return hvec4_init(color.x * vignette, color.y * vignette, color.z * vignette, vignette);
        }
    }

    hvec3 color = texture2D(u_SceneLighting5, hitUV).rgb;
    hfloat vignette = ComputeHitVignette(hitUV);
    return hvec4_init(color.x * vignette, color.y * vignette, color.z * vignette, vignette);
}

#endif // COMPILEPS && SSR_TRACE_PASS
#endif // SSR_COMMON_SH
