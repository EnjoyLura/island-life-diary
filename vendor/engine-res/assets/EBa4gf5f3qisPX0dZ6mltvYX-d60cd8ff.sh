// UE 5.5.4 SkyAtmosphere.usf IntegrateSingleScatteredLuminance, combined RGB branch.
// Ground, phase, sample distribution and distance scale are selected by the caller.
#include "Sky/SkyAtmosphereCommon.sh"
#if defined(ATMOSPHERE_CLOUD_SHADOW) || defined(ATMOSPHERE_CLOUD_SKY_AO)
#include "Volumetric/VolumetricCloudShadowCommon.sh"
#endif
#ifdef ATMOSPHERE_CLOUD_SHADOW
SAMPLER2D(u_AtmosphereCloudShadow2, 2);
uniform hmat4 u_CloudShadowWorldToUV;
uniform hvec4 u_CloudShadowParams;
#endif
#ifdef ATMOSPHERE_CLOUD_SKY_AO
SAMPLER2D(u_AtmosphereCloudSkyAO3, 3);
uniform hmat4 u_CloudSkyAOWorldToUV;
uniform hvec4 u_CloudSkyAOParams;
#endif


#ifndef ATMOSPHERE_TRANSMITTANCE_PASS
SAMPLER2D(u_AtmosphereTransmittance0, 0);
#endif
#ifdef ATMOSPHERE_MULTIPLE_SCATTERING
SAMPLER2D(u_AtmosphereMultiScatter1, 1);
#endif

hvec3 AtmosphereTransmittance(hfloat height, hfloat zenith)
{
#ifdef ATMOSPHERE_TRANSMITTANCE_PASS
    return hvec3_init(1.0, 1.0, 1.0);
#else
    return texture2DLod(u_AtmosphereTransmittance0, AtmosphereTransmittanceUV(height, zenith), 0.0).rgb;
#endif
}

hvec3 AtmosphereMultipleScattering(hvec3 position, hfloat zenith)
{
#ifdef ATMOSPHERE_MULTIPLE_SCATTERING
    hvec2 uv = saturate(hvec2_init(zenith * 0.5 + 0.5, (length(position) - u_AtmosphereRadii.x) / (u_AtmosphereRadii.y - u_AtmosphereRadii.x)));
    return texture2DLod(u_AtmosphereMultiScatter1, uv, 0.0).rgb;
#else
    return hvec3_init(0.0, 0.0, 0.0);
#endif
}

struct AtmosphereIntegral
{
    hvec3 luminance;
    hvec3 opticalDepth;
    hvec3 transmittance;
    hvec3 multiScatAsOne;
};

AtmosphereIntegral IntegrateAtmosphere(hvec3 origin, hvec3 direction, bool ground, bool mieRayPhase,
    hfloat sampleCount, bool variableSamples, hfloat minimumSamples, hfloat maximumSamples, hfloat distanceToMaxInv,
    hvec3 lightDirection0, hvec3 lightDirection1, hvec3 illuminance0, hvec3 illuminance1, hfloat distanceScale, hfloat maxDistance, hfloat sampleOffset)
{
    AtmosphereIntegral result;
    result.luminance = hvec3_init(0.0, 0.0, 0.0);
    result.opticalDepth = hvec3_init(0.0, 0.0, 0.0);
    result.transmittance = hvec3_init(1.0, 1.0, 1.0);
    result.multiScatAsOne = hvec3_init(0.0, 0.0, 0.0);
    if (dot(origin, origin) <= u_AtmosphereRadii.x * u_AtmosphereRadii.x)
        return result;

    // Use UE's active two-root branch, including the ground hit at distance zero.
    hvec2 bottomHits = AtmosphereRaySphere(origin, direction, u_AtmosphereRadii.x);
    hvec2 topHits = AtmosphereRaySphere(origin, direction, u_AtmosphereRadii.y);
    if (all(lessThan(topHits, hvec2_init(0.0, 0.0))))
        return result;
    hfloat bottomDistance = 0.0;
    hfloat distance = max(topHits.x, topHits.y);
    if (!all(lessThan(bottomHits, hvec2_init(0.0, 0.0))))
    {
        bottomDistance = max(0.0, min(bottomHits.x, bottomHits.y));
        distance = bottomDistance;
    }
    distance = min(distance, maxDistance);
    hfloat countFloor = sampleCount;
    hfloat distanceFloor = distance;
    if (variableSamples)
    {
        sampleCount = mix(minimumSamples, maximumSamples, saturate(distance * distanceToMaxInv));
        countFloor = floor(sampleCount);
        distanceFloor = distance * countFloor / sampleCount;
    }
    hfloat stepLength = distance / sampleCount;
    hfloat cosine0 = dot(lightDirection0, direction);
    hfloat cosine1 = dot(lightDirection1, direction);
    hfloat miePhase0 = mieRayPhase ? AtmosphereMiePhase(cosine0) : 0.07957747154594767;
    hfloat miePhase1 = mieRayPhase ? AtmosphereMiePhase(cosine1) : 0.07957747154594767;
    hfloat rayPhase0 = mieRayPhase ? AtmosphereRayleighPhase(cosine0) : 0.07957747154594767;
    hfloat rayPhase1 = mieRayPhase ? AtmosphereRayleighPhase(cosine1) : 0.07957747154594767;

    LOOP for (hfloat sampleIndex = 0.0; sampleIndex < sampleCount; sampleIndex += 1.0)
    {
        hfloat t = distance * (sampleIndex + sampleOffset) / sampleCount;
        if (variableSamples)
        {
            hfloat t0 = sampleIndex / countFloor;
            hfloat t1 = (sampleIndex + 1.0) / countFloor;
            t0 *= t0;
            t1 *= t1;
            t0 *= distanceFloor;
            t1 = t1 > 1.0 ? distance : distanceFloor * t1;
            t = t0 + (t1 - t0) * sampleOffset;
            stepLength = t1 - t0;
        }
        hvec3 position = origin + t * direction;
        hfloat height = length(position);
        hvec3 up = position / height;
        AtmosphereMedium medium = SampleAtmosphereMedium(position);
        hvec3 opticalDepth = medium.extinction * stepLength * distanceScale;
        hvec3 segmentT = exp(-opticalDepth);
        result.opticalDepth += opticalDepth;
        hfloat zenith0 = dot(lightDirection0, up);
        hfloat zenith1 = dot(lightDirection1, up);
        hfloat planetShadow0 = AtmosphereNearestSphere(position - 0.001 * up, lightDirection0, u_AtmosphereRadii.x) >= 0.0 ? 0.0 : 1.0;
        hfloat planetShadow1 = AtmosphereNearestSphere(position - 0.001 * up, lightDirection1, u_AtmosphereRadii.x) >= 0.0 ? 0.0 : 1.0;
        hvec3 phaseScattering0 = medium.mie * miePhase0 + medium.rayleigh * rayPhase0;
        hvec3 phaseScattering1 = medium.mie * miePhase1 + medium.rayleigh * rayPhase1;
        hfloat skyVisibility = 1.0;
#ifdef ATMOSPHERE_CLOUD_SHADOW
        planetShadow0 *= SampleCloudShadow(position * 1000.0 + u_AtmospherePlanetCenter.xyz,
            u_CloudShadowWorldToUV, u_CloudShadowParams.x, u_AtmosphereCloudShadow2);
#endif
#ifdef ATMOSPHERE_CLOUD_SKY_AO
        skyVisibility = SampleCloudShadow(position * 1000.0 + u_AtmospherePlanetCenter.xyz,
            u_CloudSkyAOWorldToUV, u_CloudSkyAOParams.x, u_AtmosphereCloudSkyAO3);
#endif
        hvec3 source = illuminance0 * (planetShadow0 * AtmosphereTransmittance(height, zenith0) * phaseScattering0 +
            AtmosphereMultipleScattering(position, zenith0) * skyVisibility * medium.scattering);
        source += illuminance1 * (planetShadow1 * AtmosphereTransmittance(height, zenith1) * phaseScattering1 +
            AtmosphereMultipleScattering(position, zenith1) * medium.scattering);
        // Active MULTI_SCATTERING_POWER_SERIE=0 branch: this term uses a Riemann sum.
        result.multiScatAsOne += result.transmittance * medium.scattering * stepLength;
        result.luminance += result.transmittance * (source - source * segmentT) / max(medium.extinction, hvec3_init(1e-9, 1e-9, 1e-9));
        result.transmittance *= segmentT;
    }
    if (ground && distance == bottomDistance)
    {
        hvec3 position = origin + bottomDistance * direction;
        hfloat height = length(position);
        hvec3 up = position / height;
        hfloat zenith0 = dot(lightDirection0, up);
        hfloat zenith1 = dot(lightDirection1, up);
        hvec3 bounced = illuminance0 * AtmosphereTransmittance(height, zenith0) * saturate(zenith0);
        bounced += illuminance1 * AtmosphereTransmittance(height, zenith1) * saturate(zenith1);
        result.luminance += bounced * result.transmittance * u_AtmosphereGround.rgb / 3.141592653589793;
    }
    return result;
}
