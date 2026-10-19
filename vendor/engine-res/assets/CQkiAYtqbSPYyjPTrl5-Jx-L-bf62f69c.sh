// UE ApplyFogToCloudSampleFromVPosAndDepth using the existing UrhoX fog fields.
#ifndef VOLUMETRIC_CLOUD_FOG_SH
#define VOLUMETRIC_CLOUD_FOG_SH

#include "fog.sh"
#ifdef CLOUD_FALLBACK_FOG
#include "Volumetric/VolumetricFogIntegration.sh"
#else
SAMPLER3D(u_CloudIntegratedFog4, 4);
#endif
// x = integrated fog; y = Zone fog; z = maximum opacity; w = legacy additive fog.
uniform hvec4 u_CloudFogParams;
uniform hvec4 u_FroxelGridParams;
uniform hvec4 u_FroxelCamForward;
uniform hmat4 u_CloudInvViewProj;
uniform hvec4 u_CloudCamera;

/// Evaluate foreground fog at the reconstructed cloud's representative radial distance.
hvec4 ApplyCloudForegroundFog(hvec2 uv, hfloat depthKm, hvec4 cloud)
{
    hvec4 fog = hvec4_init(0.0, 0.0, 0.0, 1.0);
    if (u_CloudFogParams.x > 0.5 || u_CloudFogParams.y > 0.5 || u_CloudFogParams.w > 0.5)
    {
        hvec4 world = mul(ScreenUVToClip(uv, 0.5), u_CloudInvViewProj);
        hvec3 direction = normalize(world.xyz / world.w - u_CloudCamera.xyz);
        hvec3 cameraToCloud = direction * (depthKm * 1000.0);
#ifdef CLOUD_FALLBACK_FOG
        if (u_CloudFogParams.w > 0.5)
            fog.rgb = EvaluateLegacyVolumetricFog(uv, u_CloudCamera.xyz, u_CloudCamera.xyz + cameraToCloud);
        // The existing fullscreen fog is additive, so its transmittance stays one.
#else
        if (u_CloudFogParams.x > 0.5)
        {
            hfloat viewZ = dot(cameraToCloud, u_FroxelCamForward.xyz);
            // The existing integrated volume stores each slice's far-boundary integral.
            hfloat slice = log2(max(viewZ * u_FroxelGridParams.x + u_FroxelGridParams.y, 1e-8)) * u_FroxelGridParams.z;
            hfloat w = clamp((slice - 0.5) / u_FroxelGridParams.w, 0.0, 1.0);
            fog = texture3DLod(u_CloudIntegratedFog4, hvec3_init(uv, w), 0.0);
            fog.a = 1.0 - clamp(1.0 - fog.a, 0.0, u_CloudFogParams.z);
        }
#endif
        if (u_CloudFogParams.y > 0.5)
        {
            hfloat zoneT = GetHeightFogFactor(depthKm * 1000.0, __GET_HEIGHT__((u_CloudCamera.xyz + cameraToCloud)));
            // UE CombineVolumetricFog: foreground volume over the analytic background fog.
            // Keep the existing Zone fog model; distance exclusion is a separate change.
            fog.rgb += fog.a * cFogColor * (1.0 - zoneT);
            fog.a *= zoneT;
        }
        cloud.rgb = cloud.rgb * fog.a + (1.0 - cloud.a) * fog.rgb;
    }
    return cloud;
}

#endif
