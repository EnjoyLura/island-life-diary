// UE 5.5.4 RenderCameraAerialPerspectiveVolumeCS, combined RGB volume without pre-exposure.
#ifdef COMPILECS
#include "varying_cluster.def.sc"
#include "Common/bgfx_compute.sh"
#define ATMOSPHERE_MULTIPLE_SCATTERING
#include "Sky/SkyAtmosphereIntegration.sh"

IMAGE3D_WR(u_AtmosphereAPOutput4, rgba32f, 4);
uniform hvec4 u_AtmosphereAPParams;
uniform hvec4 u_AtmosphereAPCamera;
uniform hmat4 u_AtmosphereAPInvViewProj;
uniform hvec4 u_AtmosphereAPForward;

NUM_THREADS(4, 4, 4)
void main()
{
    uvec3 pixel = gl_GlobalInvocationID.xyz;
    ATMOSPHERE_GEOMETRY_PRECISE hvec2 uv = (hvec2_init(pixel.xy) + 0.5) / 32.0;
#ifdef ATMOSPHERE_CAPTURE_360
    // UE RealTimeReflection360Mode: equal-area latitude and longitude, independent of cube face orientation.
    hvec2 unitUV = (uv - 0.5 / 32.0) * (32.0 / 31.0);
    hfloat sinPhi = clamp(2.0 * unitUV.y - 1.0, -1.0, 1.0);
    hfloat cosPhi = sqrt(max(0.0, 1.0 - sinPhi * sinPhi));
    hfloat theta = 6.28318530718 * unitUV.x;
    hfloat cosTheta = cos(theta);
    hfloat sinTheta = sqrt(max(0.0, 1.0 - cosTheta * cosTheta)) * (theta > 3.14159265359 ? -1.0 : 1.0);
    hvec3 direction = normalize(hvec3_init(cosTheta * cosPhi, sinPhi, sinTheta * cosPhi));
    hvec3 offset = hvec3_init(0.0, 0.0, 0.0);
#else
    ATMOSPHERE_GEOMETRY_PRECISE hvec4 clip = hvec4_init(uv * 2.0 - 1.0, 0.5, 1.0);
#if BGFX_SHADER_LANGUAGE_GLSL
    clip.z = 0.0;
#else
    clip.y = -clip.y;
#endif
    ATMOSPHERE_GEOMETRY_PRECISE hvec4 world = mul(clip, u_AtmosphereAPInvViewProj);
    ATMOSPHERE_GEOMETRY_PRECISE hvec3 offset = world.xyz / world.w;
    ATMOSPHERE_GEOMETRY_PRECISE hvec3 direction = normalize(offset);
#endif
    ATMOSPHERE_GEOMETRY_PRECISE hvec3 camera = u_AtmosphereAPCamera.xyz;
    // UE clamps the atmosphere camera to ground + 5 m; ray direction still uses the real view.
    if (length(camera) < u_AtmosphereRadii.x + 0.005)
        camera = normalize(camera) * (u_AtmosphereRadii.x + 0.005);
    if (u_AtmosphereAPCamera.w > 0.5)
    {
        direction = u_AtmosphereAPForward.xyz;
        camera += (offset - direction * dot(offset, direction)) * 0.001;
    }
    ATMOSPHERE_GEOMETRY_PRECISE hfloat slice = (hfloat_init(pixel.z) + 0.5) / u_AtmosphereAPParams.z;
    slice *= slice * u_AtmosphereAPParams.z;
    ATMOSPHERE_GEOMETRY_PRECISE hfloat maxDistance = slice * u_AtmosphereAPParams.y;
    ATMOSPHERE_GEOMETRY_PRECISE hvec3 origin = camera + u_AtmosphereAPParams.x * direction;
    ATMOSPHERE_GEOMETRY_PRECISE hvec3 voxel = origin + maxDistance * direction;
    bool underground = length(voxel) < u_AtmosphereRadii.x;
    ATMOSPHERE_GEOMETRY_PRECISE hvec3 cameraToVoxel = voxel - camera;
    ATMOSPHERE_GEOMETRY_PRECISE hfloat planetNear = AtmosphereNearestSphere(camera, normalize(cameraToVoxel), u_AtmosphereRadii.x);
    bool belowHorizon = planetNear > 0.0 && length(cameraToVoxel) > planetNear;
    if (belowHorizon || underground)
    {
        camera += normalize(camera) * 0.02;
        ATMOSPHERE_GEOMETRY_PRECISE hvec3 voxelNormal = normalize(voxel);
        ATMOSPHERE_GEOMETRY_PRECISE hvec3 cameraGround = normalize(camera) * u_AtmosphereRadii.x;
        ATMOSPHERE_GEOMETRY_PRECISE hvec3 voxelGround = voxelNormal * u_AtmosphereRadii.x;
        if (belowHorizon && dot(normalize(camera - voxelGround), voxelNormal) < 0.0001)
        {
            ATMOSPHERE_GEOMETRY_PRECISE hvec3 midpointGround = normalize(0.5 * (cameraGround + voxelGround)) * u_AtmosphereRadii.x;
            voxel = camera + 2.0 * (midpointGround - camera);
        }
        else if (underground)
            voxel = voxelGround;
        direction = normalize(voxel - camera);
        origin = camera + u_AtmosphereAPParams.x * direction;
        maxDistance = length(voxel - origin);
    }
    ATMOSPHERE_GEOMETRY_PRECISE hvec3 previousOrigin = origin;
    if (!AtmosphereMoveToTop(origin, direction) || maxDistance < length(previousOrigin - origin))
    {
        imageStore(u_AtmosphereAPOutput4, ivec3(pixel), hvec4_init(0.0, 0.0, 0.0, 1.0));
        return;
    }
    maxDistance = max(0.0, maxDistance - length(previousOrigin - origin));
    ATMOSPHERE_GEOMETRY_PRECISE hfloat count = max(1.0, (hfloat_init(pixel.z) + 1.0) * u_AtmosphereAPParams.w);
    AtmosphereIntegral integral = IntegrateAtmosphere(origin, direction, false, true, count,
        false, 0.0, 0.0, 0.0, u_AtmosphereLightDirection0.xyz, u_AtmosphereLightDirection1.xyz,
        u_AtmosphereLightColor0.rgb, u_AtmosphereLightColor1.rgb, u_AtmosphereSky.w, maxDistance, 0.3);
    imageStore(u_AtmosphereAPOutput4, ivec3(pixel), hvec4_init(integral.luminance,
        dot(integral.transmittance, hvec3_init(0.333333333333, 0.333333333333, 0.333333333333))));
}
#endif
