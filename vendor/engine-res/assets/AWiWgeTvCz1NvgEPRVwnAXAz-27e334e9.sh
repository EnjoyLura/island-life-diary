#ifndef MATERIAL_DIFFUSE_RESPONSE_SH
#define MATERIAL_DIFFUSE_RESPONSE_SH

// Keep constants and the legacy multiply order in the caller's expression.
// Inputs are side-effect-free BRDF locals; macros must not receive increments/calls with side effects.
#if defined(DIFFUSE_LAMBERT_WRAP)
float GetWrappedMaterialDiffuseBRDF(float rawNdotL, float NdotL, float perceptualRoughness)
{
    float wrap = clamp(perceptualRoughness, 0.0, 1.0);
    return max(0.0, rawNdotL + wrap) * M_INV_PI / ((1.0 + wrap) * (1.0 + wrap) * NdotL);
}
#define GetMaterialDiffuseBRDF(rawNL, NL, NV, LH, r) GetWrappedMaterialDiffuseBRDF(rawNL, NL, r)
#define GetMaterialDirectDiffuse(color, rawNL, NL, NV, LH, r) ((color) * GetMaterialDiffuseBRDF(rawNL, NL, NV, LH, r))
#elif defined(DIFFUSE_BURLEY) || !USE_DIFFUSE_LAMBERT_BRDF
#define GetMaterialDiffuseBRDF(rawNL, NL, NV, LH, r) (DisneyDiffuse(NV, NL, LH, r) * M_INV_PI)
#define GetMaterialDirectDiffuse(color, rawNL, NL, NV, LH, r) (DisneyDiffuse(NV, NL, LH, r) * (color) * M_INV_PI)
#else
#define GetMaterialDiffuseBRDF(rawNL, NL, NV, LH, r) M_INV_PI
#define GetMaterialDirectDiffuse(color, rawNL, NL, NV, LH, r) ((color) * M_INV_PI)
#endif

float SphereHorizonCosWrap( float NoL, float sinAlphaSqr )
{
    if (sinAlphaSqr <= 0.0)
        return max(NoL, 0.0);
	float sinAlpha = sqrt( sinAlphaSqr );

	if( NoL < sinAlpha )
	{
		NoL = max(NoL, -sinAlpha);
		NoL = Square(sinAlpha + NoL) / (4.0 * sinAlpha);
	}

	return NoL;
}

#if defined(DIFFUSE_BURLEY) || defined(DIFFUSE_LAMBERT_WRAP) || defined(USES_BACKLIGHT) || defined(DEFERRED_BACKLIGHT)
// Uncolored area diffuse response, including its receiving cosine. Explicit
// selectors use the emitter's native horizon approximation; old area materials
// keep Lambert even when punctual lights use Disney diffuse by default.
hfloat GetMaterialAreaDiffuseResponseNL(hfloat rawNdotL, hfloat areaNdotL, hfloat sinAlphaSqr,
    hfloat NdotV, hfloat LdotH, hfloat perceptualRoughness)
{
#if defined(DIFFUSE_LAMBERT_WRAP)
    hfloat wrap = clamp(perceptualRoughness, 0.0, 1.0);
    hfloat wrappedNoL = SphereHorizonCosWrap(rawNdotL + wrap, sinAlphaSqr);
    return max(0.0, wrappedNoL) * M_INV_PI / ((1.0 + wrap) * (1.0 + wrap));
#elif defined(DIFFUSE_BURLEY)
    return DisneyDiffuse(NdotV, max(areaNdotL, M_EPSILON), LdotH, perceptualRoughness)
        * M_INV_PI * areaNdotL;
#else
    return M_INV_PI * areaNdotL;
#endif
}
#endif

#if defined(USES_BACKLIGHT) || defined(DEFERRED_BACKLIGHT)
// backlightColor already includes workflow base-color / diffuse-material weighting.
vec3 GetBacklightContribution(vec3 backlightColor, float diffuseResponseNL)
{
    return backlightColor * (M_INV_PI - diffuseResponseNL);
}
#endif
#endif
