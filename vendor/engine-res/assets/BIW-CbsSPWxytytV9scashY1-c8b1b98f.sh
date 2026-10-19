#include "Toon/ToonUniforms.sh"
#include "SurfaceOutline.sh"

// 2-bit Area Type，高位=皮肤族：11=Face 10=Skin 01=Hair 00=Default。
// 该编码让皮肤/脸判定退化为单条 step，无逻辑运算。
#define TOON_AREA_DEFAULT 0.0
#define TOON_AREA_HAIR 1.0
#define TOON_AREA_SKIN 2.0
#define TOON_AREA_FACE 3.0
#define TOON_FACE_SHADOW_LIFT 0.5
#define TOON_LOW_SATURATION_SCALE 5.0
#define TOON_NDOTV_RIM_MIDPOINT 0.6
#define TOON_NDOTV_RIM_TRANSITION 0.02
#define TOON_NDOTV_RIM_LIGHT_TRANSITION_HALF_PIXELS 2.0
#define TOON_NDOTV_RIM_GUARD_PIXELS 4.0
#define TOON_NDOTV_RIM_GUARD_MAX_OUTPUT 1.0
#define TOON_DEPTH_RIM_BASE_THRESHOLD 0.05
#define TOON_DEPTH_RIM_FADEOUT_SCALE 10.0
#define TOON_DEPTH_SHADOW_BASE_THRESHOLD 0.03
#define TOON_DEPTH_SHADOW_FADEOUT_SCALE 50.0
#define TOON_DEPTH_ORTHO_DISTANCE_FIX 0.7
#define TOON_DEPTH_ORTHO_SIZE_SCALE 100.0

#include "Toon/ToonSpecular.sh"

float ToonSkinAreaMask(float areaType)
{
    return step(1.5, areaType); // 2/3 -> 1
}

float ToonFaceAreaMask(float areaType)
{
    return step(2.5, areaType); // 3 -> 1
}

vec3 ToonRgbToHsv(vec3 color)
{
    vec4 k = vec4(0.0, -0.3333333333, 0.6666666667, -1.0);
    vec4 p = mix(vec4(color.bg, k.wz), vec4(color.gb, k.xy), step(color.b, color.g));
    vec4 q = mix(vec4(p.xyw, color.r), vec4(color.r, p.yzx), step(p.x, color.r));
    float delta = q.x - min(q.w, q.y);
    float epsilon = M_EPSILON;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * delta + epsilon)), delta / (q.x + epsilon), q.x);
}

vec3 ToonHsvToRgb(vec3 color)
{
    vec3 p = abs(fract(color.xxx + vec3(0.0, 0.6666666667, 0.3333333333)) * 6.0 - 3.0);
    return color.z * mix(vec3_splat(1.0), saturate(p - 1.0), color.y);
}

float GetToonBand(ToonSurfaceParams toonParams, vec3 normalDirection, vec3 lightDirection, float areaType,
    float softness)
{
    float faceMask = ToonFaceAreaMask(areaType);
    vec3 lightingNormal = mix(normalDirection, -GetCameraForwardDir(), faceMask);
    float midpoint = mix(toonParams.midpoint, -0.3, faceMask);
    softness = mix(clamp(softness, 0.001, 1.0), 1.0, faceMask);
    return smoothstep(midpoint - softness, midpoint + softness,
        dot(lightingNormal, lightDirection));
}

float ResolveToonLightingRamp(ToonSurfaceParams toonParams, vec3 normalDirection, vec3 lightDirection,
    float areaType, float toonLightingInput)
{
#ifdef TOON_LEGACY_SOFTNESS
    return GetToonBand(toonParams, normalDirection, lightDirection, areaType, toonLightingInput);
#else
    return saturate(toonLightingInput);
#endif
}

vec3 GetToonGenericShadowColor(ToonSurfaceParams toonParams, vec3 baseColor)
{
    float saturationBoost = saturate(toonParams.shadowHSV.y);
    float valueMultiplier = max(toonParams.shadowHSV.z, 0.0);

    // Zero Hue Offset is the common path. Fold HSV saturation adjustment and
    // low-saturation fallback into RGB space to avoid both color conversions.
    BRANCH if (toonParams.shadowHSV.x == 0.0)
    {
        float maxColor = max(max(baseColor.r, baseColor.g), baseColor.b);
        float minColor = min(min(baseColor.r, baseColor.g), baseColor.b);
        float chroma = maxColor - minColor;
        float denominator = max(max(chroma, maxColor / TOON_LOW_SATURATION_SCALE), M_EPSILON);
        float saturationScale = 1.0 + saturationBoost * minColor / denominator;
        return (maxColor + (baseColor - maxColor) * saturationScale) * valueMultiplier;
    }

    vec3 hsv = ToonRgbToHsv(baseColor);
    float originalSaturation = hsv.y;
    hsv.x += toonParams.shadowHSV.x;
    hsv.y = mix(hsv.y, 1.0, saturationBoost);
    hsv.z *= valueMultiplier;

    vec3 hsvShadow = ToonHsvToRgb(hsv);
    vec3 neutralShadow = baseColor * valueMultiplier;
    return mix(neutralShadow, hsvShadow,
        saturate(originalSaturation * TOON_LOW_SATURATION_SCALE));
}

vec3 GetToonSkinShadowColor(ToonSurfaceParams toonParams, vec3 baseColor, float areaType)
{
    vec3 skinShadow = baseColor * max(toonParams.skinShadowTint.rgb, vec3_splat(0.0));
    skinShadow += TOON_FACE_SHADOW_LIFT * max(skinShadow * (1.0 - skinShadow), vec3_splat(0.0))
        * ToonFaceAreaMask(areaType);
    return skinShadow;
}

vec3 GetToonShadowColor(ToonSurfaceParams toonParams, vec3 baseColor, float areaType)
{
    float skinInfluence = ToonSkinAreaMask(areaType) * saturate(toonParams.skinShadowTint.a);
    BRANCH if (skinInfluence <= 0.0)
        return GetToonGenericShadowColor(toonParams, baseColor);

    vec3 skinShadow = GetToonSkinShadowColor(toonParams, baseColor, areaType);
    BRANCH if (skinInfluence >= 1.0)
        return skinShadow;

    return mix(GetToonGenericShadowColor(toonParams, baseColor), skinShadow, skinInfluence);
}

float GetToonShadowAttenuation(vec3 shadow)
{
    return saturate(dot(shadow, vec3(0.2126, 0.7152, 0.0722)));
}

float GetToonNdotVRimMask(vec3 normalDirection, vec3 viewDirection,
    vec3 lightDirection, float areaType, float rimIntensity)
{
#ifdef SURFACE_TOON_OUTLINE
    return 0.0;
#elif !defined(USES_RIM)
    // Without fragment RIM/RIM_TINT outputs, the inherited intensity is draw-uniform.
    BRANCH if (rimIntensity <= 0.0)
        return 0.0;
#endif

    // Generate the view-angle Rim shape, then modulate it by the light-facing side and face mask.
    float rawRim = 1.0 - saturate(dot(normalDirection, viewDirection));
    float rimAttenuation = rawRim;
    float NoL = dot(normalDirection, lightDirection);
    rimAttenuation *= saturate(NoL) * 0.25 + 0.75;
    rimAttenuation *= 1.0 - ToonFaceAreaMask(areaType);

    // Threshold the shape and anti-alias its inner edge.
    float aaWidth = max(TOON_NDOTV_RIM_TRANSITION, fwidth(rawRim));
    float rimMask = smoothstep(
        TOON_NDOTV_RIM_MIDPOINT - aaWidth,
        TOON_NDOTV_RIM_MIDPOINT + aaWidth,
        rimAttenuation);

    // Anti-alias the light/dark cutoff after thresholding to preserve the requested pixel width.
    float lightTransitionHalfWidth = max(
        fwidth(NoL) * TOON_NDOTV_RIM_LIGHT_TRANSITION_HALF_PIXELS, M_EPSILON);
    float lightSideMask = smoothstep(-lightTransitionHalfWidth, lightTransitionHalfWidth, NoL);
    return rimMask * lightSideMask;
}

#if defined(DEFERRED)
vec2 GetToonDepthMasks(vec2 screenUV, float currentLinearDepth, vec3 normalDirection,
    vec3 viewDirection, vec3 lightDirection, float areaType, float rimIntensity)
{
#if RENDER_QUALITY >= RENDER_QUALITY_HIGH
    BRANCH if (cToonDepthEffectsSimpleOffset != 0.0)
    {
        vec3 lightDirectionVS = mul(hvec4_init(lightDirection, 0.0), cView).xyz;
        float faceMask = ToonFaceAreaMask(areaType);
        float faceDepthEffectsSimpleOffsetMultiplier = mix(
            1.0, cToonFaceDepthEffectsSimpleOffsetMultiplier, faceMask);
        // Match the reference depth-texture offset: closer objects get a larger
        // screen-space sample, then divide by FOV / ortho size.
        float cameraDistanceFix = cProj[3][3] == 0.0
            ? 1.0 / (1.0 + max(currentLinearDepth, 0.0))
            : TOON_DEPTH_ORTHO_DISTANCE_FIX;
        float verticalFocal = max(abs(cProj[1][1]), 1e-6);
        float fovOrOrthoSizeFix = cProj[3][3] == 0.0
            ? 1.0 / (2.0 * atan(1.0 / verticalFocal) * (180.0 / 3.14159265))
            : verticalFocal / TOON_DEPTH_ORTHO_SIZE_SCALE;
        float widthMultiplier = cToonDepthEffectsSimpleOffset * faceDepthEffectsSimpleOffsetMultiplier
            * cameraDistanceFix * fovOrOrthoSizeFix;
        // Reference applies (height/width, 1) * width / FOV directly in UV space.
        vec2 screenLightDirection = GetScreenUVDirection(lightDirectionVS.xy);
        vec2 offsetUV = screenUV + screenLightDirection * vec2(
            cGBufferInvSize.x / max(cGBufferInvSize.y, 1e-6), 1.0) * widthMultiplier;
        offsetUV = clamp(offsetUV, vec2_splat(0.0), vec2_splat(1.0));
        float sampledRawDepth = texture2D(u_GBuffer4, offsetUV).r;
        float sampledLinearDepth = ReconstructDepth(sampledRawDepth) * cFarClipPS;
        float depthDifference = sampledLinearDepth - currentLinearDepth;

        float rimMask = 0.0;
        BRANCH if (rimIntensity > 0.0)
        {
            // Threshold is a signed offset on a fixed base, not an absolute meter value.
            float rimThreshold = saturate(TOON_DEPTH_RIM_BASE_THRESHOLD + cToonDepthRimThreshold);
            float rimFade = max(cToonDepthRimFadeRange, 0.01);
            rimMask = saturate((depthDifference - rimThreshold)
                * TOON_DEPTH_RIM_FADEOUT_SCALE / rimFade);
        }

        // Depth Shadow remains independent from the runtime Rim switch.
        float shadowThreshold =
            TOON_DEPTH_SHADOW_BASE_THRESHOLD
            + cToonDepthShadowThreshold;
        float shadowFade = max(cToonDepthShadowFadeRange, 0.01);
        float shadowVisibility = saturate((depthDifference + shadowThreshold)
            * TOON_DEPTH_SHADOW_FADEOUT_SCALE / shadowFade);
        float shadowMask = (1.0 - shadowVisibility) * saturate(cToonDepthShadowInfluence);
        return vec2(rimMask, shadowMask);
    }
#endif

    // Deferred keeps only the final shading normal in GBuffer, so its NdotV fallback cannot recover
    // the interpolated geometric normal. The preferred high-quality Depth Rim path above is unaffected.
    return vec2(GetToonNdotVRimMask(normalDirection, viewDirection,
        lightDirection, areaType, rimIntensity), 0.0);
}
#endif

vec3 GetToonRampDiffuse(ToonSurfaceParams toonParams, vec3 baseColor, vec3 normalDirection, vec3 rimNormalDirection,
    vec3 viewDirection, vec3 lightDirection, float areaType, float toonRamp, float shadowAttenuation,
    vec2 screenUV, float currentLinearDepth, bool enableDepthEffects, out float outRimMask)
{
    float rampVisibility = saturate(toonRamp) * saturate(shadowAttenuation);
#if !defined(DEFERRED)
    // Forward consumes the standard NdotV Rim directly; it does not depend on depth effects.
    outRimMask = GetToonNdotVRimMask(rimNormalDirection, viewDirection,
        lightDirection, areaType, toonParams.rimColor.a);
    float depthShadowMask = 0.0;
#else
    vec2 depthMasks = enableDepthEffects
        ? GetToonDepthMasks(screenUV, currentLinearDepth, rimNormalDirection, viewDirection,
            lightDirection, areaType, toonParams.rimColor.a)
        : vec2(0.0, 0.0);
    outRimMask = depthMasks.x;
    float depthShadowMask = depthMasks.y;
#endif
    float depthVisibility = 1.0 - depthShadowMask;
    float litVisibility = saturate(rampVisibility * depthVisibility);
    BRANCH if (litVisibility >= 1.0)
        return baseColor;
    return mix(GetToonShadowColor(toonParams, baseColor, areaType), baseColor, litVisibility);
}

// Rim 是 max(direct, indirect) 之后的独立加法项。
// 阴影内降至 25% 而非清零；Ramp 消费光颜色 min(2) 防过曝并叠加 5% 保底。
vec3 GetToonRimLighting(ToonSurfaceParams toonParams, float rimMask, float shadowAttenuation, vec3 rampLightColor)
{
    BRANCH if (toonParams.rimColor.a <= 0.0)
        return vec3_splat(0.0);

    float shadowMul = mix(0.25, 1.0, saturate(shadowAttenuation));
    vec3 rimColor = vec3_splat(0.05)
        + min(max(rampLightColor, vec3_splat(0.0)), vec3_splat(2.0)) * toonParams.rimColor.rgb / 6.0;
    return rimMask * shadowMul * rimColor * max(toonParams.rimColor.a, 0.0);
}

vec3 GetToonAdditionalDiffuse(vec3 baseColor, vec3 normalDirection,
    vec3 lightDirection, float attenuation, float shadowAttenuation, vec3 lightColor, float areaType)
{
    vec3 additionalLightNormal = mix(normalDirection, -GetCameraForwardDir(),
        ToonFaceAreaMask(areaType));
    float angular = 0.8 + 0.2 * dot(additionalLightNormal, lightDirection);
    float boundedAttenuation = min(1.0, max(attenuation, 0.0));
    return baseColor * lightColor * angular * boundedAttenuation * shadowAttenuation * 0.5;
}

#ifdef USES_BACKLIGHT
vec3 GetToonAdditionalBacklight(vec3 backlightColor, vec3 normalDirection, vec3 lightDirection,
    float attenuation, float shadowAttenuation, vec3 lightColor, float areaType)
{
    vec3 normal = mix(normalDirection, -GetCameraForwardDir(), ToonFaceAreaMask(areaType));
    float responseNL = (0.8 + 0.2 * dot(normal, lightDirection)) * M_INV_PI;
    return GetBacklightContribution(backlightColor, responseNL) * lightColor
        * min(1.0, max(attenuation, 0.0)) * shadowAttenuation * 0.5;
}
#endif

struct ToonDirectDiffuseLighting
{
    vec3 lighting;
#ifdef MATERIAL_PBR_SPECULAR
    vec3 specularLighting;
#endif
    float rimMask;
    vec3 rampLightColor;
    vec3 rampLightDirection;
    float rampShadowAttenuation;
    vec3 rampLightFactor;
};

ToonDirectDiffuseLighting EvaluateToonDirectDiffuseLighting(ToonSurfaceParams toonParams, vec3 baseColor, hvec3 worldPos,
    vec3 normalDirection, vec3 rimNormalDirection, vec3 viewDirection, vec3 shadow, float areaType, float toonLightingInput,
    vec2 screenUV, float currentLinearDepth, bool enableDepthEffects
#ifdef USES_DIRECT_AO
    , float directOcclusion
#endif
#ifdef USES_BACKLIGHT
    , vec3 backlightColor
#endif
#ifdef DEFERRED_CLUSTER
    , hfloat sceneDepth
#endif
#ifdef MATERIAL_PBR_SPECULAR
    , vec3 specularColor, float roughness, float perceptualRoughness
#endif
)
{
#ifndef USES_DIRECT_AO
    float directOcclusion = 1.0;
#endif
    ToonDirectDiffuseLighting result;
    result.lighting = vec3_splat(0.0);
#ifdef MATERIAL_PBR_SPECULAR
    result.specularLighting = vec3_splat(0.0);
#endif
    result.rimMask = 0.0;
    result.rampLightColor = vec3_splat(0.0);
    result.rampLightDirection = vec3_splat(0.0);
    result.rampShadowAttenuation = 1.0;
    result.rampLightFactor = vec3_splat(0.0);

#if defined(PERPIXEL)
    hvec3 lightColor;
    vec3 lightDirection;
    hfloat attenuation;

#if (defined(DIRLIGHT) && !defined(CLUSTER_BASE)) || !defined(CLUSTER)
    lightColor = GI_GetLightColor(worldPos);
    attenuation = GI_GetAttenAndLightDir(worldPos, lightDirection);
    float shadowAttenuation = GetToonShadowAttenuation(shadow);
    #ifdef MATERIAL_PBR_SPECULAR
        #ifdef RECTLIGHT
            #ifdef USES_RIM
                hfloat unusedRectRimAttenuation;
            #endif
            vec3 selectedSpecular = GetRectLightBRDF(worldPos, normalDirection, viewDirection,
                vec3_splat(0.0), specularColor, roughness, perceptualRoughness,
                cLightPosPS.xyz, -cLightDirPS, cLightTangent,
                cLightRectParams.x, cLightRectParams.y, cLightRectParams.z, cLightRectParams.w
            #ifdef USES_BACKLIGHT
                , vec3_splat(0.0)
            #endif
            #ifdef USES_RIM
                , unusedRectRimAttenuation
            #endif
            );
        #else
            vec3 selectedSpecular = GetSpecularColor(specularColor, roughness, perceptualRoughness,
                normalDirection, viewDirection, lightDirection, abs(dot(normalDirection, viewDirection)));
        #endif
        result.specularLighting += directOcclusion * selectedSpecular * lightColor * attenuation * shadow;
    #endif

    #ifdef TOON_FULL_SHADE
        result.rampLightColor = vec3(lightColor);
        result.rampLightDirection = lightDirection;
        result.rampShadowAttenuation = shadowAttenuation;
        result.rampLightFactor = GetToonMainLightFactor(lightColor, attenuation);
        float toonRamp = ResolveToonLightingRamp(toonParams, normalDirection,
            lightDirection, areaType, toonLightingInput);
        float rimMask;
        vec3 directDiffuse = GetToonRampDiffuse(toonParams, baseColor, normalDirection, rimNormalDirection, viewDirection,
            lightDirection, areaType, toonRamp, shadowAttenuation, screenUV, currentLinearDepth,
            enableDepthEffects, rimMask);
        result.lighting += directOcclusion * (directDiffuse * result.rampLightFactor);
        result.rimMask = rimMask;
        #ifdef USES_BACKLIGHT
            float responseNL = saturate(toonRamp) * M_INV_PI;
            result.lighting += directOcclusion * GetBacklightContribution(backlightColor, responseNL)
                * result.rampLightFactor * shadowAttenuation;
        #endif
    #else
        result.lighting += directOcclusion * (GetToonAdditionalDiffuse(baseColor, normalDirection,
            lightDirection, attenuation, shadowAttenuation, max(lightColor, vec3_splat(0.0)), areaType));
        #ifdef USES_BACKLIGHT
            result.lighting += directOcclusion * GetToonAdditionalBacklight(backlightColor, normalDirection,
                lightDirection, attenuation, shadowAttenuation, max(lightColor, vec3_splat(0.0)), areaType);
        #endif
    #endif
#endif

#if defined(LIGHTMAP) && !defined(MATERIAL_AMBIENT_DISABLED)
    #if RENDER_QUALITY >= RENDER_QUALITY_HIGH && defined(LIGHTMAP_DIRECTIONALITY)
        vec3 lightMapDirection;
        vec4 lightMapColor = GetLightMapColor(vLightMapUV.xy, normalDirection, lightMapDirection);
    #else
        vec4 lightMapColor = GetLightMapColor(vLightMapUV.xy, normalDirection);
    #endif
    result.lighting += baseColor * lightMapColor.rgb;
#endif

#if defined(CLUSTER)
    #ifdef CLUSTER_VS
        if (vMrp.w > 0.0)
        {
            vec3 irradiance = vec3(dot(normalDirection, vVecIrrR.rgb), dot(normalDirection, vVecIrrG.rgb),
                dot(normalDirection, vec3(vVecIrrR.w, vVecIrrG.w, vMrpDir.w)));
            result.lighting += directOcclusion * (max(irradiance, vec3_splat(0.0)) * baseColor * 0.5);
        }
    #else
        #ifdef DEFERRED_CLUSTER
            uint cluster = getDeferredClusterIndex(gl_FragCoord.xy, sceneDepth);
        #else
            uint cluster = getMaterialClusterIndex(worldPos);
        #endif
        #ifdef CLUSTER_LOCAL_SHADOWS
            hvec3 localShadowNormal = GetClusterShadowNormal(worldPos, normalDirection);
        #endif
        LightGrid grid = getLightGrid(cluster);
        LOOP
        for (uint i = 0u; i < grid.pointLights; ++i)
        {
            uint lightIndex = GetGridLightIndex(grid.offset, i);
            #ifdef CLUSTER_SPOTLIGHT
                SpotLight light = GetSpotLight(lightIndex);
            #else
                PointLight light = GetPointLight(lightIndex);
            #endif
            lightColor = light.intensity;
            attenuation = GI_PointLight_GetAttenAndLightDir(
                worldPos, light.position, light.range, lightDirection);
            #ifdef CLUSTER_SPOTLIGHT
                attenuation *= GetLightDirectionFalloff(
                    lightDirection, light.direction, light.cosOuterCone, light.invCosConeDiff);
            #endif
            #ifdef CLUSTER_LOCAL_SHADOWS
                if (attenuation > 0.0)
                    attenuation *= SampleClusterLocalShadow(light.shadowIndex, worldPos, localShadowNormal);
            #endif
            result.lighting += directOcclusion * (GetToonAdditionalDiffuse(baseColor, normalDirection,
                lightDirection, attenuation, 1.0, max(lightColor, vec3_splat(0.0)), areaType));
            #ifdef MATERIAL_PBR_SPECULAR
                result.specularLighting += directOcclusion * GetSpecularColor(specularColor, roughness, perceptualRoughness,
                    normalDirection, viewDirection, lightDirection, abs(dot(normalDirection, viewDirection))) * lightColor * attenuation;
            #endif
            #ifdef USES_BACKLIGHT
                result.lighting += directOcclusion * GetToonAdditionalBacklight(backlightColor, normalDirection,
                    lightDirection, attenuation, 1.0, max(lightColor, vec3_splat(0.0)), areaType);
            #endif
        }
    #endif
#endif
#endif

    return result;
}

void EvaluateToonDirectLighting(ToonSurfaceParams toonParams, vec3 baseColor, vec3 specularColor, float roughness,
    float perceptualRoughness, hvec3 worldPos, vec3 normalDirection, vec3 rimNormalDirection, vec3 viewDirection,
    vec3 shadow, float areaType, float toonLightingInput, vec2 screenUV, float currentLinearDepth, bool enableDepthEffects
#ifdef USES_DIRECT_AO
    , float directOcclusion
#endif
#ifdef USES_BACKLIGHT
    , vec3 backlightColor
#endif
#ifdef DEFERRED_CLUSTER
    , hfloat sceneDepth
#endif
    , out vec3 directLighting, out vec3 rimLighting)
{
#ifndef USES_DIRECT_AO
    float directOcclusion = 1.0;
#endif
    ToonDirectDiffuseLighting result = EvaluateToonDirectDiffuseLighting(toonParams, baseColor, worldPos,
        normalDirection, rimNormalDirection, viewDirection, shadow, areaType, toonLightingInput, screenUV, currentLinearDepth, enableDepthEffects
#ifdef USES_DIRECT_AO
        , directOcclusion
#endif
#ifdef USES_BACKLIGHT
        , backlightColor
#endif
#ifdef DEFERRED_CLUSTER
        , sceneDepth
#endif
#ifdef MATERIAL_PBR_SPECULAR
        , specularColor, roughness, perceptualRoughness
#endif
    );
    directLighting = result.lighting;
#ifdef MATERIAL_PBR_SPECULAR
    directLighting += result.specularLighting;
#endif
    rimLighting = vec3_splat(0.0);

#ifdef TOON_FULL_SHADE
#ifndef MATERIAL_PBR_SPECULAR
    directLighting += directOcclusion * GetToonDirectSpecular(specularColor, roughness, perceptualRoughness,
        normalDirection, viewDirection, result.rampLightDirection)
        * result.rampShadowAttenuation * result.rampLightFactor;
#endif
    rimLighting = directOcclusion * GetToonRimLighting(toonParams, result.rimMask, result.rampShadowAttenuation,
        result.rampLightColor);
#endif
}

vec3 EvaluateToonIndirectDiffuseLighting(vec3 diffuseColor, float occlusion)
{
    return GI_IndirectDiffuse(vec3_splat(0.0), occlusion) * diffuseColor;
}

void EvaluateToonIndirectLighting(vec3 diffuseColor, vec3 specularColor, float oneMinusReflectivity,
    float roughness, float perceptualRoughness, vec3 normalDirection, vec3 indirectNormalDirection,
    vec3 viewDirection, float occlusion,
    out vec3 indirectDiffuse, out vec3 indirectSpecular)
{
    indirectDiffuse = EvaluateToonIndirectDiffuseLighting(diffuseColor, occlusion);
    indirectSpecular = GI_IndirectSpecular(normalDirection, viewDirection, perceptualRoughness, occlusion);
    float NdotV = abs(dot(normalDirection, viewDirection));
#if UNITY_ENV_BRDF
    float surfaceReduction = 1.0 / (roughness * roughness + 1.0);
    float grazingTerm = saturate(1.0 - perceptualRoughness + (1.0 - oneMinusReflectivity));
    indirectSpecular *= surfaceReduction
        * FresnelLerp(specularColor, vec3_splat(grazingTerm), NdotV);
#else
    indirectSpecular *= EnvBRDFApprox(specularColor, perceptualRoughness, NdotV);
#endif
}

vec3 ApplyToonNdotVRimGuard(vec3 baseLighting, vec3 rimLighting,
    vec3 rimNormalDirection, vec3 viewDirection, float rimIntensity)
{
#if !defined(DEFERRED)
#ifndef USES_RIM
    BRANCH if (rimIntensity <= 0.0)
        return vec3_splat(0.0);
#endif

    float NoV = saturate(dot(rimNormalDirection, viewDirection));
    float guardWidth = max(fwidth(NoV) * TOON_NDOTV_RIM_GUARD_PIXELS, M_EPSILON);
    float interiorBlend = smoothstep(0.0, guardWidth, NoV);

    // Keep outer MSAA coverage samples below the non-HDR ceiling without dimming the inner Rim.
    float basePeak = max(max(baseLighting.r, baseLighting.g), baseLighting.b);
    float rimPeak = max(max(rimLighting.r, rimLighting.g), rimLighting.b);
    float guardedScale = saturate((TOON_NDOTV_RIM_GUARD_MAX_OUTPUT - basePeak)
        / max(rimPeak, M_EPSILON));
    return mix(rimLighting * guardedScale, rimLighting, interiorBlend);
#else
    return rimLighting;
#endif
}

vec3 MetallicToonPBR(ToonSurfaceParams toonParams, vec3 baseColor, float metallic, float specular, float perceptualRoughness,
    hvec3 worldPos, vec3 normalDirection, vec3 indirectNormalDirection, vec3 viewDirection,
    vec3 shadow, float occlusion, float areaType, float toonLightingInput, vec2 screenUV, float currentLinearDepth
#ifdef USES_DIRECT_AO
    , float directOcclusion
#endif
#ifdef USES_BACKLIGHT
    , vec3 backlightColor
#endif
#ifdef DEFERRED_CLUSTER
    , hfloat sceneDepth
#endif
)
{
#if defined(PAINTABLE) && defined(PAINTABLE_UV_AVAILABLE)
    ApplyPaintMap(baseColor, metallic, perceptualRoughness);
#endif
    perceptualRoughness = mix(perceptualRoughness, cGlobalRoughness, cGlobalRoughnessOn);
#ifdef USES_BACKLIGHT
    backlightColor *= baseColor * (1.0 - metallic);
#endif
    float oneMinusReflectivity;
    vec3 specularColor = vec3_splat(specular);
    vec3 diffuseColor = DiffuseAndSpecularFromMetallicEx(
        baseColor, metallic, specularColor, oneMinusReflectivity);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

    vec3 finalColor;
    vec3 rimLighting;
    EvaluateToonDirectLighting(toonParams, baseColor, specularColor, roughness, perceptualRoughness,
        worldPos, normalDirection, indirectNormalDirection, viewDirection, shadow, areaType, toonLightingInput, screenUV, currentLinearDepth, true
#ifdef USES_DIRECT_AO
        , directOcclusion
#endif
#ifdef USES_BACKLIGHT
        , backlightColor
#endif
#ifdef DEFERRED_CLUSTER
        , sceneDepth
#endif
        , finalColor, rimLighting);

#if defined(AMBIENT)
    // Forward 只有 litbase 带 AMBIENT；Deferred 每盏 Light Volume 都有，靠平行光 Replace 留下最后一次。
    vec3 indirectDiffuse;
    vec3 indirectSpecular;
    EvaluateToonIndirectLighting(diffuseColor, specularColor, oneMinusReflectivity,
        roughness, perceptualRoughness, normalDirection, indirectNormalDirection, viewDirection, occlusion,
        indirectDiffuse, indirectSpecular);
    // 间接漫反射只作暗部托底，逐通道 max 避免加法冲淡 Toon 明暗分区。
    finalColor = max(finalColor, indirectDiffuse) + indirectSpecular;
#endif
    // Rim 在 max 合成之后追加，避免被环境漫反射 max 吞掉
    rimLighting = ApplyToonNdotVRimGuard(finalColor, rimLighting,
        indirectNormalDirection, viewDirection, toonParams.rimColor.a);
    finalColor += rimLighting;
    return finalColor;
}

vec3 MetallicToonOutline(ToonSurfaceParams toonParams, vec3 outlineAlbedo, hvec3 worldPos, vec3 normalDirection,
    vec3 indirectNormalDirection, vec3 viewDirection, vec3 shadow, float occlusion, float areaType, float toonLightingInput,
    float outlineBrightness
#ifdef USES_DIRECT_AO
    , float directOcclusion
#endif
#ifdef USES_BACKLIGHT
    , vec3 backlightColor
#endif
#ifdef DEFERRED_CLUSTER
    , hfloat sceneDepth
#endif
)
{
#if RENDER_QUALITY < RENDER_QUALITY_HIGH
    return outlineAlbedo * max(outlineBrightness, 0.0);
#else
#ifdef USES_BACKLIGHT
    backlightColor *= outlineAlbedo;
#endif
    ToonDirectDiffuseLighting direct = EvaluateToonDirectDiffuseLighting(toonParams, outlineAlbedo, worldPos,
        normalDirection, indirectNormalDirection, viewDirection, shadow, areaType, toonLightingInput, vec2_splat(0.0), 0.0, false
#ifdef USES_DIRECT_AO
        , directOcclusion
#endif
#ifdef USES_BACKLIGHT
        , backlightColor
#endif
#ifdef DEFERRED_CLUSTER
        , sceneDepth
#endif
#ifdef MATERIAL_PBR_SPECULAR
        , vec3_splat(0.0), 1.0, 1.0
#endif
    );
    vec3 indirectDiffuse = EvaluateToonIndirectDiffuseLighting(outlineAlbedo, occlusion);
    return max(direct.lighting, indirectDiffuse) * max(outlineBrightness, 0.0);
#endif
}

#ifdef SPLIT_LIGHTING
void MetallicToonPBR_Split(ToonSurfaceParams toonParams, vec3 baseColor, float metallic, float specular, float perceptualRoughness,
    hvec3 worldPos, vec3 normalDirection, vec3 indirectNormalDirection, vec3 viewDirection,
    vec3 shadow, float occlusion,
    float areaType, float toonLightingInput, vec2 screenUV, float currentLinearDepth
#ifdef USES_DIRECT_AO
    , float directOcclusion
#endif
#ifdef USES_BACKLIGHT
    , vec3 backlightColor
#endif
#ifdef DEFERRED_CLUSTER
    , hfloat sceneDepth
#endif
    , out vec3 outSceneLighting, out vec3 outEnvSpecular)
{
#if defined(PAINTABLE) && defined(PAINTABLE_UV_AVAILABLE)
    ApplyPaintMap(baseColor, metallic, perceptualRoughness);
#endif
    perceptualRoughness = mix(perceptualRoughness, cGlobalRoughness, cGlobalRoughnessOn);
#ifdef USES_BACKLIGHT
    backlightColor *= baseColor * (1.0 - metallic);
#endif
    float oneMinusReflectivity;
    vec3 specularColor = vec3_splat(specular);
    vec3 diffuseColor = DiffuseAndSpecularFromMetallicEx(
        baseColor, metallic, specularColor, oneMinusReflectivity);
    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

    vec3 directLighting;
    vec3 rimLighting;
    EvaluateToonDirectLighting(toonParams, baseColor, specularColor, roughness, perceptualRoughness,
        worldPos, normalDirection, indirectNormalDirection, viewDirection, shadow, areaType, toonLightingInput, screenUV, currentLinearDepth, true
#ifdef USES_DIRECT_AO
        , directOcclusion
#endif
#ifdef USES_BACKLIGHT
        , backlightColor
#endif
#ifdef DEFERRED_CLUSTER
        , sceneDepth
#endif
        , directLighting, rimLighting);
    vec3 indirectDiffuse;
    EvaluateToonIndirectLighting(diffuseColor, specularColor, oneMinusReflectivity,
        roughness, perceptualRoughness, normalDirection, indirectNormalDirection, viewDirection, occlusion,
        indirectDiffuse, outEnvSpecular);
    outSceneLighting = max(directLighting, indirectDiffuse) + rimLighting;
}

void MetallicToonOutline_Split(ToonSurfaceParams toonParams, vec3 outlineAlbedo, hvec3 worldPos, vec3 normalDirection,
    vec3 indirectNormalDirection, vec3 viewDirection, vec3 shadow, float occlusion, float areaType, float toonLightingInput,
    float outlineBrightness
#ifdef USES_DIRECT_AO
    , float directOcclusion
#endif
#ifdef USES_BACKLIGHT
    , vec3 backlightColor
#endif
#ifdef DEFERRED_CLUSTER
    , hfloat sceneDepth
#endif
    , out vec3 outSceneLighting)
{
#if RENDER_QUALITY < RENDER_QUALITY_HIGH
    outSceneLighting = outlineAlbedo * max(outlineBrightness, 0.0);
#else
#ifdef USES_BACKLIGHT
    backlightColor *= outlineAlbedo;
#endif
    ToonDirectDiffuseLighting direct = EvaluateToonDirectDiffuseLighting(toonParams, outlineAlbedo, worldPos,
        normalDirection, indirectNormalDirection, viewDirection, shadow, areaType, toonLightingInput, vec2_splat(0.0), 0.0, false
#ifdef USES_DIRECT_AO
        , directOcclusion
#endif
#ifdef USES_BACKLIGHT
        , backlightColor
#endif
#ifdef DEFERRED_CLUSTER
        , sceneDepth
#endif
    );
    float brightness = max(outlineBrightness, 0.0);
    vec3 indirectDiffuse = EvaluateToonIndirectDiffuseLighting(outlineAlbedo, occlusion);
    outSceneLighting = max(direct.lighting, indirectDiffuse) * brightness;
#endif
}
#endif
