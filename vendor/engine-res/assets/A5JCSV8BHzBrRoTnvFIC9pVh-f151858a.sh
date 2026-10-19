#ifndef MOBILE_SSR_SH
#define MOBILE_SSR_SH

// UrhoX additions to UE mobile SSR. Default off for frame rate; set to 1 in pixel shader defines to opt in.
#ifndef URHOX_MOBILE_SSR_HIT_PATCHES
#define URHOX_MOBILE_SSR_HIT_PATCHES 0
#endif

#include "ScreenSpace/MotionVector/CameraReprojection.sh"
SAMPLER2D_PRECISION(u_MobileHZB2, 2, highp);
SAMPLER2D(u_MobileHistory3, 3);
SAMPLER2D(u_MobileMotion4, 4);
// Intensity (zero for invalid history), pre-exposure correction, max roughness, 2/max roughness.
uniform hvec4 u_MobileSSRParams;
// Highest available mip, number of steps, velocity availability, temporal noise index.
uniform hvec4 u_MobileSSRTrace;
uniform hvec4 u_MobileSSRHistoryBounds;
#if URHOX_MOBILE_SSR_HIT_PATCHES
// Thickness in world units; zero bypasses validation at runtime, not the compiled A/B switch.
uniform hfloat u_Thickness;
#endif
uniform hvec4 u_HZBUvFactor;
#ifdef MOBILE_SSR_PREVIOUS_HZB
// Previous projection jitter (pixels / full view size). This uniform also declares the history-depth contract.
uniform hvec2 u_MobileSSRHistoryJitter;
#endif

hvec4 MobileProjectView(hvec3 position)
{
    hvec4 clip = mul(hvec4_init(position, 1.0), cProj);
#ifdef MOBILE_SSR_PREVIOUS_HZB
    // Trace against the previous raster's actual geometry, not the current view's mesh-only prepass.
    clip.xy -= u_CameraJitterOffset * (2.0 * clip.w);
    clip = mul(clip, u_CameraClipToPrevClip);
    clip.xy += u_MobileSSRHistoryJitter * (2.0 * clip.w);
#endif
    hvec3 ndc = clip.xyz / max(clip.w, 1e-8);
    hvec2 uv = ndc.xy * 0.5 + 0.5;
#if BGFX_SHADER_LANGUAGE_GLSL
    ndc.z = ndc.z * 0.5 + 0.5;
#else
    uv.y = 1.0 - uv.y;
#endif
    return hvec4_init(uv, ndc.z, clip.w);
}

hfloat MobileRayBorderFactor(hvec2 uv, hvec2 stepUV)
{
    // UE GetStepScreenFactorToClipAtScreenEdge, expressed in normalized screen coordinates.
    hvec2 start = uv * 2.0 - 1.0;
    hvec2 step = stepUV * 2.0;
    hfloat inverseFactor = 0.5 * length(step);
    hvec2 scale = 1.0 - max(abs(step + start * inverseFactor) - inverseFactor, hvec2_init(0.0, 0.0)) /
        max(abs(step), hvec2_init(1e-8, 1e-8));
    return min(scale.x, scale.y) / max(inverseFactor, 1e-8);
}

#if URHOX_MOBILE_SSR_HIT_PATCHES
// Resolve a candidate in the finest geometry available to this profile.
// This remains a sampled prepass/history resource, never a tile-local GBuffer fetch.
hfloat MobileSSRSurfaceDepth(hvec2 uv)
{
#ifdef MOBILE_SSR_PREVIOUS_HZB
    return texture2DLod(u_MobileHZB2, uv * u_HZBUvFactor.xy, 0.0).r;
#else
    return texture2DLod(u_MobileDepth0, uv, 0.0).r;
#endif
}

hfloat MobileSSRDepthDifference(hvec3 position)
{
    hfloat surface = MobileSSRSurfaceDepth(position.xy);
#ifdef REVERSED_Z
    return surface - position.z;
#else
    return position.z - surface;
#endif
}

bool MobileSSRRefineHit(hvec3 origin, hvec3 step, hfloat lowerTime, hfloat upperTime, out hvec3 hit)
{
    hit = origin;
    // The first interval starts at the unjittered ray origin. Starting at the jittered
    // point can skip the entire contact intersection before the first coarse sample.
    hvec3 lowerPosition = origin + step * lowerTime;
    hfloat lowerDepth = lowerTime > 0.0 ? MobileSSRSurfaceDepth(lowerPosition.xy) : lowerPosition.z;
#ifdef REVERSED_Z
    hfloat lowerDifference = lowerDepth - lowerPosition.z;
#else
    hfloat lowerDifference = lowerPosition.z - lowerDepth;
#endif
    hvec3 upperPosition = origin + step * upperTime;
    hfloat upperDepth = MobileSSRSurfaceDepth(upperPosition.xy);
#ifdef REVERSED_Z
    hfloat upperDifference = upperDepth - upperPosition.z;
#else
    hfloat upperDifference = upperPosition.z - upperDepth;
#endif
    // A step can cross an object and exit into either sky or more distant geometry.
    // Search relative to the ray endpoint, not a special far-depth/sky value.
    if (upperDifference <= 0.0)
    {
        hfloat surfaceTime = lowerTime;
        hfloat surfaceDepth = lowerDepth;
        hfloat backgroundTime = upperTime;
#ifdef REVERSED_Z
        hfloat endDepth = min(upperPosition.z, lowerDepth);
#else
        hfloat endDepth = max(upperPosition.z, lowerDepth);
#endif
        hvec2 pixelStep = abs(step.xy) / cGBufferInvSize.xy;
#ifdef MOBILE_SSR_PREVIOUS_HZB
        pixelStep *= 0.5; // The finest stored history depth is half resolution.
#endif
        hfloat pixelsPerStep = max(pixelStep.x, pixelStep.y);
        for (int boundary = 0; boundary < 8; ++boundary)
        {
            if ((backgroundTime - surfaceTime) * pixelsPerStep <= 1.0)
                break;
            hfloat middleTime = 0.5 * (surfaceTime + backgroundTime);
            hvec3 middlePosition = origin + step * middleTime;
            hfloat depth = MobileSSRSurfaceDepth(middlePosition.xy);
#ifdef REVERSED_Z
            bool crossed = depth > middlePosition.z;
#else
            bool crossed = depth < middlePosition.z;
#endif
            // A convex object may be entered through its side and left through its top
            // before reaching the silhouette. Preserve an observed crossing immediately;
            // the last foreground point can already be in front of its depth again.
            if (crossed)
            {
                surfaceTime = middleTime;
                surfaceDepth = depth;
                break;
            }
#ifdef REVERSED_Z
            bool background = depth <= endDepth;
#else
            bool background = depth >= endDepth;
#endif
            if (background)
                backgroundTime = middleTime;
            else
            {
                surfaceTime = middleTime;
                surfaceDepth = depth;
            }
        }
        upperTime = surfaceTime;
        upperPosition = origin + step * upperTime;
        upperDepth = surfaceDepth;
    }
#ifdef REVERSED_Z
    upperDifference = upperDepth - upperPosition.z;
#else
    upperDifference = upperPosition.z - upperDepth;
#endif
    if (upperDifference <= 0.0)
    {
        // A convex side/top transition can contain a short behind-surface interval
        // even when both coarse endpoints and the silhouette endpoint are in front.
        // Search that retained foreground interval for a bracket. Reuse one depth
        // sample per iteration, and stop as soon as a genuine crossing is observed.
        hfloat searchLower = lowerTime;
        hfloat searchUpper = upperTime;
        hfloat t0 = mix(searchLower, searchUpper, 0.381966);
        hfloat t1 = mix(searchLower, searchUpper, 0.618034);
        hfloat d0 = MobileSSRDepthDifference(origin + step * t0);
        hfloat d1 = MobileSSRDepthDifference(origin + step * t1);
        for (int search = 0; search < 10; ++search)
        {
            if (d0 > 0.0 || d1 > 0.0)
            {
                upperTime = d0 > 0.0 ? t0 : t1;
                upperDifference = d0 > 0.0 ? d0 : d1;
                break;
            }
            if (search == 9)
                break;
            if (d0 < d1)
            {
                searchLower = t0;
                t0 = t1;
                d0 = d1;
                t1 = mix(searchLower, searchUpper, 0.618034);
                d1 = MobileSSRDepthDifference(origin + step * t1);
            }
            else
            {
                searchUpper = t1;
                t1 = t0;
                d1 = d0;
                t0 = mix(searchLower, searchUpper, 0.381966);
                d0 = MobileSSRDepthDifference(origin + step * t0);
            }
        }
        if (upperDifference <= 0.0)
            return false;
    }
    // Farthest HZB can report a hit after the finest depth was already crossed,
    // especially where a mip footprint contains both a silhouette and background.
    // Recover the front endpoint instead of turning those candidates into holes.
    for (int backtrack = 0; backtrack < 12; ++backtrack)
    {
        if (lowerDifference <= 0.0)
            break;
        upperTime = lowerTime;
        upperDifference = lowerDifference;
        lowerTime = max(0.0, lowerTime - 1.0);
        lowerDifference = lowerTime > 0.0 ? MobileSSRDepthDifference(origin + step * lowerTime) : 0.0;
    }
    if (lowerDifference > 0.0)
        return false;
    // Refinement is an UrhoX addition: a thickness rejection alone cannot correct
    // UE's first-sample LastDiff=0 interpolation or a coarse depth discontinuity.
    for (int refinement = 0; refinement < 4; ++refinement)
    {
        hfloat middleTime = 0.5 * (lowerTime + upperTime);
        hfloat difference = MobileSSRDepthDifference(origin + step * middleTime);
        if (difference > 0.0)
        {
            upperTime = middleTime;
            upperDifference = difference;
        }
        else
        {
            lowerTime = middleTime;
            lowerDifference = difference;
        }
    }
    // A zero at the receiver origin is a self intersection, not the reflected hit.
    hfloat fraction = lowerDifference < -1e-9 ?
        saturate(lowerDifference / (lowerDifference - upperDifference)) : 1.0;
    hit = origin + step * mix(lowerTime, upperTime, fraction);
    return true;
}

hfloat MobileSSRHitConfidence(hvec3 hit)
{
    if (u_Thickness <= 0.0)
        return 1.0;
#ifdef MOBILE_SSR_PREVIOUS_HZB
    // The DDA profile owns previous geometry only in the stored half-resolution hierarchy.
    // Its current-pixel depth attachment cannot be sampled at a ray hit elsewhere on screen.
    hfloat surfaceDepth = MobileSSRSurfaceDepth(hit.xy);
    hvec2 jitterDelta = u_CameraJitterOffset - u_MobileSSRHistoryJitter;
#if !BGFX_SHADER_LANGUAGE_GLSL
    jitterDelta.y = -jitterDelta.y;
#endif
    hvec2 depthUV = hit.xy + jitterDelta;
#else
    hfloat surfaceDepth = MobileSSRSurfaceDepth(hit.xy);
    hvec2 depthUV = hit.xy;
#endif
    if (IsSceneFarDepth(surfaceDepth, 1e-7))
        return 0.0;
    // Match the desktop SSR thickness check. UE's slope tolerance alone accepts
    // samples well behind a surface, stretching floating objects into long streaks.
    hfloat separation = length(ReconstructViewPos(depthUV, hit.z) - ReconstructViewPos(depthUV, surfaceDepth));
    hfloat confidence = 1.0 - smoothstep(0.0, u_Thickness, separation);
    return confidence * confidence;
}

#endif // URHOX_MOBILE_SSR_HIT_PATCHES

// Trace a reflected ray; return the accepted hit and its thickness confidence.
// Rejected refined candidates leave the remaining coarse intervals available.
bool MobileRayCast(hvec3 origin, hvec3 direction, hfloat roughness, hfloat noise, out hvec3 hit, out hfloat hitConfidence)
{
    hit = hvec3_init(0.0, 0.0, 0.0);
    hitConfidence = 1.0;
    hfloat sceneDepth = abs(origin.z);
    hfloat distance = direction.z < 0.0 ? min(sceneDepth, -0.95 * sceneDepth / direction.z) : sceneDepth;
    hvec4 projectedStart = MobileProjectView(origin);
    hvec4 projectedEnd = MobileProjectView(origin + direction * distance);
    if (projectedStart.w <= 1e-6 || projectedEnd.w <= 1e-6 ||
        any(lessThan(projectedStart.xy, hvec2_init(0.0, 0.0))) ||
        any(greaterThan(projectedStart.xy, hvec2_init(1.0, 1.0))) || projectedStart.z < 0.0 || projectedStart.z > 1.0)
        return false;
    hvec3 start = projectedStart.xyz;
    hvec3 delta = projectedEnd.xyz - start;
    if (dot(delta.xy, delta.xy) < 1e-14 || distance <= 0.0)
        return false;
    delta *= MobileRayBorderFactor(start.xy, delta.xy);
    hfloat depthDelta = abs(start.z - MobileProjectView(origin + hvec3_init(0.0, 0.0, distance)).z);
    // UE uses slope-only tolerance for orthographic projection; perspective also covers ray depth span.
    hfloat tolerance = abs(u_ReflectionEnvironment.w) > 0.5 ? depthDelta * 4.0 : max(abs(delta.z), depthDelta * 4.0);
    hfloat step = 1.0 / u_MobileSSRTrace.y;
    tolerance *= step;
    delta *= step;
    start += delta * noise;
    hfloat previousDifference = 0.0;
#if URHOX_MOBILE_SSR_HIT_PATCHES
    // Start at half-resolution depth; UE's mip 1 can erase narrow silhouettes into the background.
    // Keep the original start mip for the runtime bypass as well as the compiled OFF variant.
    hfloat level = u_Thickness > 0.0 ? 0.0 : 1.0;
    hfloat previousSurfaceDepth = projectedStart.z;
#else
    hfloat level = 1.0;
#endif
    // Keep an explicit result across the loops: the runtime ESSL compiler can
    // miscompile early returns into undefined flags when all samples miss.
    bool foundHit = false;
    // UE's four-sample batches and roughness mip schedule, with fixed mobile budgets of 8/12.
    for (int batch = 0; batch < 12 && !foundHit; batch += 4)
    {
        if (hfloat_init(batch) >= u_MobileSSRTrace.y)
            break;
        hvec4 differences = hvec4_init(0.0, 0.0, 0.0, 0.0);
        hvec4 hits = hvec4_init(0.0, 0.0, 0.0, 0.0);
#if URHOX_MOBILE_SSR_HIT_PATCHES
        hvec4 surfaceDepths = hvec4_init(0.0, 0.0, 0.0, 0.0);
#endif
        for (int sampleIndex = 0; sampleIndex < 4; ++sampleIndex)
        {
            hvec3 samplePosition = start + delta * hfloat_init(batch + sampleIndex + 1);
            hfloat sampleMip = min(level, u_MobileSSRTrace.x);
            hfloat z = texture2DLod(u_MobileHZB2, samplePosition.xy * u_HZBUvFactor.xy, sampleMip).r;
#if URHOX_MOBILE_SSR_HIT_PATCHES
            surfaceDepths[sampleIndex] = z;
#endif
            hfloat difference = samplePosition.z - z;
            differences[sampleIndex] = difference;
#ifdef REVERSED_Z
            hits[sampleIndex] = abs(difference + tolerance) < tolerance ? 1.0 : 0.0;
#else
            hits[sampleIndex] = abs(difference - tolerance) < tolerance ? 1.0 : 0.0;
#endif
            if (sampleIndex == 1 || sampleIndex == 3)
                level += 8.0 * step * roughness;
        }
#if !URHOX_MOBILE_SSR_HIT_PATCHES
        // Without refinement, select the first accepted sample directly.
        if (any(greaterThan(hits, hvec4_init(0.0, 0.0, 0.0, 0.0))))
        {
            int sampleIndex = hits.x > 0.0 ? 0 : (hits.y > 0.0 ? 1 : (hits.z > 0.0 ? 2 : 3));
            hfloat d0 = sampleIndex == 0 ? previousDifference : differences[sampleIndex - 1];
            hfloat d1 = differences[sampleIndex];
            hfloat denominator = d0 - d1;
            hfloat fraction = abs(denominator) > 1e-12 ? saturate(d0 / denominator) : 0.0;
            hit = start + delta * (hfloat_init(batch + sampleIndex) + fraction);
            foundHit = true;
        }
#else
        for (int sampleIndex = 0; sampleIndex < 4; ++sampleIndex)
        {
            bool candidate = hits[sampleIndex] > 0.0;
#if URHOX_MOBILE_SSR_HIT_PATCHES
            if (!candidate && u_Thickness > 0.0)
            {
                hfloat previousDepth = sampleIndex == 0 ? previousSurfaceDepth : surfaceDepths[sampleIndex - 1];
                hvec3 samplePosition = start + delta * hfloat_init(batch + sampleIndex + 1);
#ifdef REVERSED_Z
                hfloat exitDifference = previousDepth - surfaceDepths[sampleIndex];
                hfloat surfaceDifference = surfaceDepths[sampleIndex] - samplePosition.z;
#else
                hfloat exitDifference = surfaceDepths[sampleIndex] - previousDepth;
                hfloat surfaceDifference = samplePosition.z - surfaceDepths[sampleIndex];
#endif
                // Receding depth can hide an entry and exit within a single coarse interval.
                candidate = surfaceDifference <= 0.0 && exitDifference > 0.0 &&
                    all(greaterThanEqual(samplePosition.xy, hvec2_init(0.0, 0.0))) &&
                    all(lessThanEqual(samplePosition.xy, hvec2_init(1.0, 1.0)));
            }
#endif
            if (candidate)
            {
                hfloat d0 = sampleIndex == 0 ? previousDifference : differences[sampleIndex - 1];
                hfloat d1 = differences[sampleIndex];
                hfloat denominator = d0 - d1;
                hfloat fraction = abs(denominator) > 1e-12 ? saturate(d0 / denominator) : 0.0;
                hit = start + delta * (hfloat_init(batch + sampleIndex) + fraction);
#if URHOX_MOBILE_SSR_HIT_PATCHES
                if (u_Thickness > 0.0)
                {
                    hfloat lowerTime = batch + sampleIndex == 0 ? 0.0 : hfloat_init(batch + sampleIndex) + noise;
                    hfloat upperTime = hfloat_init(batch + sampleIndex + 1) + noise;
                    if (!MobileSSRRefineHit(projectedStart.xyz, delta, lowerTime, upperTime, hit))
                        continue;
                    hvec2 hitPixels = abs(hit.xy - projectedStart.xy) / cGBufferInvSize.xy;
#ifdef MOBILE_SSR_PREVIOUS_HZB
                    hitPixels *= 0.5;
#endif
                    // Nearest depth quantization can bracket the receiver itself. Keep
                    // searching instead of letting a sub-texel self hit hide a later object.
                    if (max(hitPixels.x, hitPixels.y) <= 1.0)
                        continue;
                    hitConfidence = MobileSSRHitConfidence(hit);
                    if (hitConfidence <= 0.0)
                        continue;
                }
#endif
                foundHit = true;
                break;
            }
        }
#endif
        previousDifference = differences.w;
#if URHOX_MOBILE_SSR_HIT_PATCHES
        previousSurfaceDepth = surfaceDepths.w;
#endif
    }
    return foundHit && all(greaterThanEqual(hit.xy, hvec2_init(0.0, 0.0))) &&
        all(lessThanEqual(hit.xy, hvec2_init(1.0, 1.0)));
}

hfloat MobileHitVignette(hvec2 uv)
{
    hvec2 edge = saturate(abs(uv * 2.0 - 1.0) * 5.0 - 4.0);
    return saturate(1.0 - dot(edge, edge));
}

hvec4 MobileSSR(hvec2 uv, hvec3 viewPosition, hvec3 worldRay, hfloat roughness)
{
    if (u_MobileSSRParams.x <= 0.0 || roughness > u_MobileSSRParams.z)
        return hvec4_init(0.0, 0.0, 0.0, 0.0);
    hvec2 noisePixel = floor(uv / cGBufferInvSize.xy) + u_MobileSSRTrace.w * hvec2_init(47.0, 17.0) * 0.695;
    hfloat noise = InterleavedGradientNoise(noisePixel) - 0.5;
    hvec3 hit;
    hfloat hitConfidence;
    hvec3 direction = normalize(mul(hvec4_init(worldRay, 0.0), cView).xyz);
    if (!MobileRayCast(viewPosition, direction, roughness, noise, hit, hitConfidence))
        return hvec4_init(0.0, 0.0, 0.0, 0.0);
#ifdef MOBILE_SSR_PREVIOUS_HZB
    // The ray hit already belongs to the previous camera; HDR TAA history is unjittered.
    hvec2 previousJitter = u_MobileSSRHistoryJitter;
#if !BGFX_SHADER_LANGUAGE_GLSL
    previousJitter.y = -previousJitter.y;
#endif
    hvec2 previousUV = hit.xy - previousJitter;
    hfloat weight = min(MobileHitVignette(uv), MobileHitVignette(previousUV));
#else
    hvec2 jitter = u_CameraJitterOffset;
#if !BGFX_SHADER_LANGUAGE_GLSL
    jitter.y = -jitter.y;
#endif
    hvec2 currentUV = hit.xy - jitter;
    hvec4 previousClip = mul(ScreenUVToClip(currentUV, hit.z), u_CameraClipToPrevClip);
    if (previousClip.w <= 1e-6)
        return hvec4_init(0.0, 0.0, 0.0, 0.0);
    hvec2 previousUV = previousClip.xy / previousClip.w * 0.5 + 0.5;
#if !BGFX_SHADER_LANGUAGE_GLSL
    previousUV.y = 1.0 - previousUV.y;
#endif
    if (u_MobileSSRTrace.z > 0.5)
        previousUV = currentUV - texture2DLod(u_MobileMotion4, hit.xy, 0.0).rg;
    hfloat weight = min(MobileHitVignette(hit.xy), MobileHitVignette(previousUV));
#endif
#if URHOX_MOBILE_SSR_HIT_PATCHES
    weight *= hitConfidence * u_MobileSSRParams.x * saturate(2.0 - u_MobileSSRParams.w * roughness);
#else
    weight *= u_MobileSSRParams.x * saturate(2.0 - u_MobileSSRParams.w * roughness);
#endif
    if (!(weight > 0.0))
        return hvec4_init(0.0, 0.0, 0.0, 0.0);
    previousUV = clamp(previousUV, u_MobileSSRHistoryBounds.xy, u_MobileSSRHistoryBounds.zw);
    hvec3 color = texture2DLod(u_MobileHistory3, previousUV, 0.0).rgb;
    color = max(color, hvec3_init(0.0, 0.0, 0.0));
    return hvec4_init(color * (weight * u_MobileSSRParams.y), weight);
}
#endif
