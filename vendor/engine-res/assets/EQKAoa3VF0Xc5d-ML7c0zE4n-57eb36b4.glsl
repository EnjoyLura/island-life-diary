#include "varying_deferred.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position
    $output vTexCoord, vScreenPos, vFarRay _VNEARRAY
#endif
#ifdef COMPILEPS
    $input vTexCoord, vScreenPos, vFarRay _VNEARRAY
#endif

#include "Common/common.sh"
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "lighting.sh"

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
    vFarRay = GetFarRay(gl_Position);
    #ifdef ORTHO
        vNearRay = GetNearRay(gl_Position);
    #endif
}

#ifdef COMPILEPS
SAMPLER2D(u_ShadowDepth4, 4);

#ifndef TEMPORAL_SHADOW_RESOLVE
SAMPLER2D(u_ShadowNormal0, 0);

void PS()
{
    hfloat depth = ReconstructDepth(texture2D(u_ShadowDepth4, vScreenPos).r);
    #ifdef ORTHO
        hvec3 worldPos = mix(vNearRay, vFarRay, depth) + cCameraPosPS;
    #else
        hvec3 worldPos = vFarRay * depth + cCameraPosPS;
    #endif
    hvec3 normal = normalize(DecodeNormal(texture2D(u_ShadowNormal0, vScreenPos).rgb));
    int contributors;
    // Evaluate receiver derivatives before the background branch, including silhouette quads.
    hfloat visibility = TemporalDirShadowVisibilityDeferred(hvec4_init(worldPos, 1.0), normal, depth, contributors);
    if (!(depth > 0.0 && depth < 0.99999))
    {
        visibility = 1.0;
        contributors = 0;
    }
    gl_FragData[0] = hvec4_init(visibility, 0.0, 0.0, 1.0);
    gl_FragData[1] = hvec4_init(float(contributors) / 255.0, 0.0, 0.0, 1.0);
}

#else
SAMPLER2D(u_ShadowCurrent0, 0);
SAMPLER2D(u_ShadowHistory1, 1);
SAMPLER2D(u_ShadowCurrentMetadata2, 2);
SAMPLER2D(u_ShadowHistoryMetadata3, 3);
SAMPLER2D(u_ShadowNormal5, 5);
SAMPLER2D(u_ShadowMotion6, 6);
uniform hvec4 u_ShadowHistoryControl; // valid, changed cascade mask, base weight, refreshed weight
uniform hmat4 u_ShadowRasterInvViewProj;
uniform hmat4 u_ShadowPreviousRasterViewProj;
uniform hmat4 u_ShadowPreviousView;
#include "ScreenSpace/ScreenSpaceCommon.sh"
#include "ScreenSpace/MotionVector/CameraReprojection.sh"

hvec2 ShadowSignNotZero(hvec2 value)
{
    return hvec2_init(value.x >= 0.0 ? 1.0 : -1.0, value.y >= 0.0 ? 1.0 : -1.0);
}

hvec2 ShadowEncodeNormal(hvec3 normal)
{
    normal /= max(abs(normal.x) + abs(normal.y) + abs(normal.z), 0.0001);
    hvec2 oct = normal.xy;
    if (normal.z < 0.0)
        oct = (1.0 - abs(oct.yx)) * ShadowSignNotZero(oct);
    return oct * 0.5 + 0.5;
}

hvec3 ShadowDecodeNormal(hvec2 oct)
{
    oct = oct * 2.0 - 1.0;
    hvec3 normal = hvec3_init(oct, 1.0 - abs(oct.x) - abs(oct.y));
    if (normal.z < 0.0)
        normal.xy = (1.0 - abs(normal.yx)) * ShadowSignNotZero(normal.xy);
    return normalize(normal);
}

hvec2 ShadowScreenUV(hvec4 clip)
{
    hvec2 uv = clip.xy / clip.w * 0.5 + 0.5;
    #if !BGFX_SHADER_LANGUAGE_GLSL
        uv.y = 1.0 - uv.y;
    #endif
    return uv;
}

void PS()
{
    hvec2 uv = vScreenPos.xy;
    hvec2 texel = cGBufferInvSize.xy;
    hfloat current = texture2D(u_ShadowCurrent0, uv).r;
    hfloat deviceDepth = texture2D(u_ShadowDepth4, uv).r;
    hfloat depth = ReconstructDepth(deviceDepth);
    hfloat viewZ = depth * cFarClipPS;
    hvec3 normal = normalize(DecodeNormal(texture2D(u_ShadowNormal5, uv).rgb));
    hvec4 outputValue = hvec4_init(current, min(viewZ, 60000.0), ShadowEncodeNormal(normal));
    int contributors = int(round(texture2D(u_ShadowCurrentMetadata2, uv).r * 255.0));
    if (u_ShadowHistoryControl.x < 0.5 || contributors == 0 || !(depth > 0.0 && depth < 0.99999))
    {
        gl_FragColor = outputValue;
        return;
    }

    hvec4 clip = ScreenUVToClip(uv, deviceDepth);
    hvec4 world = mul(clip, u_ShadowRasterInvViewProj);
    world /= world.w;
    hvec4 previousClip = mul(world, u_ShadowPreviousRasterViewProj);
    hvec2 historyUV = ShadowScreenUV(previousClip);
    hfloat expectedPreviousZ = mul(world, u_ShadowPreviousView).z;

    // Match the velocity producer at this raster pixel. History lookup above already
    // includes current/previous jitter through its raster matrices.
    hvec2 cameraMotion = ComputeCameraMotionVectorFromRaster(uv, deviceDepth);
    hvec2 motion = texture2D(u_ShadowMotion6, uv).rg;
    hvec2 objectMotionPixels = (motion - clamp(cameraMotion, vec2_splat(-0.5), vec2_splat(0.5))) / texel;
    bool valid = previousClip.w > 0.0 && expectedPreviousZ > 0.0
        && all(greaterThanEqual(historyUV, texel * 0.5)) && all(lessThanEqual(historyUV, 1.0 - texel * 0.5))
        && all(lessThan(abs(motion), vec2_splat(0.49))) && dot(objectMotionPixels, objectMotionPixels) < 0.0625;
    if (!valid)
    {
        gl_FragColor = outputValue;
        return;
    }

    // Nearest metadata/depth/normal: no interpolation across unrelated geometry or cascade contributors.
    hvec4 history = texture2D(u_ShadowHistory1, historyUV);
    int previousContributors = int(round(texture2D(u_ShadowHistoryMetadata3, historyUV).r * 255.0));
    valid = contributors == previousContributors && history.r >= 0.0 && history.r <= 1.0
        && abs(history.g - expectedPreviousZ) < max(0.01, expectedPreviousZ * 0.005)
        && dot(normal, ShadowDecodeNormal(history.ba)) > 0.95;
    if (!valid)
    {
        gl_FragColor = outputValue;
        return;
    }

    hfloat minimum = current;
    hfloat maximum = current;
    for (int i = 0; i < 4; ++i)
    {
        hvec2 offset = i == 0 ? hvec2_init(-texel.x, 0.0) : (i == 1 ? hvec2_init(texel.x, 0.0)
            : (i == 2 ? hvec2_init(0.0, -texel.y) : hvec2_init(0.0, texel.y)));
        hvec2 neighborUV = uv + offset;
        hfloat neighborZ = ReconstructDepth(texture2D(u_ShadowDepth4, neighborUV).r) * cFarClipPS;
        hvec3 neighborNormal = normalize(DecodeNormal(texture2D(u_ShadowNormal5, neighborUV).rgb));
        int neighborContributors = int(round(texture2D(u_ShadowCurrentMetadata2, neighborUV).r * 255.0));
        if (abs(neighborZ - viewZ) < max(0.01, viewZ * 0.03) && dot(normal, neighborNormal) > 0.95
            && contributors == neighborContributors)
        {
            hfloat neighbor = texture2D(u_ShadowCurrent0, neighborUV).r;
            minimum = min(minimum, neighbor);
            maximum = max(maximum, neighbor);
        }
    }
    hfloat weight = u_ShadowHistoryControl.z;
    if ((contributors & int(u_ShadowHistoryControl.y)) != 0)
        weight = min(weight, u_ShadowHistoryControl.w);
    if ((contributors & 1) != 0)
        weight = min(weight, 0.35);
    // Receiver MV cannot follow a moving shadow on a static floor. Visibility change and clipping
    // must quickly accept newly refreshed occlusion instead of accumulating the stale silhouette.
    weight *= saturate(1.0 - abs(history.r - current) * 4.0);
    weight *= saturate(1.0 - length(motion / texel) / 32.0);
    outputValue.r = mix(current, clamp(history.r, minimum, maximum), weight);
    gl_FragColor = outputValue;
}
#endif
#endif
