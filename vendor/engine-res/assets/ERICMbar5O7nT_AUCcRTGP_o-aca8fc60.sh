/*
 * XeGTAO Common Functions
 *
 * Faithful port of Intel's XeGTAO (GameTechDev/XeGTAO, MIT License).
 * Based on "Practical Realtime Strategies for Accurate Indirect Occlusion"
 * Jorge Jimenez, Xian-Chun Wu, Angelo Pesce, Adrian Jarabo — SIGGRAPH 2016
 *
 * All computations use full precision (hfloat/hvec*) to avoid fp16 artifacts.
 */

#ifndef GTAO_COMMON_SH
#define GTAO_COMMON_SH

#include "ScreenSpace/ScreenSpaceCommon.sh"

#ifdef COMPILEPS
/// Return mip-zero dimensions without the half-precision textureSize wrapper on HLSL.
hvec2 GTAOTextureSize(sampler2D source)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    uint width, height;
    source.m_texture.GetDimensions(width, height);
    return hvec2_init(width, height);
#else
    return hvec2_init(textureSize(source, 0));
#endif
}

/// Return an exact affine depth grid for equal sizes or half resolution rounded up per axis.
/// The returned step/origin are valid only when true; other ratios require the integer mapping.
bool GTAODepthGrid(hvec2 aoSize, hvec2 depthSize, out hvec2 step, out hvec2 origin)
{
    if (all(equal(aoSize, depthSize)))
    {
        step = hvec2_init(1.0, 1.0);
        origin = hvec2_init(0.0, 0.0);
        return true;
    }
    step = hvec2_init(2.0, 2.0);
    origin = depthSize - aoSize * 2.0 + 1.0;
    return all(greaterThanEqual(origin, hvec2_init(0.0, 0.0))) &&
        all(lessThanEqual(origin, hvec2_init(1.0, 1.0)));
}

/// Map a clamped AO texel index to its representative full-resolution depth texel.
/// Exact full/half-resolution grids avoid division; other ratios retain integer boundary selection.
hvec2 GTAODepthPixel(hvec2 aoPixel, hvec2 aoSize, hvec2 depthSize)
{
    hvec2 pixel = floor(clamp(aoPixel, hvec2_init(0.0, 0.0), aoSize - 1.0));
    hvec2 step, origin;
    hvec2 result;
    // Keep the integer fallback out of the common path after HLSL cross-compilation.
    BRANCH
    if (GTAODepthGrid(aoSize, depthSize, step, origin))
        result = pixel * step + origin;
    else
        result = hvec2_init(((ivec2(pixel) * 2 + 1) * ivec2(depthSize)) / (ivec2(aoSize) * 2));
    return result;
}

/// Return the depth/normal/motion sample center represented by an AO-buffer UV.
/// Both textures cover the same viewport; dimensions may be odd or equal.
hvec2 GTAODepthUV(hvec2 aoUV, hvec2 aoSize, hvec2 depthSize)
{
    return (GTAODepthPixel(floor(aoUV * aoSize), aoSize, depthSize) + 0.5) / depthSize;
}

/// Return clamped AO neighbors, their representative depth pixels, and weights at a physical depth UV.
/// Keep the footprint separate so rounding an interpolated index cannot shift its neighbors.
void GTAOBufferFootprint(hvec2 depthUV, hvec2 aoSize, hvec2 depthSize,
    out hvec2 low, out hvec2 high, out hvec2 lowDepth, out hvec2 highDepth, out hvec2 fraction)
{
    hvec2 pixel = floor(depthUV * aoSize);
    hvec2 sampleUV = (GTAODepthPixel(pixel, aoSize, depthSize) + 0.5) / depthSize;
    pixel -= hvec2_init(depthUV.x < sampleUV.x ? 1.0 : 0.0, depthUV.y < sampleUV.y ? 1.0 : 0.0);
    low = clamp(pixel, hvec2_init(0.0, 0.0), aoSize - 1.0);
    high = clamp(pixel + 1.0, hvec2_init(0.0, 0.0), aoSize - 1.0);
    lowDepth = GTAODepthPixel(low, aoSize, depthSize);
    highDepth = GTAODepthPixel(high, aoSize, depthSize);
    fraction = saturate((depthUV * depthSize - 0.5 - lowDepth) / max(highDepth - lowDepth, hvec2_init(1.0, 1.0)));
}

/// Map a physical depth UV to the AO lattice for bilinear history sampling.
/// Interpolate between the actual representative samples, including nonuniform odd-size spacing.
hvec2 GTAOBufferUV(hvec2 depthUV, hvec2 aoSize, hvec2 depthSize)
{
    hvec2 low, high, lowDepth, highDepth, fraction;
    GTAOBufferFootprint(depthUV, aoSize, depthSize, low, high, lowDepth, highDepth, fraction);
    return (mix(low, high, fraction) + 0.5) / aoSize;
}
#endif

// Constants
#define PI 3.14159265359
#define HALF_PI 1.57079632679

// XeGTAO default tuning constants (from XeGTAO.h / vaGTAO.hlsl)
#define XE_GTAO_RADIUS_MULTIPLIER          1.457
#define XE_GTAO_FALLOFF_RANGE              0.615
#define XE_GTAO_SAMPLE_DISTRIBUTION_POWER  2.0
#define XE_GTAO_PIXEL_TOO_CLOSE_THRESHOLD  1.3
#define XE_GTAO_DEPTH_MIP_SAMPLING_OFFSET  3.30

// Fast acos approximation (polynomial fit, ~0.01 max error)
// XeGTAO uses this to avoid expensive acos() in the inner loop.
hfloat XeGTAO_FastACos(hfloat inX)
{
    hfloat x = abs(inX);
    hfloat res = -0.156583 * x + HALF_PI;
    res *= sqrt(1.0 - x);
    return (inX >= 0.0) ? res : PI - res;
}

// ====================================================================
// Hilbert curve index (XeGTAO.h — HilbertIndex)
// Maps 2D pixel coordinates to a 1D index along the Hilbert space-filling
// curve within a 64x64 tile. The Hilbert curve has excellent spatial
// distribution: neighboring pixels map to very different indices,
// eliminating the directional banding artifacts of IGN noise.
// ====================================================================
#define XE_HILBERT_LEVEL  6
#define XE_HILBERT_WIDTH  64

int XeGTAO_HilbertIndex(int posX, int posY)
{
    int index = 0;
    for (int curLevel = XE_HILBERT_WIDTH / 2; curLevel > 0; curLevel /= 2)
    {
        int regionX = ((posX & curLevel) > 0) ? 1 : 0;
        int regionY = ((posY & curLevel) > 0) ? 1 : 0;
        index += curLevel * curLevel * ((3 * regionX) ^ regionY);
        if (regionY == 0)
        {
            if (regionX == 1)
            {
                posX = (XE_HILBERT_WIDTH - 1) - posX;
                posY = (XE_HILBERT_WIDTH - 1) - posY;
            }
            int temp = posX;
            posX = posY;
            posY = temp;
        }
    }
    return index;
}

// ====================================================================
// SpatioTemporalNoise (vaGTAO.hlsl — SpatioTemporalNoise)
// Combines Hilbert curve index with R2 quasi-random sequence for
// well-distributed 2D noise with temporal variation.
// R2 constants: generalized golden ratio for 2D quasi-random sampling.
// Ref: http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
// ====================================================================
hvec2 XeGTAO_SpatioTemporalNoise(int pixX, int pixY, int temporalIndex)
{
    int hilbert = XeGTAO_HilbertIndex(pixX & (XE_HILBERT_WIDTH - 1),
                                       pixY & (XE_HILBERT_WIDTH - 1));
    hilbert += 288 * (temporalIndex & 63);
    return fract(hvec2_init(0.5, 0.5) + hfloat_init(hilbert)
        * hvec2_init(0.75487766624669276, 0.56984029099805327));
}

#endif // GTAO_COMMON_SH
