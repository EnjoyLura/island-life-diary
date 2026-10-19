// UE 5.5.4 SkyAtmosphereCommon.ush: planet-relative kilometers and inverse-kilometer coefficients.
// The engine is Y-up; all vectors in this include use the engine axes.
#ifndef URHO_SKY_ATMOSPHERE_COMMON
#define URHO_SKY_ATMOSPHERE_COMMON

// Keep planet-scale geometry invariant across FXC lighting permutations.
#if BGFX_SHADER_LANGUAGE_HLSL
#define ATMOSPHERE_GEOMETRY_PRECISE precise
#else
#define ATMOSPHERE_GEOMETRY_PRECISE
#endif

uniform hvec4 u_AtmosphereRadii; // bottom, top, Rayleigh density exponent, Mie density exponent
uniform hvec4 u_AtmosphereRayleigh;
uniform hvec4 u_AtmosphereMie; // scattering.rgb, phase g
uniform hvec4 u_AtmosphereMieAbsorption;
uniform hvec4 u_AtmosphereAbsorption; // extinction.rgb, tent tip altitude
uniform hvec4 u_AtmosphereAbsorptionDensity; // linear0, linear1, constant0, constant1
uniform hvec4 u_AtmosphereGround; // linear albedo.rgb, multiple scattering factor
uniform hvec4 u_AtmosphereSky; // sky luminance factor.rgb, AP distance scale
uniform hvec4 u_AtmospherePlanetCenter; // world meters.xyz, AP start depth in km
uniform hvec4 u_AtmosphereLightDirection0;
uniform hvec4 u_AtmosphereLightDirection1;
uniform hvec4 u_AtmosphereLightColor0; // outer-space illuminance, without exposure
uniform hvec4 u_AtmosphereLightColor1;

hvec2 AtmosphereRaySphere(hvec3 origin, hvec3 direction, hfloat radius)
{
    ATMOSPHERE_GEOMETRY_PRECISE hfloat a = dot(direction, direction);
    ATMOSPHERE_GEOMETRY_PRECISE hfloat b = 2.0 * dot(direction, origin);
    ATMOSPHERE_GEOMETRY_PRECISE hfloat c = dot(origin, origin) - radius * radius;
    ATMOSPHERE_GEOMETRY_PRECISE hfloat discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0)
        return hvec2_init(-1.0, -1.0);
    ATMOSPHERE_GEOMETRY_PRECISE hfloat root = sqrt(discriminant);
    return hvec2_init(-b - root, -b + root) / (2.0 * a);
}

hfloat AtmosphereNearestSphere(hvec3 origin, hvec3 direction, hfloat radius)
{
    hvec2 hit = AtmosphereRaySphere(origin, direction, radius);
    if (all(lessThan(hit, hvec2_init(0.0, 0.0))))
        return -1.0;
    if (hit.x < 0.0)
        return max(0.0, hit.y);
    if (hit.y < 0.0)
        return max(0.0, hit.x);
    return max(0.0, min(hit.x, hit.y));
}

bool AtmosphereMoveToTop(inout hvec3 position, hvec3 direction)
{
    hfloat height = length(position);
    if (height > u_AtmosphereRadii.y)
    {
        hfloat hit = AtmosphereNearestSphere(position, direction, u_AtmosphereRadii.y);
        if (hit < 0.0)
            return false;
        position += direction * hit - position / height * 0.001;
    }
    return true;
}

void AtmosphereFromTransmittanceUV(hvec2 uv, out hfloat height, out hfloat zenith)
{
    hfloat bottom = u_AtmosphereRadii.x;
    hfloat top = u_AtmosphereRadii.y;
    hfloat h = sqrt(top * top - bottom * bottom);
    hfloat rho = h * uv.y;
    height = sqrt(rho * rho + bottom * bottom);
    hfloat dMin = top - height;
    hfloat dMax = rho + h;
    hfloat d = dMin + uv.x * (dMax - dMin);
    zenith = d == 0.0 ? 1.0 : (h * h - rho * rho - d * d) / (2.0 * height * d);
    zenith = clamp(zenith, -1.0, 1.0);
}

hvec2 AtmosphereTransmittanceUV(hfloat height, hfloat zenith)
{
    hfloat bottom = u_AtmosphereRadii.x;
    hfloat top = u_AtmosphereRadii.y;
    hfloat h = sqrt(max(0.0, top * top - bottom * bottom));
    hfloat rho = sqrt(max(0.0, height * height - bottom * bottom));
    hfloat discriminant = height * height * (zenith * zenith - 1.0) + top * top;
    hfloat d = max(0.0, -height * zenith + sqrt(discriminant));
    hfloat dMin = top - height;
    hfloat dMax = rho + h;
    return hvec2_init((d - dMin) / (dMax - dMin), rho / h);
}

struct AtmosphereMedium
{
    hvec3 rayleigh;
    hvec3 mie;
    hvec3 scattering;
    hvec3 extinction;
};

AtmosphereMedium SampleAtmosphereMedium(hvec3 position)
{
    hfloat height = max(0.0, length(position) - u_AtmosphereRadii.x);
    hfloat rayDensity = exp(u_AtmosphereRadii.z * height);
    hfloat mieDensity = exp(u_AtmosphereRadii.w * height);
    hfloat absorptionDensity = height < u_AtmosphereAbsorption.w ?
        saturate(u_AtmosphereAbsorptionDensity.x * height + u_AtmosphereAbsorptionDensity.z) :
        saturate(u_AtmosphereAbsorptionDensity.y * height + u_AtmosphereAbsorptionDensity.w);
    AtmosphereMedium medium;
    medium.rayleigh = rayDensity * u_AtmosphereRayleigh.rgb;
    medium.mie = mieDensity * u_AtmosphereMie.rgb;
    medium.scattering = medium.rayleigh + medium.mie;
    medium.extinction = medium.scattering + mieDensity * u_AtmosphereMieAbsorption.rgb +
        absorptionDensity * u_AtmosphereAbsorption.rgb;
    return medium;
}

hfloat AtmosphereRayleighPhase(hfloat cosine)
{
    return 3.0 / (16.0 * 3.141592653589793) * (1.0 + cosine * cosine);
}

hfloat AtmosphereMiePhase(hfloat cosine)
{
    hfloat g = u_AtmosphereMie.w;
    hfloat denominator = 1.0 + g * g - 2.0 * g * cosine;
    return (1.0 - g * g) / (12.566370614359172 * denominator * sqrt(denominator));
}

/// UE GetAtmosphereTransmittance, including the analytic planet shadow omitted from the LUT.
hvec3 SampleAtmosphereSunTransmittance(hvec3 positionKm, hvec3 direction, sampler2D transmittanceLut)
{
    hvec2 hit = AtmosphereRaySphere(positionKm, direction, u_AtmosphereRadii.x);
    if (hit.x > 0.0 || hit.y > 0.0)
        return hvec3_init(0.0, 0.0, 0.0);
    hfloat height = length(positionKm);
    return texture2DLod(transmittanceLut, AtmosphereTransmittanceUV(height, dot(direction, positionKm / height)), 0.0).rgb;
}

/// UE combined AP depth mapping and near fade; params are start km, slice km, slice count, samples per slice.
hvec4 SampleAtmosphereAP(hvec2 uv, hfloat distanceKm, hvec4 params, sampler3D volume)
{
    hfloat depth = max(0.0, distanceKm - params.x);
    hfloat w = sqrt(depth / (params.y * params.z));
    hfloat slice = w * params.z;
    hfloat weight = slice < 0.7071067811865475 ? saturate(slice * slice * 2.0) : 1.0;
    weight *= saturate(depth * 100000.0);
    hvec4 ap = texture3DLod(volume, hvec3_init(uv, w), 0.0);
    ap.rgb *= weight;
    ap.a = 1.0 - weight * (1.0 - ap.a);
    return ap;
}

#endif
