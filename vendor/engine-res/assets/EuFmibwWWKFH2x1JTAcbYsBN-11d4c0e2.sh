#ifndef CAMERA_REPROJECTION_SH
#define CAMERA_REPROJECTION_SH

#include "ScreenSpace/ScreenSpaceCommon.sh"

// Built from relative camera transforms in double precision on the CPU.
uniform hmat4 u_CameraClipToPrevClip;
// Current raster jitter in projection-offset units (pixels / full view size).
uniform hvec2 u_CameraJitterOffset;

// Both endpoints are unjittered; depth still belongs to the sampled raster pixel.
hvec2 ComputeCameraMotionVector(hvec2 unjitteredUV, hfloat deviceDepth)
{
    hvec4 clip = ScreenUVToClip(unjitteredUV, deviceDepth);
    hvec4 previousClip = mul(clip, u_CameraClipToPrevClip);
    // Identity gives exact zero without a UV -> NDC -> UV rounding residual.
    hvec2 motion = (clip.xy * previousClip.w - previousClip.xy) * (0.5 / previousClip.w);
#if !BGFX_SHADER_LANGUAGE_GLSL
    motion.y = -motion.y;
#endif
    return motion;
}

hvec2 ComputeCameraMotionVectorFromRaster(hvec2 rasterUV, hfloat deviceDepth)
{
    hvec2 jitterUV = u_CameraJitterOffset;
#if !BGFX_SHADER_LANGUAGE_GLSL
    jitterUV.y = -jitterUV.y;
#endif
    return ComputeCameraMotionVector(rasterUV - jitterUV, deviceDepth);
}

#endif
