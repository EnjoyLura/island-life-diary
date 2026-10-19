#ifndef CAPSULE_LIGHT_COMMON_HELPERS
#define CAPSULE_LIGHT_COMMON_HELPERS
/// UE New_a2 in FP32; a2 is alpha squared (perceptual roughness to the fourth power).
hfloat AreaLightNewA2(hfloat a2, hfloat sinAlpha, hfloat VoH)
{
    return a2 + 0.25 * sinAlpha * (3.0 * sqrt(a2) + sinAlpha) / (VoH + 0.001);
}

/// Return UE area-light energy compensation and apply soft-source broadening to positive a2 (r^4).
/// sinAlpha / softSinAlpha are source angular radii; lineCos is the capsule's subtended-angle cosine.
hfloat AreaLightEnergyNormalization(inout hfloat a2, hfloat VoH, hfloat sinAlpha, hfloat softSinAlpha, hfloat lineCos)
{
    a2 = saturate(a2 + softSinAlpha * softSinAlpha / (VoH * 3.6 + 0.4));
    hfloat sphereA2 = AreaLightNewA2(a2, sinAlpha, VoH);
    hfloat energy = a2 / sphereA2;
    if (lineCos < 1.0)
    {
        hfloat lineTanAlpha = sqrt((1.0001 - lineCos) / max(1.0 + lineCos, 1e-6));
        energy *= sqrt(sphereA2 / AreaLightNewA2(sphereA2, lineTanAlpha, VoH));
    }
    return energy;
}

// Closest point on line segment to ray
vec3 ClosestPointLineToRay(vec3 Line0, vec3 Line1, float Length, vec3 R)
{
	vec3 L0 = Line0;
	vec3 L1 = Line1;
	vec3 Line01 = Line1 - Line0;

	// Shortest distance
	float A = Square( Length );
	float B = dot( R, Line01 );
	float t = saturate( dot( Line0, B*R - Line01 ) / (A - B*B) );

	return Line0 + t * Line01;
}

// Closest point on sphere to ray
vec3 ClosestPointSphereToRay(vec3 L, float radius, vec3 R)
{
    vec3 closestPointOnRay = dot(L, R) * R;
    vec3 centerToRay = closestPointOnRay - L;
    float distToRay = sqrt(dot(centerToRay, centerToRay));
    return L + centerToRay * clamp(radius / (distToRay + 1e-4), 0.0, 1.0);
}

#endif // CAPSULE_LIGHT_COMMON_HELPERS

#if defined(CLEAR_COAT) && !defined(CLEAR_COAT_AREA_HELPERS)
#define CLEAR_COAT_AREA_HELPERS
struct ClearCoatAreaContext
{
    hfloat NoV;
    hfloat NoL;
    hfloat VoL;
    hfloat NoH;
    hfloat VoH;
};

/// Renormalize in FP32 before evaluating narrow-lobe dots; FP16 NoH can round to one across the highlight.
ClearCoatAreaContext GetClearCoatAreaContext(hvec3 N, hvec3 V, hvec3 L)
{
    N = normalize(N);
    V = normalize(V);
    L = normalize(L);
    ClearCoatAreaContext context;
    context.NoV = dot(N, V);
    context.NoL = dot(N, L);
    context.VoL = dot(V, L);
    hvec3 H = normalize(V + L);
    context.NoH = saturate(dot(N, H));
    context.VoH = saturate(dot(V, H));
    return context;
}

/// UE BRDF.ush::SphereMaxNoH; only the bottom layer uses its Newton refinement with dual normals.
void ClearCoatSphereMaxNoH(inout ClearCoatAreaContext context, hfloat sinAlpha, bool newtonIteration)
{
    if (sinAlpha <= 0.0)
        return;
    hfloat cosAlpha = sqrt(1.0 - sinAlpha * sinAlpha);
    hfloat RoL = 2.0 * context.NoL * context.NoV - context.VoL;
    if (RoL >= cosAlpha)
    {
        context.NoH = 1.0;
        context.VoH = abs(context.NoV);
        return;
    }
    hfloat invLengthT = sinAlpha * inversesqrt(max(1.0 - RoL * RoL, 1e-8));
    hfloat NoTr = invLengthT * (context.NoV - RoL * context.NoL);
    hfloat VoTr = invLengthT * (2.0 * context.NoV * context.NoV - 1.0 - RoL * context.VoL);
    if (newtonIteration)
    {
        hfloat NxLoV = sqrt(saturate(1.0 - context.NoL * context.NoL - context.NoV * context.NoV
            - context.VoL * context.VoL + 2.0 * context.NoL * context.NoV * context.VoL));
        hfloat NoBr = invLengthT * NxLoV;
        hfloat VoBr = NoBr * 2.0 * context.NoV;
        hfloat NoLVTr = context.NoL * cosAlpha + context.NoV + NoTr;
        hfloat VoLVTr = context.VoL * cosAlpha + 1.0 + VoTr;
        hfloat p = NoBr * VoLVTr;
        hfloat q = NoLVTr * VoLVTr;
        hfloat s = VoBr * NoLVTr;
        hfloat xNum = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
        hfloat xDenom = p * p + s * (s - 2.0 * p) + NoLVTr * ((context.NoL * cosAlpha + context.NoV)
            * VoLVTr * VoLVTr + q * (-0.5 * (VoLVTr + context.VoL * cosAlpha) - 0.5));
        hfloat twoX = 2.0 * xNum / max(xDenom * xDenom + xNum * xNum, 1e-20);
        hfloat sinTheta = twoX * xDenom;
        hfloat cosTheta = 1.0 - twoX * xNum;
        NoTr = cosTheta * NoTr + sinTheta * NoBr;
        VoTr = cosTheta * VoTr + sinTheta * VoBr;
    }
    context.NoL = context.NoL * cosAlpha + NoTr;
    context.VoL = context.VoL * cosAlpha + VoTr;
    hfloat invLenH = inversesqrt(max(2.0 + 2.0 * context.VoL, 1e-8));
    context.NoH = saturate((context.NoL + context.NoV) * invLenH);
    context.VoH = saturate((1.0 + context.VoL) * invLenH);
}

/// Evaluate UE's two area-light lobes with shared integrated NoL and independent sphere contexts.
/// UE 5.5.4 CapsuleLightIntegrate.ush derives the shared NoL from the bottom normal.
/// sinAlpha is the unmodified radius/distance; alpha is the substrate's r^2. Outputs include NoL.
void ApplyClearCoatArea(out vec3 diff, out vec3 spec, out vec3 layerWeight,
    vec3 coatNormal, vec3 bottomNormal, vec3 viewDirection, vec3 lightDirection, hfloat integratedNoL,
    vec3 diffuseColor, vec3 specularColor, vec3 baseColor, hfloat metallic, hfloat alpha,
    hfloat strength, hfloat coatRoughness, hfloat sinAlpha, hfloat softSinAlpha, hfloat lineCos)
{
    hfloat coatAlpha = Square(max(coatRoughness, 0.02));
    hfloat coatSinAlpha = saturate(sinAlpha * (1.0 - coatAlpha));
    hfloat bottomSinAlpha = saturate(sinAlpha * (1.0 - alpha));
    ClearCoatAreaContext top = GetClearCoatAreaContext(coatNormal, viewDirection, lightDirection);
    ClearCoatSphereMaxNoH(top, coatSinAlpha, false);
    top.NoV = saturate(abs(top.NoV) + 1e-5);
    hfloat F = 0.04 + 0.96 * Pow5(1.0 - top.VoH);
    hfloat topA2 = coatAlpha * coatAlpha;
    hfloat topEnergy = AreaLightEnergyNormalization(topA2, top.VoH, coatSinAlpha, softSinAlpha, lineCos);
    hfloat topD = ClearCoatGGXDistribution(top.NoH, sqrt(topA2));
    hfloat topVis = SmithJointGGXVisibilityTerm(integratedNoL, top.NoV, sqrt(topA2));

    ClearCoatAreaContext bottom = GetClearCoatAreaContext(bottomNormal, viewDirection, lightDirection);
    // ClearCoatBxDF saturates the bottom-normal dots before SphereMaxNoH.
    bottom.NoV = saturate(bottom.NoV);
    bottom.NoL = saturate(bottom.NoL);
    bottom.VoL = saturate(bottom.VoL);
    ClearCoatSphereMaxNoH(bottom, bottomSinAlpha, true);
    bottom.NoV = saturate(abs(bottom.NoV) + 1e-5);
    vec3 refracted = RefractClearCoatCosines(bottom.NoV, bottom.NoL, bottom.NoH, bottom.VoH);
    vec3 transmission = ComputeClearCoatTransmittance(refracted.y, refracted.x, metallic, baseColor);
    vec3 throughCoat = (1.0 - F) * (1.0 - F) * transmission;
    layerWeight = mix(vec3_splat(1.0), throughCoat, strength);
    diff = diffuseColor * M_INV_PI * integratedNoL * layerWeight;

    // UE 5.5.4 ShadingModels.ush::ClearCoatBxDF evaluates bottom D/Vis before EnergyNormalization.
    // Unlike the top layer, its bottom D/Vis retain the material roughness (lines 587-635).
    hfloat bottomD = ClearCoatGGXDistribution(bottom.NoH, alpha);
    hfloat bottomVis = SmithJointGGXVisibilityTerm(integratedNoL, refracted.x, alpha);
    hfloat bottomA2 = alpha * alpha;
    hfloat bottomEnergy = AreaLightEnergyNormalization(bottomA2, bottom.VoH, bottomSinAlpha, softSinAlpha, lineCos);
    // UE F_Schlick treats very small F0 as shadowing, including at grazing angles.
    vec3 substrateF90 = vec3_splat(saturate(50.0 * specularColor.g));
    vec3 defaultF = mix(specularColor, substrateF90, Pow5(1.0 - bottom.VoH));
    vec3 refractedF = mix(specularColor, substrateF90, Pow5(1.0 - refracted.z));
    spec = integratedNoL * (hvec3_splat(strength * topD * topVis * topEnergy * F)
        + bottomD * bottomVis * bottomEnergy * mix(defaultF, throughCoat * refractedF, strength));
}
#endif // CLEAR_COAT_AREA_HELPERS

#if NONPUNCTUAL_LIGHTING && defined(CLUSTER)
/// Evaluate a line source with spherical extent; the optional coat normal is independent of the substrate.
vec3 GetCapsuleLighting(NonPunctualPointLight light, vec3 worldPos, vec3 normal, vec3 viewDirection, vec3 diffuseColor, vec3 specularColor, float roughness, float perceptualRoughness
#ifdef USES_BACKLIGHT
    , vec3 backlightColor
#endif
#ifdef USES_RIM
    , vec3 rimTerm
#endif
#ifdef CLEAR_COAT
    , vec3 coatNormal, float clearCoatStrength, float clearCoatRoughness
    , vec3 baseColor, float metallic
#endif
)
{
    hfloat radius = light.sourceRadius;
    hfloat softRadius = light.softRadius;

    hvec3 L = light.position - worldPos;
    hvec3 L01 = light.direction * light.length;
    hvec3 L0 = L - 0.5 * L01;
    hvec3 L1 = L + 0.5 * L01;
    L01 = L1 - L0;

    hfloat Length0Sqr = dot(L0, L0);
    hfloat Length0 = sqrt(Length0Sqr);
    hfloat Length1Sqr = dot(L1, L1);
    hfloat Length1 = sqrt(Length1Sqr);
    hfloat Length01 = Length0 * Length1;

    hfloat NdotL = 0.5 * (dot(normal, L0) / Length0 + dot(normal, L1) / Length1);
    hfloat distSqr = dot(L, L);
    hfloat rangeMask = GetLightRangeMask(light.range, distSqr);

    hfloat NdotV = abs(dot(normal, viewDirection));
    hfloat cosSubtended = dot(L0, L1) / Length01;
    hfloat falloff = 1.0 / (Length01 * (0.5 * cosSubtended + 0.5 + 1.0 / (Length01 + 1e-4)));
    hfloat rawNdotL = NdotL;
    hfloat sinAlphaSqr = saturate(radius * radius * falloff);
    if(radius > 0.0)
    {
        NdotL = SphereHorizonCosWrap(NdotL, sinAlphaSqr);
    }
#if defined(DIFFUSE_BURLEY) || defined(DIFFUSE_LAMBERT_WRAP) || defined(USES_BACKLIGHT)
    hvec3 diffuseDirection = normalize(L0 / Length0 + L1 / Length1);
    hvec3 diffuseHalfDirection = normalize(diffuseDirection + viewDirection);
    hfloat diffuseResponseNL = GetMaterialAreaDiffuseResponseNL(rawNdotL, NdotL, sinAlphaSqr,
        NdotV, saturate(dot(diffuseDirection, diffuseHalfDirection)), perceptualRoughness);
#endif
    hvec3 diff = diffuseColor * M_INV_PI;
    //Specular
    hvec3 reflectDir = -viewDirection + 2.0 * dot(viewDirection, normal) * normal;
    L = ClosestPointLineToRay(L0, L1, light.length, reflectDir);
#ifndef CLEAR_COAT
    L = ClosestPointSphereToRay(L, radius, reflectDir);
#endif
    distSqr = dot(L, L);
    hfloat invDist = 1.0 / sqrt(distSqr + 1e-4);
    falloff *= rangeMask;
    L = normalize(L);
    hvec3 H = normalize(L + viewDirection);
    hfloat VdotH = dot(viewDirection, H);
    hfloat NdotH = clamp(dot(normal, H), M_EPSILON, 1.0);
    roughness = max(roughness, 0.002);
#ifdef CLEAR_COAT
    vec3 spec, substrateTransmission;
    vec3 areaDiff;
    ApplyClearCoatArea(areaDiff, spec, substrateTransmission, coatNormal, normal, viewDirection, L,
        saturate(NdotL), diffuseColor, specularColor, baseColor, metallic, roughness,
        clearCoatStrength, clearCoatRoughness, radius * invDist, saturate(softRadius * invDist), cosSubtended);
    diff = areaDiff;
#else
    // UE SpecularGGX evaluates D/Vis after soft-source broadening, unlike the clear-coat bottom layer.
    hfloat alpha = roughness;
    hfloat a2 = alpha * alpha;
    hfloat energy = AreaLightEnergyNormalization(a2, VdotH, radius * invDist * (1.0 - alpha),
        softRadius * invDist, cosSubtended);
    hfloat areaAlpha = sqrt(a2);
    hfloat V = SmithJointGGXVisibilityTerm(NdotL, NdotV, areaAlpha);
    hfloat D = GGXTerm(NdotH, areaAlpha);
    hvec3 F = FresnelTerm(specularColor, VdotH);
    hvec3 spec = V * D * F * energy;
#endif
#if defined(MATERIAL_SPECULAR_DISABLED) || defined(MATERIAL_SPECULAR_TOON)
    spec = hvec3_init(0.0, 0.0, 0.0);
#endif
#if !defined(DIFFUSE_BURLEY) && !defined(DIFFUSE_LAMBERT_WRAP) && !defined(USES_BACKLIGHT)
#ifdef CLEAR_COAT
    vec3 lighting = (diff + spec) * light.intensity * falloff;
#else
    vec3 lighting = (diff + spec) * light.intensity * falloff * NdotL;
#endif
#ifdef USES_RIM
    lighting += rimTerm * light.intensity * falloff;
#endif
    return lighting;
#else
#ifdef CLEAR_COAT
    // Custom diffuse modes retain the integrated source response and layer transmission.
#if defined(DIFFUSE_BURLEY) || defined(DIFFUSE_LAMBERT_WRAP)
    diff = diffuseColor * diffuseResponseNL * substrateTransmission;
#endif
#else
    diff = diffuseColor * diffuseResponseNL;
    spec *= NdotL;
#endif
#ifdef USES_BACKLIGHT
    vec3 backlightTerm = GetBacklightContribution(backlightColor, diffuseResponseNL);
#ifdef CLEAR_COAT
    backlightTerm *= substrateTransmission;
#endif
    diff += backlightTerm;
#endif
#ifdef USES_RIM
    // Area attenuation is independent of the receiving normal and specular lobe.
    diff += rimTerm;
#endif
    return (diff + spec) * light.intensity * falloff;
#endif
}

/// Evaluate a spherical source with separate coat and substrate normals.
vec3 GetSphereLighting(NonPunctualPointLight light, vec3 worldPos, vec3 normal, vec3 viewDirection, vec3 diffuseColor, vec3 specularColor, float roughness, float perceptualRoughness
#ifdef USES_BACKLIGHT
    , vec3 backlightColor
#endif
#ifdef USES_RIM
    , vec3 rimTerm
#endif
#ifdef CLEAR_COAT
    , vec3 coatNormal, float clearCoatStrength, float clearCoatRoughness
    , vec3 baseColor, float metallic
#endif
)
{
    hfloat radius = light.sourceRadius;
    hfloat softRadius = light.softRadius;

    hvec3 lightVec = light.position - worldPos.xyz;
    hfloat distSqr = dot(lightVec, lightVec);
    hfloat rangeMask = GetLightRangeMask(light.range, distSqr);
    hfloat falloff = rangeMask / max(distSqr, 0.0001);
    hfloat invDist = 1.0 / sqrt(distSqr + 1e-4);
    hfloat sinAlphaSqr = saturate(radius * radius / max(distSqr, 0.0001));

    hvec3 lightDirection = lightVec * invDist;
    hfloat rawNdotL = dot(normal, lightDirection);
    hfloat NdotL = SphereHorizonCosWrap(rawNdotL, sinAlphaSqr);
    hfloat NdotV = abs(dot(normal, viewDirection));
#if defined(DIFFUSE_BURLEY) || defined(DIFFUSE_LAMBERT_WRAP) || defined(USES_BACKLIGHT)
    hvec3 diffuseHalfDirection = normalize(lightDirection + viewDirection);
    hfloat diffuseResponseNL = GetMaterialAreaDiffuseResponseNL(rawNdotL, NdotL, sinAlphaSqr,
        NdotV, saturate(dot(lightDirection, diffuseHalfDirection)), perceptualRoughness);
#endif

    hvec3 diff = diffuseColor * M_INV_PI;

    //Specular
#ifdef CLEAR_COAT
    hvec3 L = normalize(lightVec);
#else
    hvec3 reflectDir = -viewDirection + 2.0 * dot(viewDirection, normal) * normal;
    hvec3 closestPointOnSphere = ClosestPointSphereToRay(lightVec, radius, reflectDir);

    hvec3 L = normalize(closestPointOnSphere);
#endif
    hvec3 H = normalize(L + viewDirection);
    hfloat VdotH = dot(viewDirection, H);
    hfloat NdotH = clamp(dot(normal, H), M_EPSILON, 1.0);
    roughness = max(roughness, 0.002);
#ifdef CLEAR_COAT
    vec3 spec, substrateTransmission;
    vec3 areaDiff;
    ApplyClearCoatArea(areaDiff, spec, substrateTransmission, coatNormal, normal, viewDirection, L,
        saturate(NdotL), diffuseColor, specularColor, baseColor, metallic, roughness,
        clearCoatStrength, clearCoatRoughness, radius * invDist, saturate(softRadius * invDist), 1.0);
    diff = areaDiff;
#else
    // Keep the original source angle, but feed the broadened alpha to the existing D/Vis helpers.
    hfloat alpha = roughness;
    hfloat a2 = alpha * alpha;
    hfloat energy = AreaLightEnergyNormalization(a2, VdotH, radius * invDist * (1.0 - alpha),
        softRadius * invDist, 1.0);
    hfloat areaAlpha = sqrt(a2);
    hfloat V = SmithJointGGXVisibilityTerm(NdotL, NdotV, areaAlpha);
    hfloat D = GGXTerm(NdotH, areaAlpha);
    hvec3 F = FresnelTerm(specularColor, VdotH);
    hvec3 spec = V * D * F * energy;
#endif
#if defined(MATERIAL_SPECULAR_DISABLED) || defined(MATERIAL_SPECULAR_TOON)
    spec = hvec3_init(0.0, 0.0, 0.0);
#endif
#if !defined(DIFFUSE_BURLEY) && !defined(DIFFUSE_LAMBERT_WRAP) && !defined(USES_BACKLIGHT)
#ifdef CLEAR_COAT
    vec3 lighting = (diff + spec) * light.intensity * falloff;
#else
    vec3 lighting = (diff + spec) * light.intensity * falloff * NdotL;
#endif
#ifdef USES_RIM
    lighting += rimTerm * light.intensity * falloff;
#endif
    return lighting;
#else
#ifdef CLEAR_COAT
    // Custom diffuse modes retain the integrated source response and layer transmission.
#if defined(DIFFUSE_BURLEY) || defined(DIFFUSE_LAMBERT_WRAP)
    diff = diffuseColor * diffuseResponseNL * substrateTransmission;
#endif
#else
    diff = diffuseColor * diffuseResponseNL;
    spec *= NdotL;
#endif
#ifdef USES_BACKLIGHT
    vec3 backlightTerm = GetBacklightContribution(backlightColor, diffuseResponseNL);
#ifdef CLEAR_COAT
    backlightTerm *= substrateTransmission;
#endif
    diff += backlightTerm;
#endif
#ifdef USES_RIM
    // Area attenuation is independent of the receiving normal and specular lobe.
    diff += rimTerm;
#endif
    return (diff + spec) * light.intensity * falloff;
#endif
}
#endif
