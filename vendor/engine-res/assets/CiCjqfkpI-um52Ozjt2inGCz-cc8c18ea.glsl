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

void VS()
{
    gl_Position = GetClipPos(GetWorldPos(iModelMatrix));
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS
// Packed device depth must retain float sampling precision even though its channels are UNORM8.
SAMPLER2D_PRECISION(u_MobileHorizon0, 0, highp);
uniform hvec4 u_MobileGTAOFilter;

hvec2 MobilePackedDepthAO(hvec2 uv)
{
    hvec4 packed = texture2DLod(u_MobileHorizon0, uv, 0.0);
    return hvec2_init(dot(packed.rgb, hvec3_init(1.0, 1.0 / 255.0, 1.0 / 65025.0)), packed.a);
}

hfloat MobileDepthSlope(hvec2 uv, hvec2 delta, hfloat center)
{
    hfloat m1 = MobilePackedDepthAO(uv - delta).x;
    hfloat m2 = MobilePackedDepthAO(uv - delta * 2.0).x;
    hfloat p1 = MobilePackedDepthAO(uv + delta).x;
    hfloat p2 = MobilePackedDepthAO(uv + delta * 2.0).x;
    return abs(2.0 * m1 - m2 - center) < abs(2.0 * p1 - p2 - center) ? m1 - m2 : p2 - p1;
}

void PS()
{
    hvec2 uv = vTexCoord;
    hvec2 center = MobilePackedDepthAO(uv);
    hvec2 gradient = hvec2_init(MobileDepthSlope(uv, hvec2_init(cGBufferInvSize.x, 0.0), center.x),
        MobileDepthSlope(uv, hvec2_init(0.0, cGBufferInvSize.y), center.x));
    hfloat sum = 0.0;
    hfloat weights = 0.0;
    // UE's 5x5 plane-aware device-depth filter, with a defined fallback for degenerate weights.
    for (int y = -2; y <= 2; ++y)
        for (int x = -2; x <= 2; ++x)
        {
            hvec2 offset = hvec2_init(hfloat_init(x), hfloat_init(y));
            hvec2 sampleValue = MobilePackedDepthAO(uv + offset * cGBufferInvSize.xy);
            hfloat weight = 1.0 - saturate(abs(center.x + dot(gradient, offset) - sampleValue.x) * 1000.0);
            sum += sampleValue.y * weight;
            weights += weight;
        }
    hfloat visibility = saturate((weights > 0.0 ? sum / weights : center.y) * 1.57079632679);
    visibility = mix(1.0, pow(max(visibility, 1e-6), u_MobileGTAOFilter.x), u_MobileGTAOFilter.y);
    gl_FragColor = hvec4_init(saturate(visibility), 0.0, 0.0, 1.0);
}
#endif
