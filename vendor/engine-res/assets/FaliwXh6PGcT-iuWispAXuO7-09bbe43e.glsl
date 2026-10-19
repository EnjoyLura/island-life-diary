// UE RenderSkyViewLutCS. Integrate in world orientation so world cloud maps remain valid.
#ifdef COMPILECS
#include "varying_cluster.def.sc"
#include "Common/bgfx_compute.sh"
#define ATMOSPHERE_MULTIPLE_SCATTERING
#include "Sky/SkyAtmosphereIntegration.sh"
#include "Sky/SkyAtmosphereSkyView.sh"

IMAGE2D_WR(u_AtmosphereSkyViewOutput4, rgba32f, 4);

NUM_THREADS(8, 8, 1)
void main()
{
    uvec2 pixel = gl_GlobalInvocationID.xy;
    hvec2 uv = (hvec2_init(pixel) + 0.5) / hvec2_init(192.0, 104.0);
    hvec3 localDir = AtmosphereSkyViewDirection(uv, length(u_AtmosphereAPCamera.xyz));
    hvec3 direction = localDir.x * u_AtmosphereSkyViewForward.xyz + localDir.y * u_AtmosphereSkyViewUp.xyz
        + localDir.z * u_AtmosphereSkyViewLeft.xyz;
    hvec3 origin = u_AtmosphereAPCamera.xyz;
    hvec4 result = hvec4_init(0.0, 0.0, 0.0, 1.0);
    if (AtmosphereMoveToTop(origin, direction))
    {
        AtmosphereIntegral integral = IntegrateAtmosphere(origin, direction, false, true, 0.0,
            true, u_AtmosphereViewOptions.y, u_AtmosphereViewOptions.z, u_AtmosphereViewOptions.w,
            u_AtmosphereLightDirection0.xyz, u_AtmosphereLightDirection1.xyz,
            u_AtmosphereLightColor0.rgb, u_AtmosphereLightColor1.rgb, 1.0, 9000000.0, 0.3);
        result = hvec4_init(integral.luminance, dot(integral.transmittance, hvec3_init(1.0, 1.0, 1.0)) / 3.0);
    }
    imageStore(u_AtmosphereSkyViewOutput4, ivec2(pixel), result);
}
#endif
