// UE MainCommon cloud integration for the Mode 0 near/far depth pair.
#include "Volumetric/VolumetricCloudMaterial.sh"
#if defined(CLOUD_AERIAL_PERSPECTIVE) && !defined(CLOUD_REFLECTION_CAPTURE)
uniform hmat4 u_AtmosphereAPViewProj;
#endif

/// Distances are meters at the integrator boundary; attachment depths are kilometers.
void TraceVolumetricCloud(hvec3 cameraPosition, hvec3 rayDirection, hfloat sceneDistance,
    hfloat nearestDistance, hfloat initialDistance, hvec2 uv, hfloat jitter, out hvec4 farResult, out hvec4 nearResult,
    out hfloat representativeDepth, out bool minMaxApplied, out hvec4 debugResult)
{
    farResult = hvec4_init(0.0, 0.0, 0.0, 1.0);
    nearResult = farResult;
    representativeDepth = initialDistance * 0.001;
    minMaxApplied = false;
    debugResult = hvec4_init(1.0, representativeDepth, representativeDepth, 0.0);
    hfloat outerNear;
    hfloat outerFar;
    if (!IntersectCloudSphere(cameraPosition, rayDirection, u_CloudPlanetCenter.xyz,
            u_CloudLayerRadii.y, outerNear, outerFar))
    {
        return;
    }

    hfloat rayStart = max(outerNear, 0.0);
    hfloat rayEnd = max(outerFar, 0.0);
    hfloat innerNear = -1.0;
    hfloat innerFar = -1.0;
    if (IntersectCloudSphere(cameraPosition, rayDirection, u_CloudPlanetCenter.xyz,
            u_CloudLayerRadii.x, innerNear, innerFar))
    {
        hfloat top = outerNear > 0.0 && outerFar > 0.0 ? min(outerNear, outerFar) : max(outerNear, outerFar);
        hfloat bottom = innerNear > 0.0 && innerFar > 0.0 ? min(innerNear, innerFar) : max(innerNear, innerFar);
        if (innerNear > 0.0 && innerFar > 0.0)
            top = max(0.0, min(outerNear, outerFar));
        rayStart = max(0.0, min(top, bottom));
        rayEnd = max(0.0, max(top, bottom));
    }
    if (rayEnd <= rayStart || rayStart > u_CloudTracing.x)
    {
        return;
    }
    minMaxApplied = true;
    if (sceneDistance <= rayStart)
        return;
    rayEnd = min(rayEnd, sceneDistance);
    if (u_CloudTracing.y < 0.5)
        rayEnd = rayStart + min(u_CloudLayerRadii.w, rayEnd - rayStart);
    else
    {
        rayStart = min(u_CloudLayerRadii.w, rayStart);
        if (innerNear > 0.0 && innerFar > 0.0 && max(innerNear, innerFar) <= u_CloudLayerRadii.w)
            rayEnd = min(u_CloudLayerRadii.w, max(outerNear, outerFar));
        else
            rayEnd = min(rayEnd, u_CloudLayerRadii.w);
    }
    rayStart = max(rayStart, u_CloudLayerRadii.z);
    rayEnd = max(rayStart, rayEnd);

    hfloat rayLength = rayEnd - rayStart;
    if (rayLength <= 0.0001)
    {
        return;
    }

    int stepCount = max(2, int(u_CloudSampling.x * saturate(rayLength / u_CloudSampling.w)));
    hfloat stepLength = rayLength / hfloat_init(stepCount);
    hfloat transmittance = 1.0;
    hvec3 scattering = hvec3_init(0.0, 0.0, 0.0);
    hfloat frontDepth = sceneDistance;
    hfloat nearestTransmittance = 1.0;
    hvec3 nearestScattering = hvec3_init(0.0, 0.0, 0.0);
    hfloat nearestDepthSum = 0.0;
    hfloat nearestDepthWeight = 0.0;
    hfloat depthWeightedSum = 0.0;
    hfloat depthWeight = 0.0;
    hfloat lightCosTheta = dot(normalize(u_CloudLightDirection.xyz), rayDirection);
    hfloat phase = CloudDualPhase(lightCosTheta);
    hvec3 lightDirection = normalize(u_CloudLightDirection.xyz);
#ifdef CLOUD_SAMPLE_SECOND_LIGHT
    hvec3 lightDirection1 = u_AtmosphereLightDirection1.xyz;
    hfloat phase1 = CloudDualPhase(dot(lightDirection1, rayDirection));
    hfloat phases1[3];
    phases1[0] = phase1;
#endif
    hvec3 skyLuminance = u_CloudSkyColor.rgb;
#ifdef CLOUD_DISTANT_SKY_LIGHT
    skyLuminance = texture2DLod(u_CloudDistantSkyLight2, hvec2_init(0.5, 0.5), 0.0).rgb;
#endif
    hvec3 materialAlbedo = saturate(u_CloudFeatures.z > 0.5 ? u_CloudMaterial.rrr : u_CloudMaterial.rgb);
    hfloat scatteringFactors[3];
    hfloat extinctionFactors[3];
    hfloat phases[3];
    scatteringFactors[0] = 1.0;
    extinctionFactors[0] = 1.0;
    phases[0] = phase;
    hfloat scatteringFactor = u_CloudAdvanced.z;
    hfloat extinctionFactor = u_CloudMultiScattering.x;
    hfloat phaseFactor = u_CloudMultiScattering.y;
    // UE SetupParticipatingMediaContext and SetupParticipatingMediaPhaseContext.
    for (int order = 1; order < 3; ++order)
    {
        scatteringFactors[order] = scatteringFactors[order - 1] * scatteringFactor;
        extinctionFactors[order] = extinctionFactors[order - 1] * extinctionFactor;
        phases[order] = lerp(0.07957747155, phase, phaseFactor);
#ifdef CLOUD_SAMPLE_SECOND_LIGHT
        phases1[order] = lerp(0.07957747155, phase1, phaseFactor);
#endif
        scatteringFactor *= scatteringFactor;
        extinctionFactor *= extinctionFactor;
        phaseFactor *= phaseFactor;
    }

    LOOP for (int i = 0; i < stepCount; ++i)
    {
        if (i >= stepCount || transmittance <= u_CloudDensityParams.y)
            break;

        CLOUD_GEOMETRY_PRECISE hfloat sampleDistance = rayStart + (hfloat_init(i) + jitter) * stepLength;
        CLOUD_GEOMETRY_PRECISE hvec3 samplePosition = cameraPosition + rayDirection * sampleDistance;
        CLOUD_GEOMETRY_PRECISE hfloat height = (length(samplePosition - u_CloudPlanetCenter.xyz) - u_CloudLayerRadii.x) /
            max(u_CloudLayerRadii.y - u_CloudLayerRadii.x, 0.001);
        if (height < 0.0 || height > 1.0)
            continue;

        hfloat density = CloudDensity(samplePosition, height);
        if (density <= 0.0 && max(max(u_CloudEmissive.r, u_CloudEmissive.g), u_CloudEmissive.b) <= 0.0)
            continue;

        frontDepth = min(frontDepth, sampleDistance);

        // UE uses view-transmittance-weighted cloud distance for reprojection.
        // Keep the true front distance separately for foreground composition.
        if (density > 0.0)
        {
            depthWeightedSum += sampleDistance * transmittance;
            depthWeight += transmittance;
            if (sampleDistance <= nearestDistance)
            {
                nearestDepthSum += sampleDistance * transmittance;
                nearestDepthWeight += transmittance;
            }
        }
        hvec3 lightIlluminance = u_CloudLightColor.rgb;
#ifdef CLOUD_PER_SAMPLE_ATMOSPHERE_TRANSMITTANCE
        lightIlluminance *= SampleAtmosphereSunTransmittance(
            (samplePosition - u_AtmospherePlanetCenter.xyz) * 0.001, lightDirection, u_CloudAtmosphereTransmittance1);
#endif

        hfloat opticalDepth = density > 0.0 ? CloudLightOpticalDepth(samplePosition, lightDirection) : 0.0;
        hvec3 groundIlluminance = lightIlluminance;
#ifdef CLOUD_SAMPLE_SECOND_LIGHT
        hvec3 lightIlluminance1 = u_CloudLightColor1.rgb;
#ifdef CLOUD_PER_SAMPLE_ATMOSPHERE_TRANSMITTANCE
        lightIlluminance1 *= SampleAtmosphereSunTransmittance(
            (samplePosition - u_AtmospherePlanetCenter.xyz) * 0.001, lightDirection1, u_CloudAtmosphereTransmittance1);
#endif
        hfloat opticalDepth1 = density > 0.0 ? CloudLightOpticalDepth(samplePosition, lightDirection1) : 0.0;
        groundIlluminance += lightIlluminance1;
#endif
        hfloat skyVisibility = saturate(1.0 - u_CloudEmissive.w + height);
        hvec3 radial = normalize(samplePosition - u_CloudPlanetCenter.xyz);
        hfloat altitude = height * (u_CloudLayerRadii.y - u_CloudLayerRadii.x);
        hvec3 groundLighting = hvec3_init(0.0, 0.0, 0.0);
        if (u_CloudMultiScattering.w > 0.5 && transmittance > 0.01 && density > 0.0)
            // UE 5.5.4 uses the primary light's NdotL for both ground contributions.
            groundLighting = groundIlluminance * u_CloudGroundAlbedo.rgb *
                (saturate(dot(lightDirection, radial)) / 6.28318530718) *
                exp(-CloudGroundOpticalDepth(samplePosition, -radial, altitude));
        hvec3 ambientLighting = skyLuminance * skyVisibility + groundLighting;
        hvec3 sampleIntegral = hvec3_init(0.0, 0.0, 0.0);
        // Descending order leaves the view-transmittance update until order zero.
        for (int octave = 2; octave >= 0; --octave)
        {
            if (hfloat_init(octave) > u_CloudMultiScattering.z)
                continue;
            hvec3 incident = lightIlluminance * (exp(-opticalDepth * extinctionFactors[octave]) * phases[octave]);
#ifdef CLOUD_SAMPLE_SECOND_LIGHT
            incident += lightIlluminance1 * (exp(-opticalDepth1 * extinctionFactors[octave]) * phases1[octave]);
#endif
            if (octave == 0)
                incident += ambientLighting;
            hfloat extinction = max(density * extinctionFactors[octave], 0.000001);
            hvec3 source = incident * materialAlbedo * (density * scatteringFactors[octave]) + u_CloudEmissive.rgb;
            // Analytical constant-coefficient segment integral (UE/Frostbite).
            sampleIntegral += source * ((1.0 - exp(-extinction * stepLength)) / extinction);
        }
        scattering += sampleIntegral * transmittance;
        if (sampleDistance <= nearestDistance)
            nearestScattering += sampleIntegral * transmittance;
        if (sampleDistance < nearestDistance)
            nearestTransmittance *= exp(-max(density, 0.000001) * stepLength);
        transmittance *= exp(-max(density, 0.000001) * stepLength);
    }

#ifdef CLOUD_AERIAL_PERSPECTIVE
#ifdef CLOUD_REFLECTION_CAPTURE
    // UE GetAerialPerspectiveLuminanceTransmittance inverse 360 mapping; all six faces sample the same frozen volume.
    hfloat cosPhi = sqrt(max(0.0, 1.0 - rayDirection.y * rayDirection.y));
    hfloat theta = acos(clamp(rayDirection.x / max(cosPhi, 1e-6), -1.0, 1.0));
    theta = rayDirection.z < 0.0 ? 6.28318530718 - theta : theta;
    uv = hvec2_init(theta / 6.28318530718, rayDirection.y * 0.5 + 0.5);
    uv = (uv + 0.5 / 32.0) * (32.0 / 33.0);
#else
    // UE derives AP UV from the cloud world ray projected into the AP camera, not the trace-grid UV.
    // A shared volume may have been generated by a jittered opaque pass before this unjittered cloud pass.
    hvec4 apClip = mul(hvec4_init(rayDirection, 0.0), u_AtmosphereAPViewProj);
    uv = apClip.xy / apClip.w * 0.5 + 0.5;
#if !BGFX_SHADER_LANGUAGE_GLSL
    uv.y = 1.0 - uv.y;
#endif
#endif
    if (depthWeight > 0.0)
    {
        hvec4 ap = SampleAtmosphereAP(uv, depthWeightedSum / depthWeight * 0.001,
            u_AtmosphereAPParams, u_CloudAerialPerspective3);
        scattering = ap.rgb * (1.0 - transmittance) + ap.a * scattering;
    }
#endif
#ifdef CLOUD_AERIAL_PERSPECTIVE
    if (nearestDepthWeight > 0.0)
    {
        hvec4 ap = SampleAtmosphereAP(uv, nearestDepthSum / nearestDepthWeight * 0.001,
            u_AtmosphereAPParams, u_CloudAerialPerspective3);
        nearestScattering = ap.rgb * (1.0 - nearestTransmittance) + ap.a * nearestScattering;
    }
#endif
    transmittance = transmittance < u_CloudDensityParams.y ? 0.0 : transmittance;
    nearestTransmittance = nearestTransmittance < u_CloudDensityParams.y ? 0.0 : nearestTransmittance;
    farResult = hvec4_init(scattering, transmittance);
    nearResult = hvec4_init(nearestScattering, nearestTransmittance);
    representativeDepth = (transmittance > 0.99 || depthWeight == 0.0 ? rayEnd : depthWeightedSum / max(depthWeight, 1e-10)) * 0.001;
    debugResult = hvec4_init(transmittance, frontDepth * 0.001, rayEnd * 0.001, phase);
}
