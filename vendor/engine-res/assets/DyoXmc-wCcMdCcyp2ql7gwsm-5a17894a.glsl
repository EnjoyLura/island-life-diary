#include "varying_deferred.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position
    $output vTexCoord, vScreenPos, vFarRay _VNEARRAY
#endif
#ifdef COMPILEPS
    $input vTexCoord, vScreenPos, vFarRay _VNEARRAY
#endif

#include "Common/common.sh"

#ifdef LIGHTVOLUME_BASE_ONLY
    // 空光体积命令仍需写入环境光和自发光，不求值直接光及其阴影。
    #undef PERPIXEL
    #undef SHADOW
    #undef TEMPORAL_SHADOW_FILTER
    #undef CLOUD_SHADOW
    #undef VOXEL_SHADOW_VOLUME
#endif

#if defined(REFLECTION_CAPTURE) && !defined(REFLECTION_CAPTURE_AMBIENT)
    // 捕获的环境光由独立全屏 pass 求值，灯光批次不能再次累加。
    #undef AMBIENT
#endif

#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "lighting.sh"
#include "fog.sh"
#include "constants.sh"
#ifdef REFLECTION_CAPTURE_AMBIENT
    #undef cLightColor
    #undef cLightDirPS
    #define cLightColor vec4(0.0, 0.0, 0.0, 0.0)
    #define cLightDirPS vec3(0.0, 1.0, 0.0)
#endif
SAMPLER2D(u_GBuffer0, 0);
SAMPLER2D(u_GBuffer1, 1);
SAMPLER2D(u_GBuffer2, 2);
SAMPLER2D(u_GBuffer3, 3);
SAMPLER2D(u_GBuffer4, 4);
#if defined(DEFERRED_CLEAR_COAT) || defined(DEFERRED_BACKLIGHT)
SAMPLER2D(u_DeferredCustomData7, 7);
#endif
#ifdef TEMPORAL_SHADOW_FILTER
// This directional-only variation does not sample the depth atlas; reuse its otherwise unused slot.
SAMPLER2D(u_TemporalShadowMask10, 10);
#endif
#if defined(CLOUD_SHADOW) && defined(DIRLIGHT)
// Directional cloud shadow owns slot 6 when the experimental voxel-shadow path is inactive.
// Local light volumes keep their shape texture; Cluster shadow data remains at slot 11.
SAMPLER2D(u_CloudShadow6, 6);
uniform hmat4 u_CloudShadowWorldToUV;
uniform hvec4 u_CloudShadowParams;
uniform hvec4 u_CloudShadowDirection;
#include "Volumetric/VolumetricCloudShadowCommon.sh"
#endif
#ifdef LIGHTMAP
#include "LightMap.sh"
#endif
#ifdef COMPILEPS
// 延迟运行时分发：同一编译产物按 GBuffer shading model ID 选择 PBR、Toon 或 Toon Outline。
#include "PBR/StandardPBR.sh"
#ifdef DEFERRED_CLEAR_COAT
#include "PBR/DeferredClearCoat.sh"
#endif
#ifdef DEFERRED_BACKLIGHT
#include "PBR/DeferredBacklight.sh"
#endif
#include "Toon/ToonLighting.sh"
#include "lambert.sh"
#include "Voxel/VoxelShadowVolume.sh"
#endif

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    #ifdef DIRLIGHT
        vScreenPos = GetScreenPosPreDiv(gl_Position);
        vFarRay = GetFarRay(gl_Position);
        #ifdef ORTHO
            vNearRay = GetNearRay(gl_Position);
        #endif
    #else
        vScreenPos = GetScreenPos(gl_Position);
        vFarRay = GetFarRay(gl_Position) * gl_Position.w;
        #ifdef ORTHO
            vNearRay = GetNearRay(gl_Position) * gl_Position.w;
        #endif
    #endif
}

void PS()
{
    // 局部灯光体积的屏幕坐标与视线均携带 clip.w，需要先做透视除法。
    hfloat inverseScreenW = 1.0;
#ifndef DIRLIGHT
    inverseScreenW = 1.0 / max(vScreenPos.w, 0.0001);
#endif
    hvec2 screenUV = vScreenPos.xy * inverseScreenW;
    hfloat sourceDepth = texture2D(u_GBuffer4, screenUV).r;
    hfloat depth = ReconstructDepth(sourceDepth);
    // ReconstructDepth already accounts for the camera depth convention, including reversed-Z.
    hfloat linearEyeDepth = depth * cFarClipPS;
    #ifdef ORTHO
        hvec3 worldPos = mix(vNearRay, vFarRay, depth);
    #else
        hvec3 worldPos = vFarRay * depth;
    #endif
    worldPos *= inverseScreenW;
    vec4 encodedNormalArea = texture2D(u_GBuffer0, screenUV);
    vec3 normalDirection = normalize(DecodeNormal(encodedNormalArea.rgb));
    vec4 metallicSpecularRoughnessID = texture2D(u_GBuffer1, screenUV);
#ifdef REFLECTION_CAPTURE
    metallicSpecularRoughnessID.b = 1.0;
#endif
    vec4 baseColor = texture2D(u_GBuffer2, screenUV);
    vec3 emissiveColor = texture2D(u_GBuffer3, screenUV).rgb;

    // Position acquired via near/far ray is relative to camera. Bring position to world space
    hvec3 eyeVec = -worldPos;
    worldPos += cCameraPosPS;

    hvec4 projWorldPos = hvec4_init(worldPos, 1.0);

    #ifdef TEMPORAL_SHADOW_FILTER
        hfloat visibility = texture2D(u_TemporalShadowMask10, screenUV).r;
        float shadow = GetDirShadowFade(cShadowIntensity.y + 4.0 * cShadowIntensity.x * visibility, depth);
    #elif defined(SHADOW)
        float shadow = GetShadowDeferred(projWorldPos, normalDirection, depth);
    #else
        float shadow = 1.0;
    #endif

#if defined(CLOUD_SHADOW) && defined(DIRLIGHT)
    if (dot(cLightDirPS, -u_CloudShadowDirection.xyz) > 0.9999)
        shadow *= SampleCloudShadow(projWorldPos.xyz, u_CloudShadowWorldToUV, u_CloudShadowParams.x, u_CloudShadow6);
#endif

    #if defined(VOXEL_SHADOW_VOLUME) && defined(DIRLIGHT)
        shadow = min(shadow, GetVoxelShadowVolumeVisibility(worldPos.xyz, normalDirection, cLightDirPS));
    #endif

    vec3 viewDirection = normalize(eyeVec);
    uint shadingModelID = uint(round(metallicSpecularRoughnessID.a * 255.0));
#ifdef SPLIT_LIGHTING
    // ========================================
    // Split output mode: Output to three RenderTargets
    // Used by reflection hierarchy system (SSR replaces env specular, SSGI replaces env diffuse)
    // ========================================
    vec3 sceneLighting = emissiveColor;  // Emissive goes into scene lighting
#if defined(REFLECTION_CAPTURE) && !defined(REFLECTION_CAPTURE_AMBIENT)
    sceneLighting = vec3(0.0, 0.0, 0.0);
#endif
    vec3 envSpecular = vec3(0.0, 0.0, 0.0);
    vec3 envDiffuse = vec3(0.0, 0.0, 0.0);

    switch (shadingModelID)
    {
#ifdef DEFERRED_CLEAR_COAT
        case SHADINGMODELID_CLEAR_COAT:
        {
            vec4 coat = texture2D(u_DeferredCustomData7, screenUV);
#ifdef REFLECTION_CAPTURE
            coat.g = 1.0;
#endif
            vec3 sceneLit, envSpec, envDiff;
            MetallicPBR_Split(baseColor.rgb, metallicSpecularRoughnessID.r, metallicSpecularRoughnessID.g,
                metallicSpecularRoughnessID.b, worldPos, normalDirection, viewDirection, vec3(shadow, shadow, shadow), baseColor.a
#ifdef DEFERRED_CLUSTER
                , linearEyeDepth
#endif
                , coat.r, coat.g, DecodeClearCoatBottomNormal(coat), sceneLit, envSpec, envDiff);
            sceneLighting += sceneLit;
            envSpecular = envSpec;
            envDiffuse = envDiff;
            break;
        }
#endif
        case SHADINGMODELID_TOON_LIT:
        {
            vec3 sceneLit, envSpec;
            MetallicToonPBR_Split(
                GetZoneToonSurfaceParams(),
                baseColor.rgb,
                metallicSpecularRoughnessID.r,
                metallicSpecularRoughnessID.g,
                metallicSpecularRoughnessID.b,
                worldPos,
                normalDirection,
                normalDirection,
                viewDirection,
                vec3(shadow, shadow, shadow),
                1.0,
                round(encodedNormalArea.a * 3.0), // toonAreaType
                baseColor.a, // toonRamp
                screenUV,
                // Depth Rim 的深度比较必须与偏移采样点同为线性视空间单位，
                // 不能传 ReconstructDepth 的 0~1 归一化值
                linearEyeDepth
#ifdef DEFERRED_CLUSTER
                , linearEyeDepth
#endif
                , sceneLit,
                envSpec
            );
            sceneLighting += sceneLit;
            envSpecular = envSpec;
            break;
        }

        case SHADINGMODELID_TOON_OUTLINE:
        {
            vec3 sceneLit;
            MetallicToonOutline_Split(
                GetZoneToonSurfaceParams(),
                baseColor.rgb,
                worldPos,
                normalDirection,
                normalDirection,
                viewDirection,
                vec3(shadow, shadow, shadow),
                1.0,
                round(encodedNormalArea.a * 3.0), // toonAreaType
                baseColor.a, // toonRamp
                metallicSpecularRoughnessID.g
#ifdef DEFERRED_CLUSTER
                , linearEyeDepth
#endif
                , sceneLit
            );
            sceneLighting += sceneLit;
            break;
        }

#ifdef DEFERRED_BACKLIGHT
        case SHADINGMODELID_PBR_BACKLIGHT:
        {
            vec3 backlight = decodeRGBE8(texture2D(u_DeferredCustomData7, screenUV));
            vec3 sceneLit, envSpec, envDiff;
            BacklightMetallicPBRSplit(baseColor.rgb, metallicSpecularRoughnessID.r, metallicSpecularRoughnessID.g,
                metallicSpecularRoughnessID.b, worldPos, normalDirection, viewDirection, vec3_splat(shadow), baseColor.a,
                backlight
#ifdef DEFERRED_CLUSTER
                , linearEyeDepth
#endif
                , sceneLit, envSpec, envDiff);
            sceneLighting += sceneLit;
            envSpecular = envSpec;
            envDiffuse = envDiff;
            break;
        }
#endif
        case SHADINGMODELID_PBR_LIT:
        {
            vec3 sceneLit, envSpec, envDiff;
            MetallicPBR_Split(
                baseColor.rgb,
                metallicSpecularRoughnessID.r,  // metallic
                metallicSpecularRoughnessID.g,  // specular
                metallicSpecularRoughnessID.b,  // roughness
                worldPos,
                normalDirection,
                viewDirection,
                vec3(shadow, shadow, shadow),
                baseColor.a  // material AO; screen-space AO is combined inside the BRDF
#ifdef DEFERRED_CLUSTER
                , linearEyeDepth
#endif
                , sceneLit  // out: direct_diffuse + direct_specular
                , envSpec   // out: IBL_specular only
                , envDiff   // out: IBL_diffuse only
            );
            sceneLighting += sceneLit;
            envSpecular = envSpec;
            envDiffuse = envDiff;
            break;
        }

        case SHADINGMODELID_LAMBERT_LIT:
        {
            // Lambert has no specular reflection, all goes into scene lighting.
            // Note: Lambert ambient is NOT split into EnvDiffuse — the SSGI composite
            // must skip non-PBR/TOON shading models or Lambert would get double ambient.
            sceneLighting += LambertBRDF(
                baseColor.rgb,
                vec4(metallicSpecularRoughnessID.rgb, baseColor.a * 255.0),
                worldPos,
                normalDirection,
                vec3(shadow, shadow, shadow),
                1.0
#ifdef DEFERRED_CLUSTER
                , linearEyeDepth
#endif
            );
            break;
        }
    }

    // MRT output for reflection hierarchy system
    // RT0: Resolved scene lighting + emissive
    // RT1: Env specular = IBL_specular only (SSR replaces this when available)
    // SPLIT_ENV_DIFFUSE (SSGI on): RT2 = PBR IBL_diffuse only (SSGI replaces it in composite).
    // Without it (SSGI off) the diffuse folds back into RT0 — saves the extra RT
    // bandwidth/allocation on the disabled path.
#ifdef REFLECTION_CAPTURE
    // 专用捕获仅保存直接光、漫反射环境光与自发光，避免局部反射反馈。
    gl_FragColor = vec4(sceneLighting + envDiffuse, 1.0);
#elif defined(DEFERRED_REFLECTIONS)
    // 环境镜面反射在统一合成阶段求值；漫反射仍按原 SSGI 开关拆分。
    #ifdef SPLIT_ENV_DIFFUSE
        gl_FragData[0] = vec4(sceneLighting, 1.0);
        gl_FragData[1] = vec4(envDiffuse, 1.0);
    #else
        gl_FragColor = vec4(sceneLighting + envDiffuse, 1.0);
    #endif
#elif defined(SPLIT_ENV_DIFFUSE)
    gl_FragData[0] = vec4(sceneLighting, 1.0);
    gl_FragData[1] = vec4(envSpecular, 1.0);
    gl_FragData[2] = vec4(envDiffuse, 1.0);
#else
    gl_FragData[0] = vec4(sceneLighting + envDiffuse, 1.0);
    gl_FragData[1] = vec4(envSpecular, 1.0);
#endif

#else
    // ========================================
    // Traditional mode: Single output (backward compatible)
    // ========================================
    gl_FragColor = vec4(emissiveColor, 1.0);

    switch (shadingModelID)
    {
#ifdef DEFERRED_CLEAR_COAT
        case SHADINGMODELID_CLEAR_COAT:
        {
            vec4 coat = texture2D(u_DeferredCustomData7, screenUV);
            gl_FragColor.rgb += MetallicPBR(baseColor.rgb, metallicSpecularRoughnessID.r, metallicSpecularRoughnessID.g,
                metallicSpecularRoughnessID.b, worldPos, normalDirection, viewDirection, vec3(shadow, shadow, shadow), baseColor.a
#ifdef DEFERRED_CLUSTER
                , linearEyeDepth
#endif
                , coat.r, coat.g, DecodeClearCoatBottomNormal(coat));
            break;
        }
#endif
        case SHADINGMODELID_TOON_LIT:
            gl_FragColor.rgb += MetallicToonPBR(GetZoneToonSurfaceParams(), baseColor.rgb,
                metallicSpecularRoughnessID.r, metallicSpecularRoughnessID.g,
                metallicSpecularRoughnessID.b, worldPos, normalDirection, normalDirection, viewDirection,
                vec3(shadow, shadow, shadow), 1.0, round(encodedNormalArea.a * 3.0), baseColor.a
                // 线性视空间深度，与 Depth Rim 偏移采样点同单位
                , screenUV, linearEyeDepth
            #ifdef DEFERRED_CLUSTER
                , linearEyeDepth
            #endif
            );
            break;

        case SHADINGMODELID_TOON_OUTLINE:
            gl_FragColor.rgb += MetallicToonOutline(GetZoneToonSurfaceParams(), baseColor.rgb,
                worldPos, normalDirection, normalDirection, viewDirection,
                vec3(shadow, shadow, shadow), 1.0, round(encodedNormalArea.a * 3.0), baseColor.a,
                metallicSpecularRoughnessID.g
            #ifdef DEFERRED_CLUSTER
                , linearEyeDepth
            #endif
            );
            break;

#ifdef DEFERRED_BACKLIGHT
        case SHADINGMODELID_PBR_BACKLIGHT:
        {
            vec3 backlight = decodeRGBE8(texture2D(u_DeferredCustomData7, screenUV));
            gl_FragColor.rgb += BacklightMetallicPBR(baseColor.rgb, metallicSpecularRoughnessID.r,
                metallicSpecularRoughnessID.g, metallicSpecularRoughnessID.b, worldPos, normalDirection,
                viewDirection, vec3_splat(shadow), baseColor.a, backlight
#ifdef DEFERRED_CLUSTER
                , linearEyeDepth
#endif
                );
            break;
        }
#endif
        case SHADINGMODELID_PBR_LIT:
            gl_FragColor.rgb += MetallicPBR(baseColor.rgb, metallicSpecularRoughnessID.r, metallicSpecularRoughnessID.g, metallicSpecularRoughnessID.b, worldPos, normalDirection, viewDirection, vec3(shadow, shadow, shadow), baseColor.a
            #ifdef DEFERRED_CLUSTER
                , linearEyeDepth
            #endif
            );
            break;

        case SHADINGMODELID_LAMBERT_LIT:
            gl_FragColor.rgb += LambertBRDF(baseColor.rgb, vec4(metallicSpecularRoughnessID.rgb, baseColor.a * 255.0), worldPos, normalDirection, vec3(shadow, shadow, shadow), 1.0
            #ifdef DEFERRED_CLUSTER
                , linearEyeDepth
            #endif
            );
            break;
    }
#endif // SPLIT_LIGHTING
}
