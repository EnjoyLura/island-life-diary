// UE RenderDistantSkyLightLutCS: 64 sphere directions, ten samples per ray, no pre-exposure.
#ifdef COMPILECS
#include "varying_cluster.def.sc"
#include "Common/bgfx_compute.sh"
#define ATMOSPHERE_MULTIPLE_SCATTERING
#include "Sky/SkyAtmosphereIntegration.sh"

IMAGE2D_WR(u_AtmosphereOutput2, rgba32f, 2);
uniform vec4 u_AtmosphereSphereDirections[64];
SHARED vec3 skyLuminanceSamples[64];

NUM_THREADS(8, 8, 1)
void main()
{
    uint index = gl_LocalInvocationID.y * 8u + gl_LocalInvocationID.x;
    vec3 origin = vec3(0.0, u_AtmosphereRadii.x + 6.0, 0.0);
    AtmosphereIntegral integral = IntegrateAtmosphere(origin, u_AtmosphereSphereDirections[index].xyz,
        false, false, 10.0, false, 0.0, 0.0, 0.0, u_AtmosphereLightDirection0.xyz, u_AtmosphereLightDirection1.xyz,
        u_AtmosphereLightColor0.rgb, u_AtmosphereLightColor1.rgb, 1.0, 9000000.0, 0.3);
    skyLuminanceSamples[index] = integral.luminance * u_AtmosphereSky.rgb;
    barrier();
    // Preserve UE's pairwise reduction order, with explicit synchronization for every backend wave size.
    for (uint stride = 32u; stride > 0u; stride /= 2u)
    {
        if (index < stride)
            skyLuminanceSamples[index] += skyLuminanceSamples[index + stride];
        barrier();
    }
    if (index == 0u)
        imageStore(u_AtmosphereOutput2, ivec2(0, 0), vec4(skyLuminanceSamples[0] / 64.0, 0.0));
}
#endif
