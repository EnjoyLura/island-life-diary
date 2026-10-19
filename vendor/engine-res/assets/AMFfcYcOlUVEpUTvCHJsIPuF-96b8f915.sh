#include "Common/common.sh"
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"

#ifdef COMPILEVS
void HiZInitVS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#endif

#ifdef COMPILEPS

// Depth buffer (register 0, matching RenderPath texture unit)
SAMPLER2D_PRECISION(u_Depth0, 0, highp);

// Depth source (viewport) size: xy = size, zw = invSize. The HZB RT is pow2half sized
// and no longer matches the viewport; set by View::ApplyHiZBuildParameters
uniform hvec4 u_HiZViewport;

hvec2 HiZInitPS()
{
    // Output texel (x,y) reduces the 2x2 source depth block (2x,2y)..(2x+1,2y+1).
    // Use gl_FragCoord (highp by spec) for integer addressing to avoid half-precision
    // vTexCoord off-by-one at large resolutions.
    // gl_FragCoord.xy = (x+0.5, y+0.5), so x2 = center corner of the source block (2x+1, 2y+1).
    hvec2 srcCorner = hvec2_init(gl_FragCoord.x, gl_FragCoord.y) * 2.0;

    // Clamp out-of-range samples (pow2 padding / odd viewport edge) to the last texel center
    // inside the viewport, matching UE HZB.usf InputViewportMaxBound semantics —
    // duplicated samples are harmless for min/max reduction
    hvec2 maxUV = (u_HiZViewport.xy - 0.5) * u_HiZViewport.zw;

    hvec2 uv00 = min((srcCorner + hvec2_init(-0.5, -0.5)) * u_HiZViewport.zw, maxUV);
    hvec2 uv10 = min((srcCorner + hvec2_init( 0.5, -0.5)) * u_HiZViewport.zw, maxUV);
    hvec2 uv01 = min((srcCorner + hvec2_init(-0.5,  0.5)) * u_HiZViewport.zw, maxUV);
    hvec2 uv11 = min((srcCorner + hvec2_init( 0.5,  0.5)) * u_HiZViewport.zw, maxUV);

    // Use full precision (hfloat/hvec4) for depth to avoid fp16 quantization artifacts
    hvec4 depth4;
    depth4.x = texture2D(u_Depth0, uv00).r;
    depth4.y = texture2D(u_Depth0, uv10).r;
    depth4.z = texture2D(u_Depth0, uv01).r;
    depth4.w = texture2D(u_Depth0, uv11).r;

#ifdef REVERSED_Z
    // Reversed-Z: near = 1.0, far = 0.0
    hfloat closest = max(max(depth4.x, depth4.y), max(depth4.z, depth4.w));
    hfloat farthest = min(min(depth4.x, depth4.y), min(depth4.z, depth4.w));
#else
    // Standard Z: near = 0.0, far = 1.0
    hfloat closest = min(min(depth4.x, depth4.y), min(depth4.z, depth4.w));
    hfloat farthest = max(max(depth4.x, depth4.y), max(depth4.z, depth4.w));
#endif

#ifdef HIZ_FARTHEST_ONLY
    return hvec2_init(0.0, farthest);
#else
    return hvec2_init(closest, farthest);
#endif
}

#endif
