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
#include "ScreenSpace/ScreenSpaceCommon.sh"

void VS()
{
    gl_Position = GetClipPos(GetWorldPos(iModelMatrix));
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS
// UE 5.5 PostProcessAmbientOcclusionMobile: public quality 1/2/3 maps to shader quality 0/1/2.
// UE 5.5.4 uses depthHeight * P00. Correct its aspect-dependent search extent;
// set to 0 to retain the UE formula for visual/performance comparisons.
#ifndef URHOX_MOBILE_GTAO_ASPECT_CORRECTION
#define URHOX_MOBILE_GTAO_ASPECT_CORRECTION 1
#endif
#ifndef MOBILE_GTAO_QUALITY
#define MOBILE_GTAO_QUALITY 1
#endif
#if MOBILE_GTAO_QUALITY == 1
#define MOBILE_GTAO_TAPS 4
#elif MOBILE_GTAO_QUALITY == 2
#define MOBILE_GTAO_TAPS 6
#elif MOBILE_GTAO_QUALITY == 3
#define MOBILE_GTAO_TAPS 8
#else
#error Mobile GTAO quality must be 1, 2 or 3
#endif
#if defined(MOBILE_GTAO_LUT) && MOBILE_GTAO_LUT != 0
#error Mobile GTAO currently supports the analytic integral only
#endif
SAMPLER2D_PRECISION(u_MobileDepth0, 0, highp);
// Projected world radius, inverse squared falloff, thickness retention, orthographic projection.
uniform hvec4 u_MobileGTAOSearch;
// Visibility power, enabled weight, fade end (meters), inverse fade radius.
uniform hvec4 u_MobileGTAOFilter;
uniform hvec4 u_MobileGTAODepthSize;

hfloat MobileDepth(hvec2 uv)
{
    return texture2DLod(u_MobileDepth0, uv, 0.0).r;
}

hvec3 MobileDepthNormal(hvec2 uv, hfloat depth, hvec3 position)
{
    // Choose the smaller device-depth derivative on each axis to avoid silhouette normals.
    hvec2 dx = hvec2_init(cGBufferInvSize.x, 0.0);
    hvec2 dy = hvec2_init(0.0, cGBufferInvSize.y);
    hfloat left = depth - MobileDepth(uv - dx);
    hfloat right = MobileDepth(uv + dx) - depth;
    hfloat top = depth - MobileDepth(uv - dy);
    hfloat bottom = MobileDepth(uv + dy) - depth;
    hvec3 tangent = ReconstructViewPos(uv + dx, depth + (abs(left) < abs(right) ? left : right)) - position;
    hvec3 bitangent = ReconstructViewPos(uv + dy, depth + (abs(top) < abs(bottom) ? top : bottom)) - position;
    hvec3 normal = cross(tangent, bitangent);
    normal *= inversesqrt(max(dot(normal, normal), 1e-20));
    return dot(normal, position) > 0.0 ? -normal : normal;
}

hfloat MobileAcos(hfloat x)
{
    hfloat a = abs(clamp(x, -1.0, 1.0));
    hfloat angle = (1.57079632679 - 0.156583 * a) * sqrt(1.0 - a);
    return x >= 0.0 ? angle : 3.14159265359 - angle;
}

hvec2 MobileHorizon(hvec2 uv, hvec2 direction, hfloat radius, hfloat offset, hvec3 position, hvec3 view)
{
    hvec2 best = hvec2_init(-1.0, -1.0);
    for (int tap = 0; tap < MOBILE_GTAO_TAPS; ++tap)
    {
        hvec2 delta = direction * u_MobileGTAODepthSize.zw * max(radius * (hfloat_init(tap) + offset), hfloat_init(tap + 1));
#if !BGFX_SHADER_LANGUAGE_GLSL
        delta.y = -delta.y;
#endif
        for (int side = 0; side < 2; ++side)
        {
            hvec2 sampleUV = uv + (side == 0 ? delta : -delta);
            if (any(lessThan(sampleUV, u_MobileGTAODepthSize.zw * 0.5)) ||
                any(greaterThan(sampleUV, 1.0 - u_MobileGTAODepthSize.zw * 0.5)))
                continue;
            hvec3 difference = ReconstructViewPos(sampleUV, MobileDepth(sampleUV)) - position;
            hfloat lengthSquared = dot(difference, difference);
            hfloat angle = dot(difference, view) * inversesqrt(lengthSquared + 0.0001);
            hfloat previous = side == 0 ? best.x : best.y;
            angle = mix(angle, previous, saturate(lengthSquared * u_MobileGTAOSearch.y));
            hfloat next = angle > previous ? angle : mix(angle, previous, u_MobileGTAOSearch.z);
            if (side == 0) best.x = next;
            else best.y = next;
        }
    }
    return hvec2_init(MobileAcos(best.x), MobileAcos(best.y));
}

hfloat MobileIntegral(hvec2 angles, hvec3 direction, hvec3 view, hvec3 normal)
{
    hvec3 plane = normalize(cross(direction, view));
    hvec3 perpendicular = cross(view, plane);
    hvec3 projected = normal - plane * dot(normal, plane);
    hfloat magnitude = length(projected) + 0.000001;
    hfloat cosine = clamp(dot(projected, perpendicular) / magnitude, -1.0, 1.0);
    hfloat gamma = MobileAcos(cosine) - 1.57079632679;
    hfloat cosGamma = dot(projected, view) / magnitude;
    hfloat sinGamma = -2.0 * cosine;
    angles.x = gamma + max(-angles.x - gamma, -1.57079632679);
    angles.y = gamma + min(angles.y - gamma, 1.57079632679);
    return magnitude * 0.25 * (angles.x * sinGamma + cosGamma - cos(2.0 * angles.x - gamma) +
        angles.y * sinGamma + cosGamma - cos(2.0 * angles.y - gamma));
}

void PS()
{
    hvec2 uv = vTexCoord + u_MobileGTAODepthSize.zw * 0.125;
    hfloat deviceDepth = MobileDepth(uv);
    hvec3 position = ReconstructViewPos(uv, deviceDepth);
    hfloat sceneDepth = abs(position.z);
    hfloat ao = 1.0;
    if (!IsSceneFarDepth(deviceDepth, 1e-7) && sceneDepth < u_MobileGTAOFilter.z && u_MobileGTAOFilter.y > 0.0)
    {
        hvec3 normal = MobileDepthNormal(uv, deviceDepth, position);
        hvec3 view = u_MobileGTAOSearch.w > 0.5 ? hvec3_init(0.0, 0.0, position.z > 0.0 ? -1.0 : 1.0) : normalize(-position);
        hfloat projectedRadius = u_MobileGTAOSearch.x;
#if URHOX_MOBILE_GTAO_ASPECT_CORRECTION
        // Match the horizontal projection coefficient to the horizontal pixel count.
        // Preserve UE's search multiplier, tap count and world-distance attenuation.
        projectedRadius *= u_MobileGTAODepthSize.x / u_MobileGTAODepthSize.y;
#endif
        hfloat radius = clamp(projectedRadius / (u_MobileGTAOSearch.w > 0.5 ? 1.0 : max(sceneDepth, 0.0001)),
            hfloat_init(MOBILE_GTAO_TAPS), 256.0) / hfloat_init(MOBILE_GTAO_TAPS + 1);
        hvec2 pixel = floor(vTexCoord / cGBufferInvSize.xy);
        pixel.y = 16384.0 - pixel.y;
        hfloat noise = InterleavedGradientNoise(pixel) * 3.14159265359;
        hvec2 direction = hvec2_init(cos(noise + 0.5235987756), sin(noise + 0.5235987756));
        hfloat offset = fract((pixel.y - pixel.x) * 0.25 + 0.025);
        ao = 0.0;
        for (int angle = 0; angle < 2; ++angle)
        {
            ao += MobileIntegral(MobileHorizon(uv, direction, radius, offset, position, view),
                hvec3_init(direction, 0.0), view, normal);
            direction = hvec2_init(-direction.y, direction.x);
            offset = fract(offset + 0.617);
        }
        ao *= 0.5 * 0.63661977237;
        ao = mix(ao, 1.0, saturate(1.0 + (sceneDepth - u_MobileGTAOFilter.z) * u_MobileGTAOFilter.w));
    }
    // Store the visibility integral scaled by 2/pi, as in UE's intermediate target.
    // Clamp the exact far plane before fractional packing to prevent 1.0 wrapping to 0.0.
    hvec3 packedDepth = fract(min(deviceDepth, 1.0 - 1.0 / 16581375.0) * hvec3_init(1.0, 255.0, 65025.0));
    packedDepth.xy -= packedDepth.yz / 255.0;
    gl_FragColor = hvec4_init(packedDepth, saturate(ao));
}
#endif
