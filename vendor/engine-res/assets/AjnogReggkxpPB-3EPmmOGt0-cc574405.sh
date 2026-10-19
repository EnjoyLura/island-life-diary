#ifndef URHO_VOLUMETRIC_CLOUD_SHADOW_COMMON
#define URHO_VOLUMETRIC_CLOUD_SHADOW_COMMON

/// Orthographic shadow textures use the backend render-target Y convention, independent of scene depth.
hvec2 CloudShadowUVToClip(hvec2 uv)
{
    hvec2 clip = uv * 2.0 - 1.0;
#if !BGFX_SHADER_LANGUAGE_GLSL
    clip.y = -clip.y;
#endif
    return clip;
}

/// Convert world meters to shadow texture UV and reversed orthographic depth.
hvec3 CloudShadowCoordinates(hvec3 position, hmat4 worldToClip)
{
    hvec4 clip = mul(hvec4_init(position, 1.0), worldToClip);
    hvec3 ndc = clip.xyz / clip.w;
#if !BGFX_SHADER_LANGUAGE_GLSL
    ndc.y = -ndc.y;
#endif
    return hvec3_init(ndc.xy * 0.5 + 0.5, ndc.z);
}

/// UE GetCloudVolumetricShadow: front depth (km), mean extinction (1/m), maximum optical depth.
hfloat CloudShadowOpticalDepth(hvec3 data, hfloat reversedDepth, hfloat farDepthKm)
{
    hfloat distanceKm = saturate(1.0 - reversedDepth) * farDepthKm;
    return min(data.b, data.g * max(0.0, distanceKm - data.r) * 1000.0);
}

/// Sample a world shadow/AO map; outside its world projection is explicitly unoccluded.
hfloat SampleCloudShadow(hvec3 position, hmat4 worldToClip, hfloat farDepthKm, sampler2D shadowMap)
{
    hvec3 uvz = CloudShadowCoordinates(position, worldToClip);
    if (any(lessThan(uvz.xy, hvec2_init(0.0, 0.0))) || any(greaterThan(uvz.xy, hvec2_init(1.0, 1.0))))
        return 1.0;
    hvec3 data = texture2DLod(shadowMap, uvz.xy, 0.0).rgb;
    return saturate(exp(-CloudShadowOpticalDepth(data, uvz.z, farDepthKm)));
}
#endif
