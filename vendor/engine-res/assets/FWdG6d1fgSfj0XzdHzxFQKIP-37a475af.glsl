// UE 5.5.4 Transmittance and default two-direction MultiScatteredLuminance LUT passes.
#ifdef COMPILECS
#include "varying_cluster.def.sc"
#include "Common/bgfx_compute.sh"
#include "Sky/SkyAtmosphereIntegration.sh"

IMAGE2D_WR(u_AtmosphereOutput2, rgba32f, 2);
uniform vec4 u_AtmosphereLutSize; // width, height, sample count, reserved

NUM_THREADS(8, 8, 1)
void main()
{
    uvec2 pixel = gl_GlobalInvocationID.xy;
    if (pixel.x >= uint(u_AtmosphereLutSize.x) || pixel.y >= uint(u_AtmosphereLutSize.y))
        return;
    vec2 uv = (vec2(pixel) + vec2(0.5, 0.5)) / u_AtmosphereLutSize.xy;
    vec3 zero = vec3(0.0, 0.0, 0.0);
    vec3 up = vec3(0.0, 1.0, 0.0);
#ifdef ATMOSPHERE_TRANSMITTANCE_PASS
    float height;
    float zenith;
    AtmosphereFromTransmittanceUV(uv, height, zenith);
    vec3 origin = vec3(0.0, height, 0.0);
    vec3 direction = vec3(0.0, zenith, sqrt(1.0 - zenith * zenith));
    AtmosphereIntegral integral = IntegrateAtmosphere(origin, direction, false, false, u_AtmosphereLutSize.z,
        false, 0.0, 0.0, 0.0, up, up, zero, zero, 1.0, 9000000.0, 0.3);
    imageStore(u_AtmosphereOutput2, ivec2(pixel), vec4(exp(-integral.opticalDepth), 0.0));
#else
    float cosine = uv.x * 2.0 - 1.0;
    vec3 lightDirection = vec3(0.0, cosine, sqrt(saturate(1.0 - cosine * cosine)));
    vec3 origin = vec3(0.0, u_AtmosphereRadii.x + uv.y * (u_AtmosphereRadii.y - u_AtmosphereRadii.x), 0.0);
    vec3 white = vec3(1.0, 1.0, 1.0);
    AtmosphereIntegral r0 = IntegrateAtmosphere(origin, up, true, false, u_AtmosphereLutSize.z,
        false, 0.0, 0.0, 0.0, lightDirection, up, white, zero, 1.0, 9000000.0, 0.3);
    AtmosphereIntegral r1 = IntegrateAtmosphere(origin, -up, true, false, u_AtmosphereLutSize.z,
        false, 0.0, 0.0, 0.0, lightDirection, up, white, zero, 1.0, 9000000.0, 0.3);
    vec3 luminance = 0.5 * (r0.luminance + r1.luminance);
    vec3 ratio = 0.5 * (r0.multiScatAsOne + r1.multiScatAsOne);
    vec3 ratioSquared = ratio * ratio;
    luminance *= (white + ratio + ratioSquared + ratio * ratioSquared + ratioSquared * ratioSquared);
    imageStore(u_AtmosphereOutput2, ivec2(pixel), vec4(luminance * u_AtmosphereGround.w, 0.0));
#endif
}
#endif
