#ifndef REFLECTION_ENVIRONMENT_SH
#define REFLECTION_ENVIRONMENT_SH

#ifdef REFLECTION_PROBES
#include "Cluster/ReflectionProbes.sh"
SAMPLERCUBEARRAY(s_ReflectionCubeArray, 5);
#else
SAMPLERCUBE(u_ReflectionZone5, 5);
#endif
SAMPLER2D(u_ReflectionDFG9, 9);
uniform hvec4 u_ReflectionEnvironment;

hvec2 ReflectionBRDFTerms(hfloat roughness, hfloat noV)
{
    hvec2 ab = texture2D(u_ReflectionDFG9, hvec2_init(noV, roughness)).rg;
    if (u_ReflectionEnvironment.z < 0.5)
    {
        // Resource-allocation fallback only. Normal rendering uses the UE preintegrated table.
        hvec4 r = roughness * hvec4_init(-1.0, -0.0275, -0.572, 0.022) + hvec4_init(1.0, 0.0425, 1.04, -0.04);
        hfloat a = min(r.x * r.x, exp2(-9.28 * noV)) * r.x + r.y;
        ab = hvec2_init(-1.04, 1.04) * a + r.zw;
    }
    return ab;
}

hvec3 ReflectionBRDF(hvec3 f0, hfloat roughness, hfloat noV)
{
    hvec2 ab = ReflectionBRDFTerms(roughness, noV);
    return f0 * ab.x + saturate(50.0 * f0.g) * ab.y;
}

hvec3 ReflectionZoneRadiance(hvec3 ray, hfloat roughness)
{
    if (u_ReflectionEnvironment.y < 0.5)
        return hvec3_init(0.0, 0.0, 0.0);
    ray.zx = hvec2_init(dot(ray.zx, hvec2_init(u_SinCosEnvCubeAngle.w, -u_SinCosEnvCubeAngle.z)),
        dot(ray.zx, u_SinCosEnvCubeAngle.zw));
    hfloat mip = roughness * (1.7 - 0.7 * roughness) * 6.0;
#ifdef REFLECTION_PROBES
    hvec4 sampleValue = textureCubeArrayLod(s_ReflectionCubeArray, hvec4_init(ray, 0.0), mip);
#else
    hvec4 sampleValue = textureCubeLod(u_ReflectionZone5, ray, mip);
#endif
#ifdef URHO3D_MOBILE
    sampleValue.rgb *= sampleValue.a * 6.0;
#endif
    return sampleValue.rgb * cEnvSpecTextureIntensity + cAmbientColor.rgb;
}

#ifdef REFLECTION_PROBES
hvec3 ReflectionProjection(ReflectionProbe probe, hvec3 position, hvec3 ray, out hfloat alpha)
{
    alpha = 0.0;
    hvec3 local = position - probe.positionRadius.xyz;
    hfloat distanceSquared = dot(local, local);
    hfloat radius = probe.positionRadius.w;
    if (distanceSquared >= radius * radius)
        return ray;
    if (probe.shapeSlotTransition.x < 0.5)
    {
        // Match UE's A=1 quadratic and its unnormalized off-specular peak direction.
        hfloat b = dot(ray, local);
        hfloat t = sqrt(max(b * b - distanceSquared + radius * radius, 0.0)) - b;
        hfloat x = saturate(2.5 * sqrt(distanceSquared) / radius - 1.5);
        alpha = 1.0 - x * x * (3.0 - 2.0 * x);
        return position + t * ray - probe.capturePositionBrightness.xyz;
    }
    hvec4 world = hvec4_init(position, 1.0);
    hvec3 localPosition = hvec3_init(dot(probe.worldToBox0, world), dot(probe.worldToBox1, world), dot(probe.worldToBox2, world));
    if (any(greaterThan(abs(localPosition), probe.boxHalfSize)))
        return ray;
    hvec3 start = localPosition / probe.boxHalfSize;
    hvec3 dir = hvec3_init(dot(probe.worldToBox0.xyz, ray), dot(probe.worldToBox1.xyz, ray), dot(probe.worldToBox2.xyz, ray)) / probe.boxHalfSize;
    // Axial rays must not produce 0*infinity on a box face.
    hvec3 safeDir = hvec3_init(dir.x < 0.0 ? -max(abs(dir.x), 1e-8) : max(abs(dir.x), 1e-8),
        dir.y < 0.0 ? -max(abs(dir.y), 1e-8) : max(abs(dir.y), 1e-8),
        dir.z < 0.0 ? -max(abs(dir.z), 1e-8) : max(abs(dir.z), 1e-8));
    hvec3 farPlanes = max((-1.0 - start) / safeDir, (1.0 - start) / safeDir);
    hfloat t = max(min(farPlanes.x, min(farPlanes.y, farPlanes.z)), 0.0);
    hfloat transition = probe.shapeSlotTransition.z;
    hvec3 innerSize = max(probe.boxHalfSize - 0.5 * transition, hvec3_init(0.0, 0.0, 0.0));
    hfloat boxDistance = length(max(abs(localPosition) - innerSize, hvec3_init(0.0, 0.0, 0.0)));
    alpha = transition > 0.0 ? 1.0 - smoothstep(0.0, 0.7 * transition, boxDistance) : 1.0;
    return position + t * ray - probe.capturePositionBrightness.xyz;
}
#endif

hvec3 ReflectionRadianceForRay(hvec2 uv, hfloat eyeDepth, hvec3 position, hvec3 ray,
    hfloat roughness, hfloat occlusion, hvec4 ssr)
{
    hvec3 radiance = ssr.rgb;
    hfloat remaining = 1.0 - saturate(ssr.a);
#ifdef REFLECTION_PROBES
    uvec3 cell = GetReflectionProbeCell(GetReflectionCluster(uv, eyeDepth));
    hfloat mip = clamp(u_ReflectionEnvironment.x - 3.0 + 1.2 * log2(max(roughness, 0.001)), 0.0, u_ReflectionEnvironment.x - 1.0);
    for (uint i = 0u; i < cell.y; ++i)
    {
        if (remaining < 0.001)
            break;
        uint index = b_clusterLightIndices[cell.x + i];
        if (index >= uint(u_ReflectionProbeGrid.x))
            continue;
        ReflectionProbe probe = GetReflectionProbe(index);
        hfloat distanceAlpha;
        hvec3 lookup = ReflectionProjection(probe, position, ray, distanceAlpha);
        if (distanceAlpha <= 0.0)
            continue;
        hvec4 sampleValue = textureCubeArrayLod(s_ReflectionCubeArray, hvec4_init(lookup, probe.shapeSlotTransition.y), mip);
        sampleValue.rgb *= probe.capturePositionBrightness.w;
        sampleValue *= distanceAlpha;
        radiance += remaining * sampleValue.rgb * occlusion;
        remaining *= 1.0 - saturate(sampleValue.a);
    }
#endif
    return radiance + remaining * ReflectionZoneRadiance(ray, roughness) * occlusion;
}

hfloat ReflectionSpecularOcclusion(hfloat noV, hfloat roughness, hfloat ao)
{
    return saturate(pow(noV + saturate(ao), roughness * roughness) - 1.0 + saturate(ao)) * cAmbientOcclusionIntensity;
}

hvec3 ReflectionRadiance(hvec2 uv, hfloat eyeDepth, hvec3 position, hvec3 normal, hvec3 view,
    hfloat roughness, hfloat ao, hvec4 ssr)
{
    hfloat noV = saturate(dot(normal, view));
    hfloat a = roughness * roughness;
    hvec3 reflected = 2.0 * dot(normal, view) * normal - view;
    hvec3 ray = mix(normal, reflected, (1.0 - a) * (sqrt(1.0 - a) + a));
    return ReflectionRadianceForRay(uv, eyeDepth, position, ray, roughness, ReflectionSpecularOcclusion(noV, roughness, ao), ssr);
}
#endif
