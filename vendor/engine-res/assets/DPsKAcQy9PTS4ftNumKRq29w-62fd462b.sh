// Shared UE default cloud material, scattering parameters and shadow integrals.
#ifndef VOLUMETRIC_CLOUD_MATERIAL_SH
#define VOLUMETRIC_CLOUD_MATERIAL_SH

// Keep planet-scale geometry invariant when FXC compiles different light permutations.
#if BGFX_SHADER_LANGUAGE_HLSL
#define CLOUD_GEOMETRY_PRECISE precise
#else
#define CLOUD_GEOMETRY_PRECISE
#endif
#ifndef CLOUD_SHADOW_WORLD
#ifdef COMPILECS
SAMPLER2D(u_CloudSceneDepth4, 4);
#define u_DepthBuffer0 u_CloudSceneDepth4
#else
SAMPLER2D(u_DepthBuffer0, 0);
#endif
#endif
#ifdef CLOUD_ATMOSPHERE
#include "Sky/SkyAtmosphereCommon.sh"
#ifdef COMPILECS
SAMPLER2D(u_CloudAtmosphereTransmittance5, 5);
#define u_CloudAtmosphereTransmittance1 u_CloudAtmosphereTransmittance5
#else
SAMPLER2D(u_CloudAtmosphereTransmittance1, 1);
#endif
#ifdef COMPILECS
SAMPLER2D(u_CloudDistantSkyLight6, 6);
#define u_CloudDistantSkyLight2 u_CloudDistantSkyLight6
#else
SAMPLER2D(u_CloudDistantSkyLight2, 2);
#endif
#ifdef COMPILECS
SAMPLER3D(u_CloudAerialPerspective7, 7);
#define u_CloudAerialPerspective3 u_CloudAerialPerspective7
#else
SAMPLER3D(u_CloudAerialPerspective3, 3);
#endif
uniform hvec4 u_AtmosphereAPParams;
#endif
#ifdef COMPILECS
SAMPLER2D(u_CloudWeatherMap10, 10);
#define u_CloudWeatherMap6 u_CloudWeatherMap10
#else
SAMPLER2D(u_CloudWeatherMap6, 6);
#endif
#ifdef COMPILECS
SAMPLER3D(u_CloudShapeNoise11, 11);
#define u_CloudShapeNoise7 u_CloudShapeNoise11
#else
SAMPLER3D(u_CloudShapeNoise7, 7);
#endif
#ifdef COMPILECS
SAMPLER2D(u_CloudHeightProfile13, 13);
#define u_CloudHeightProfile9 u_CloudHeightProfile13
#else
SAMPLER2D(u_CloudHeightProfile9, 9);
#endif
#ifdef COMPILECS
SAMPLER2D(u_CloudBlueNoise14, 14);
#define u_CloudBlueNoise10 u_CloudBlueNoise14
#else
SAMPLER2D(u_CloudBlueNoise10, 10);
#endif

uniform hvec4 u_CloudPlanetCenter;
uniform hvec4 u_CloudLayerRadii;
uniform hvec4 u_CloudDensityParams;
uniform hvec4 u_CloudMaterial;
uniform hvec4 u_CloudEmissive;
uniform hvec4 u_CloudLightDirection;
uniform hvec4 u_CloudLightColor;
#ifdef CLOUD_SAMPLE_SECOND_LIGHT
uniform hvec4 u_CloudLightColor1;
#endif
uniform hvec4 u_CloudSkyColor;
uniform hmat4 u_CloudInvViewProj;
uniform hvec4 u_CloudCamera;
uniform hvec4 u_CloudFrame;
uniform hvec4 u_CloudFeatures;
uniform hvec4 u_CloudGroundAlbedo;
// x = secondary HG g, y = secondary lobe blend, z = extra-octave scattering factor,
// w = enable the default material conservative coverage early-out.
uniform hvec4 u_CloudAdvanced;
// x = extinction reduction, y = phase reduction, z = extra octaves [0, 2], w = ground contribution.
uniform hvec4 u_CloudMultiScattering;
uniform hvec4 u_CloudSampling;
uniform hvec4 u_CloudTracing;
uniform hvec4 u_CloudLayout;
uniform hmat4 u_CloudShadowWorldToUV;
uniform hmat4 u_CloudShadowInvViewProj;
uniform hvec4 u_CloudShadowParams;
uniform hvec4 u_CloudShadowDirection;
#include "Volumetric/VolumetricCloudShadowCommon.sh"

hvec4 ReconstructCloudWorldPosition(hvec2 uv, hfloat depth)
{
    hvec4 clip = ScreenUVToClip(uv, depth);
    hvec4 world = mul(clip, u_CloudInvViewProj);
    return world / world.w;
}

bool IntersectCloudSphere(hvec3 origin, hvec3 direction, hvec3 center, hfloat radius, out hfloat nearHit,
    out hfloat farHit)
{
    // Match UE's RayIntersectSphereSolution in kilometers; return engine-meter distances.
    CLOUD_GEOMETRY_PRECISE hvec3 offset = (origin - center) * 0.001;
    CLOUD_GEOMETRY_PRECISE hfloat radiusKm = radius * 0.001;
    CLOUD_GEOMETRY_PRECISE hfloat a = dot(direction, direction);
    CLOUD_GEOMETRY_PRECISE hfloat b = 2.0 * dot(offset, direction);
    CLOUD_GEOMETRY_PRECISE hfloat c = dot(offset, offset) - radiusKm * radiusKm;
    CLOUD_GEOMETRY_PRECISE hfloat discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0)
        return false;

    CLOUD_GEOMETRY_PRECISE hfloat root = sqrt(discriminant);
    nearHit = (-b - root) / (2.0 * a) * 1000.0;
    farHit = (-b + root) / (2.0 * a) * 1000.0;
    return farHit >= 0.0;
}

hfloat CloudPhase(hfloat cosTheta, hfloat g)
{
    hfloat g2 = g * g;
    hfloat denominator = max(1.0 + g2 - 2.0 * g * cosTheta, 0.0001);
    return (1.0 - g2) / (12.5663706144 * denominator * sqrt(denominator));
}

hfloat CloudDualPhase(hfloat cosTheta)
{
    hfloat primary = CloudPhase(cosTheta, u_CloudMaterial.w);
    hfloat secondary = CloudPhase(cosTheta, u_CloudAdvanced.x);
    return lerp(primary, secondary, saturate(u_CloudAdvanced.y));
}

/// Evaluate the default UE m_SimpleVolumetricCloud graph (StormClouds=0, UseNoise3=false).
/// World meters are swizzled from Y-up to the material's Z-up coordinates before km scaling.
hfloat CloudDensity(hvec3 samplePosition, hfloat normalizedHeight)
{
    if (u_CloudLayout.w < 0.5 || normalizedHeight < 0.02 || normalizedHeight > 0.98)
        return 0.0;

    hvec3 weatherCoord = samplePosition.xzy / u_CloudLayout.x + hvec3_init(0.5, 0.5, 0.0);
    hvec3 cloudTypes = texture2DLod(u_CloudWeatherMap6, weatherCoord.xy - 0.5, 0.0).rgb;
    hfloat coverage = max(max(cloudTypes.r, cloudTypes.g), cloudTypes.b);
    // ConservativeDensity.r is the maximum of the three layout channels, not a density dilation.
    if (coverage <= 0.0 && u_CloudAdvanced.w > 0.0)
        return 0.0;

    hfloat profileR = texture2DLod(u_CloudHeightProfile9, hvec2_init(normalizedHeight, cloudTypes.r), 0.0).r;
    hfloat profileG = texture2DLod(u_CloudHeightProfile9, hvec2_init(normalizedHeight, cloudTypes.g), 0.0).g;
    hfloat profileB = texture2DLod(u_CloudHeightProfile9, hvec2_init(normalizedHeight, cloudTypes.b), 0.0).b;
    hfloat profile = max(max(profileR, profileG), profileB) - 0.5;

    // CloudWind: velocity * VelocityScale * Time / (PatternWidth / GlobalScaleKm * 1000).
    hvec3 wind = hvec3_init(u_CloudDensityParams.zw, 0.5) * 0.333333 *
        u_CloudCamera.w * u_CloudLayout.x / (u_CloudLayout.z * 1000000.0);
    hvec3 noise2Uv = weatherCoord * hvec3_init(60.0, 60.0, 75.0) - wind * 6.0;
    hfloat noise2 = (texture3DLod(u_CloudShapeNoise7, noise2Uv, 0.0).r - 0.8) * 0.08;
    CLOUD_GEOMETRY_PRECISE hfloat height = normalizedHeight * 0.95 + 0.05;
    hfloat heightShape = abs(height - 0.5) * 2.0;
    hvec3 distortion = hvec3_init(height, height, heightShape * heightShape) * noise2;
    hvec3 noise1Uv = weatherCoord * hvec3_init(4.167, 4.444, 9.091) + wind * 7.0 + distortion;
    hfloat noise1 = (texture3DLod(u_CloudShapeNoise7, noise1Uv, 0.0).g - 0.5 + u_CloudLayout.y) * 0.8;
    // ConservativeDensity.g * (ConservativeDensity.b + ConservativeDensity.a), then per-meter density.
    hfloat density = coverage * (profile + noise1) * (0.008 * max(u_CloudDensityParams.x, 0.0));
    hfloat cameraFade = saturate(length(samplePosition - u_CloudCamera.xyz) * 0.002);
    return saturate(density * cameraFade);
}

/// Match BlueNoiseScalar(ScreenCoord, StateFrameIndexMod8), using exact texel centers.
hfloat CloudRayJitter(hvec2 uv)
{
    hvec2 pixel = floor(uv / cGBufferInvSize);
    hvec2 wrapped = pixel - floor(pixel / 128.0) * 128.0;
    hfloat frame = u_CloudFrame.x - floor(u_CloudFrame.x / 8.0) * 8.0;
    hvec2 noiseUV = (wrapped + hvec2_init(0.5, frame * 128.0 + 0.5)) / hvec2_init(128.0, 8192.0);
    return texture2DLod(u_CloudBlueNoise10, noiseUV, 0.0).r;
}

/// Integrate light-path extinction in meters using UE 5.5's quadratic segment distribution.
/// The scaled budget matches BaseShadowRaySampleCount and is independent of the view-ray step.
hfloat CloudLightOpticalDepth(hvec3 samplePosition, hvec3 lightDirection)
{
    int shadowStepCount = int(u_CloudSampling.y);
    hfloat shadowDistance = u_CloudSampling.z;
    hfloat opticalDepth = 0.0;
    hfloat previousT = 0.0;
    LOOP for (int i = 1; i <= shadowStepCount; ++i)
    {
        hfloat t = hfloat_init(i) / hfloat_init(shadowStepCount);
        t *= t;
        hfloat segmentLength = (t - previousT) * shadowDistance;
        CLOUD_GEOMETRY_PRECISE hvec3 shadowPosition = samplePosition + lightDirection *
            ((previousT + t) * 0.5 * shadowDistance);
        CLOUD_GEOMETRY_PRECISE hfloat height = (length(shadowPosition - u_CloudPlanetCenter.xyz) - u_CloudLayerRadii.x) /
            max(u_CloudLayerRadii.y - u_CloudLayerRadii.x, 0.001);
        if (height <= 0.0 || height >= 1.0)
            break;
        opticalDepth += CloudDensity(shadowPosition, height) * segmentLength;
        previousT = t;
    }
    return opticalDepth;
}

/// Trace the ground hemisphere attenuation (UE VolumetricCloud.usf ground contribution).
hfloat CloudGroundOpticalDepth(hvec3 samplePosition, hvec3 groundDirection, hfloat altitude)
{
    hfloat traceLength = min(5000.0, altitude);
    hfloat opticalDepth = 0.0;
    hfloat previousT = 0.0;
    for (int i = 1; i <= 5; ++i)
    {
        hfloat t = hfloat_init(i) / 5.0;
        t *= t;
        hvec3 position = samplePosition + groundDirection * ((previousT + t) * 0.5 * traceLength);
        CLOUD_GEOMETRY_PRECISE hfloat height = (length(position - u_CloudPlanetCenter.xyz) - u_CloudLayerRadii.x) /
            max(u_CloudLayerRadii.y - u_CloudLayerRadii.x, 0.001);
        opticalDepth += CloudDensity(position, height) * (t - previousT) * traceLength;
        previousT = t;
    }
    return opticalDepth;
}

#endif
