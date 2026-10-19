#include "Common/common.sh"
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"

#ifdef COMPILEVS
void HiZDownsampleVS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#endif

#ifdef COMPILEPS

#ifdef HIZ_FARTHEST_ONLY
SAMPLER2D_PRECISION(u_FarthestHiZ0, 0, highp);
#define u_FarthestHiZ1 u_FarthestHiZ0
#else
// Source ClosestHiZ RT (register 0)
SAMPLER2D_PRECISION(u_ClosestHiZ0, 0, highp);
// Source FarthestHiZ RT (register 1)
SAMPLER2D_PRECISION(u_FarthestHiZ1, 1, highp);
#endif

hvec2 HiZDownsamplePS()
{
    // Query the source dimensions: a terminal 1-texel axis is not twice the output.
#if BGFX_SHADER_DIALECT_HLSL > 300
    uint width, height;
    u_FarthestHiZ1.m_texture.GetDimensions(width, height);
    hvec2 sourceSize = hvec2_init(width, height);
#else
    hvec2 sourceSize = hvec2_init(textureSize(u_FarthestHiZ1, 0));
#endif
    hvec2 texelSize = 1.0 / sourceSize;
    hvec2 srcCorner = hvec2_init(gl_FragCoord.x, gl_FragCoord.y) * 2.0;
    hvec2 maxPixel = sourceSize - 0.5;
    hvec2 uv00 = min(srcCorner + hvec2_init(-0.5, -0.5), maxPixel) * texelSize;
    hvec2 uv10 = min(srcCorner + hvec2_init( 0.5, -0.5), maxPixel) * texelSize;
    hvec2 uv01 = min(srcCorner + hvec2_init(-0.5,  0.5), maxPixel) * texelSize;
    hvec2 uv11 = min(srcCorner + hvec2_init( 0.5,  0.5), maxPixel) * texelSize;

    // Use full precision (hfloat/hvec4) for depth — fp16 causes quantization stripes
    #ifndef HIZ_FARTHEST_ONLY
    hvec4 closestSamples;
    closestSamples.x = texture2D(u_ClosestHiZ0, uv00).r;
    closestSamples.y = texture2D(u_ClosestHiZ0, uv10).r;
    closestSamples.z = texture2D(u_ClosestHiZ0, uv01).r;
    closestSamples.w = texture2D(u_ClosestHiZ0, uv11).r;

    #endif
    hvec4 farthestSamples;
    farthestSamples.x = texture2D(u_FarthestHiZ1, uv00).r;
    farthestSamples.y = texture2D(u_FarthestHiZ1, uv10).r;
    farthestSamples.z = texture2D(u_FarthestHiZ1, uv01).r;
    farthestSamples.w = texture2D(u_FarthestHiZ1, uv11).r;

    hfloat closest;
    hfloat farthest;

#ifdef REVERSED_Z
    // Reversed-Z: near = 1.0, far = 0.0
    #ifndef HIZ_FARTHEST_ONLY
    closest = max(max(closestSamples.x, closestSamples.y),
                  max(closestSamples.z, closestSamples.w));
    #endif
    farthest = min(min(farthestSamples.x, farthestSamples.y),
                   min(farthestSamples.z, farthestSamples.w));
#else
    // Standard Z: near = 0.0, far = 1.0
    #ifndef HIZ_FARTHEST_ONLY
    closest = min(min(closestSamples.x, closestSamples.y),
                  min(closestSamples.z, closestSamples.w));
    #endif
    farthest = max(max(farthestSamples.x, farthestSamples.y),
                   max(farthestSamples.z, farthestSamples.w));
#endif

#ifdef HIZ_FARTHEST_ONLY
    return hvec2_init(0.0, farthest);
#else
    return hvec2_init(closest, farthest);
#endif
}

#endif
