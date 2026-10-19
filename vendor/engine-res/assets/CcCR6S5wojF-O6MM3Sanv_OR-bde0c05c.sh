/*
 * Screen Space Common Functions
 * Shared utilities for all screen-space effects (SSR, SSAO, etc.)
 *
 * All computations use full precision ('hfloat'/'hvec'/'hmat4') to avoid
 * fp16 quantization artifacts. Engine convention: float/vec* = half, h* = full.
 */

#ifndef SCREEN_SPACE_COMMON_SH
#define SCREEN_SPACE_COMMON_SH

// Classify raw device depth, never linear view Z. Epsilon is measured in device-depth units.
bool IsSceneFarDepth(hfloat deviceDepth, hfloat epsilon)
{
#ifdef REVERSED_Z
    return deviceDepth <= epsilon;
#else
    return deviceDepth >= 1.0 - epsilon;
#endif
}

// Convert screen UV and device depth [0,1] to clip coordinates with w = 1.
hvec4 ScreenUVToClip(hvec2 uv, hfloat deviceDepth)
{
    hvec4 clip = hvec4_init(uv * 2.0 - 1.0, deviceDepth, 1.0);
    // GL clip space Z is [-1,1], depth buffer stores [0,1] -> remap
    // DX clip space Z is [0,1], depth buffer stores [0,1] -> no remap
#if BGFX_SHADER_LANGUAGE_GLSL
    // GL: UV.y=0 is bottom, clip.y=-1 is bottom -> no Y flip needed.
    clip.z = deviceDepth * 2.0 - 1.0;
#else
    // Other backends: UV.y=0 is top, clip.y=+1 is top -> need Y flip.
    clip.y = -clip.y;
#endif
    return clip;
}

// Reconstruct view-space position from UV and depth
hvec3 ReconstructViewPos(hvec2 uv, hfloat depth)
{
    hvec4 clipPos = ScreenUVToClip(uv, depth);
    hvec4 viewPos = mul(clipPos, cInvProj);
    return viewPos.xyz / viewPos.w;
}

// Decode normal from GBuffer
hvec3 DecodeGBufferNormal(hvec3 encoded)
{
    return normalize(hvec3_init(encoded.x, encoded.y, encoded.z) * 2.0 - 1.0);
}

// Interleaved Gradient Noise (Jimenez, SIGGRAPH 2014)
// Produces well-distributed screen-space noise with minimal visible pattern.
// Superior to white noise for stochastic effects because the low-frequency
// structure is easily removed by temporal filtering.
hfloat InterleavedGradientNoise(hvec2 screenPos)
{
    hvec3 magic = hvec3_init(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(screenPos, magic.xy)));
}

#endif // SCREEN_SPACE_COMMON_SH
