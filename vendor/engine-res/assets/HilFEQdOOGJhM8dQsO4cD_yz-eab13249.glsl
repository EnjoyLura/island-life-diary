// UE RenderSkyAtmosphereRayMarchingPS: fast sky inside the atmosphere, direct sky outside, opaque camera AP.
#include "varying_quad.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
$input a_position
$output vTexCoord, vWorldPos
#endif
#ifdef COMPILEPS
$input vTexCoord, vWorldPos
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
    vWorldPos = hvec4_init(GetFarRay(gl_Position), 0.0);
}

#ifdef COMPILEPS
#include "ScreenSpace/ScreenSpaceCommon.sh"
#include "Sky/SkyAtmosphereIntegration.sh"
#include "Sky/SkyAtmosphereSkyView.sh"
SAMPLER2D(u_AtmosphereSkyView2, 2);
SAMPLER3D(u_AtmosphereCameraAP3, 3);
SAMPLER2D(u_AtmosphereSceneDepth4, 4);
uniform hvec4 u_AtmosphereAPParams;
uniform hvec4 u_AtmosphereLightDisk0;
uniform hvec4 u_AtmosphereLightDisk1;
uniform hfloat u_FrameIndex;

hvec3 AtmosphereDisk(hvec3 origin, hvec3 direction, hvec3 lightDirection, hvec4 disk)
{
    hfloat viewDotLight = dot(direction, lightDirection);
    if (viewDotLight <= disk.w || disk.w >= 1.0)
        return hvec3_init(0.0, 0.0, 0.0);
    hfloat softEdge = saturate(2.0 * (viewDotLight - disk.w) / (1.0 - disk.w));
    return min(hvec3_init(64000.0, 64000.0, 64000.0), disk.rgb * softEdge
        * SampleAtmosphereSunTransmittance(origin, direction, u_AtmosphereTransmittance0));
}

void PS()
{
    hfloat deviceDepth = texture2DLod(u_AtmosphereSceneDepth4, vTexCoord, 0.0).r;
    bool background = IsSceneFarDepth(deviceDepth, 1e-12);
    if (!background)
    {
        hfloat distanceKm = length(vWorldPos.xyz * ReconstructDepth(deviceDepth)) * 0.001;
        hvec4 ap = SampleAtmosphereAP(vTexCoord, distanceKm, u_AtmosphereAPParams, u_AtmosphereCameraAP3);
        gl_FragColor = hvec4_init(ap.rgb, 1.0 - ap.a);
        return;
    }
    if (u_AtmosphereViewOptions.x < 0.5)
    {
        gl_FragColor = hvec4_init(0.0, 0.0, 0.0, 0.0);
        return;
    }
    hvec3 direction = normalize(vWorldPos.xyz);
    hvec3 origin = u_AtmosphereAPCamera.xyz;
    hfloat height = length(origin);
    bool ground = AtmosphereNearestSphere(origin, direction, u_AtmosphereRadii.x) >= 0.0;
    hvec3 luminance = hvec3_init(0.0, 0.0, 0.0);
    if (!ground)
    {
        hvec3 diskOrigin = origin;
        if (AtmosphereMoveToTop(diskOrigin, direction))
            luminance = AtmosphereDisk(diskOrigin, direction, u_AtmosphereLightDirection0.xyz, u_AtmosphereLightDisk0)
                + AtmosphereDisk(diskOrigin, direction, u_AtmosphereLightDirection1.xyz, u_AtmosphereLightDisk1);
        else
        {
            // Outside the atmosphere a ray missing the shell has unit atmospheric transmittance.
            hfloat d0 = dot(direction, u_AtmosphereLightDirection0.xyz);
            hfloat d1 = dot(direction, u_AtmosphereLightDirection1.xyz);
            luminance = u_AtmosphereLightDisk0.rgb * saturate(2.0 * (d0 - u_AtmosphereLightDisk0.w) / max(1e-8, 1.0 - u_AtmosphereLightDisk0.w))
                + u_AtmosphereLightDisk1.rgb * saturate(2.0 * (d1 - u_AtmosphereLightDisk1.w) / max(1e-8, 1.0 - u_AtmosphereLightDisk1.w));
            luminance = min(luminance, hvec3_init(64000.0, 64000.0, 64000.0));
        }
    }
    if (height < u_AtmosphereRadii.y * 0.99999)
        luminance += texture2DLod(u_AtmosphereSkyView2, AtmosphereSkyViewUV(direction, height, ground), 0.0).rgb * u_AtmosphereSky.rgb;
    else if (AtmosphereMoveToTop(origin, direction))
    {
        origin += direction * u_AtmosphereAPParams.x;
        // UE SkyAtmosphereNoise / RandomInterleavedGradientNoise. LUT and reflection paths keep offset 0.3.
        hfloat sampleOffset = InterleavedGradientNoise(gl_FragCoord.xy + u_FrameIndex * hvec2_init(32.665, 11.815));
        AtmosphereIntegral integral = IntegrateAtmosphere(origin, direction, false, true, 0.0,
            true, u_AtmosphereViewOptions.y, u_AtmosphereViewOptions.z, u_AtmosphereViewOptions.w,
            u_AtmosphereLightDirection0.xyz, u_AtmosphereLightDirection1.xyz,
            u_AtmosphereLightColor0.rgb, u_AtmosphereLightColor1.rgb, 1.0, 9000000.0, sampleOffset);
        luminance += integral.luminance * u_AtmosphereSky.rgb;
    }
    gl_FragColor = hvec4_init(luminance, 1.0);
}
#endif
