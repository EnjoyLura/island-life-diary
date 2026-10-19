// UE Mode 0: quarter-resolution compute tracing, with near/far cloud integrals.
#ifdef COMPILECS
#include "varying_cluster.def.sc"
#include "Common/bgfx_compute.sh"
#include "uniforms.sh"
#include "ScreenSpace/ScreenSpaceCommon.sh"
uniform hvec2 u_GBufferInvSize;
#define cGBufferInvSize u_GBufferInvSize
#include "Volumetric/VolumetricCloudTrace.sh"
#include "Volumetric/VolumetricCloudDepthCommon.sh"

IMAGE2D_WR(u_CloudTracingColor0, rgba16f, 0);
IMAGE2D_WR(u_CloudTracingSecondary1, rgba16f, 1);
IMAGE2D_WR(u_CloudTracingDepth2, rgba32f, 2);
IMAGE2D_WR(u_CloudTracingDebug3, rgba16f, 3);
SAMPLER2D(u_CloudMinMaxDepth9, 9);
// xy = tracing resolution; zw = current 2x2 reconstruction pixel offset.
uniform hvec4 u_CloudTraceSizeOffset;
// xy = reconstruction resolution; zw = full view resolution.
uniform hvec4 u_CloudReconstructSize;

NUM_THREADS(8, 8, 1)
void main()
{
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(hvec2_init(pixel), u_CloudTraceSizeOffset.xy)))
        return;
    hvec2 offset = u_CloudTraceSizeOffset.zw;
    hvec2 uv = (hvec2_init(pixel) + 0.5) / u_CloudTraceSizeOffset.xy +
        (offset - 0.5) / u_CloudReconstructSize.xy;
    hvec4 ray = mul(ScreenUVToClip(uv, 0.5), u_CloudInvViewProj);
    hvec3 direction = normalize(ray.xyz / ray.w - u_CloudCamera.xyz);
    hvec2 minMaxZ = CloudLoad(u_CloudMinMaxDepth9, hvec2_init(pixel)).rg;
#ifdef REVERSED_Z
    minMaxZ = minMaxZ.yx;
#endif
    hvec4 viewRay = mul(ScreenUVToClip(uv, 0.5), u_UnjitteredProjInv);
    hfloat radialScale = length(viewRay.xyz) / abs(viewRay.z);
    hfloat nearDistance = min(CloudViewDepth(minMaxZ.x) * radialScale, 65504000.0);
    hfloat farDistance = min(CloudViewDepth(minMaxZ.y) * radialScale, 65504000.0);
    hfloat initialZ = CloudLoad(u_DepthBuffer0, hvec2_init(pixel) * 2.0 + offset).r;
    hfloat initialDistance = min(CloudViewDepth(initialZ) * radialScale, 65504000.0);
    hvec2 noiseUv = (hvec2_init(pixel) * 4.0 + offset * 2.0 + 2.0) / u_CloudReconstructSize.zw;
    hvec4 color, secondary, debug;
    hfloat cloudDepth;
    bool minMaxApplied;
    TraceVolumetricCloud(u_CloudCamera.xyz, direction, farDistance, nearDistance, initialDistance, uv,
        CloudRayJitter(noiseUv), color, secondary, cloudDepth, minMaxApplied, debug);
    hfloat sceneDistance = minMaxApplied ? farDistance : initialDistance;
    hvec2 outputDeviceZ = minMaxApplied ? minMaxZ : hvec2_init(initialZ, initialZ);
    imageStore(u_CloudTracingColor0, pixel, color);
    imageStore(u_CloudTracingSecondary1, pixel, secondary);
    imageStore(u_CloudTracingDepth2, pixel, hvec4_init(min(cloudDepth, 65504.0), min(sceneDistance * 0.001, 65504.0), outputDeviceZ));
    imageStore(u_CloudTracingDebug3, pixel, debug);
}
#endif
