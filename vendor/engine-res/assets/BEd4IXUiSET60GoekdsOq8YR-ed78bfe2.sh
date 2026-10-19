#ifndef __SCREENPOS_SH__
#define __SCREENPOS_SH__

vec3 GetCameraForwardDir()
{
    return vec3(cView[0][2], cView[1][2], cView[2][2]);
}

#if COMPILEVS
mat3 GetCameraRot()
{
    return mat3(cViewInv[0][0], cViewInv[0][1], cViewInv[0][2],
        cViewInv[1][0], cViewInv[1][1], cViewInv[1][2],
        cViewInv[2][0], cViewInv[2][1], cViewInv[2][2]);
}

#if !BGFX_SHADER_LANGUAGE_GLSL
vec4 GetScreenPos(vec4 clipPos)
{
    return vec4(
        clipPos.x * cGBufferOffsets.z + cGBufferOffsets.x * clipPos.w,
        -clipPos.y * cGBufferOffsets.w + cGBufferOffsets.y * clipPos.w,
        0.0,
        clipPos.w);
}

vec2 GetScreenPosPreDiv(vec4 clipPos)
{
    return vec2(
        clipPos.x / clipPos.w * cGBufferOffsets.z + cGBufferOffsets.x,
        -clipPos.y / clipPos.w * cGBufferOffsets.w + cGBufferOffsets.y);
}


vec2 GetQuadTexCoord(vec4 clipPos)
{
    return vec2(
        clipPos.x / clipPos.w * 0.5 + 0.5,
        -clipPos.y / clipPos.w * 0.5 + 0.5);
}

vec2 GetSSAOTexCoord(vec4 clipPos)
{
    return vec2(clipPos.x, -clipPos.y);
}

hvec4 GetScreenPos(hvec4 clipPos)
{
    return hvec4_init(
        clipPos.x * cGBufferOffsets.z + cGBufferOffsets.x * clipPos.w,
        -clipPos.y * cGBufferOffsets.w + cGBufferOffsets.y * clipPos.w,
        0.0,
        clipPos.w);
}

hvec2 GetScreenPosPreDiv(hvec4 clipPos)
{
    return hvec2_init(
        clipPos.x / clipPos.w * cGBufferOffsets.z + cGBufferOffsets.x,
        -clipPos.y / clipPos.w * cGBufferOffsets.w + cGBufferOffsets.y);
}


hvec2 GetQuadTexCoord(hvec4 clipPos)
{
    return hvec2_init(
        clipPos.x / clipPos.w * 0.5 + 0.5,
        -clipPos.y / clipPos.w * 0.5 + 0.5);
}

hvec2 GetSSAOTexCoord(hvec4 clipPos)
{
    return hvec2_init(clipPos.x, -clipPos.y);
}

#else

vec4 GetScreenPos(vec4 clipPos)
{
    return vec4(
        clipPos.x * cGBufferOffsets.z + cGBufferOffsets.x * clipPos.w,
        clipPos.y * cGBufferOffsets.w + cGBufferOffsets.y * clipPos.w,
        0.0,
        clipPos.w);
}

vec2 GetScreenPosPreDiv(vec4 clipPos)
{
    return vec2(
        clipPos.x / clipPos.w * cGBufferOffsets.z + cGBufferOffsets.x,
        clipPos.y / clipPos.w * cGBufferOffsets.w + cGBufferOffsets.y);
}

vec2 GetQuadTexCoord(vec4 clipPos)
{
    return vec2(
        clipPos.x / clipPos.w * 0.5 + 0.5,
        clipPos.y / clipPos.w * 0.5 + 0.5);
}

vec2 GetSSAOTexCoord(vec4 clipPos)
{
    return vec2(clipPos.x, clipPos.y);
}

#endif


vec2 GetQuadTexCoord(hvec3 worldPos)
{
    return vec2(
        worldPos.x * 0.5 + 0.5,
        worldPos.y * 0.5 + 0.5);
}

vec2 GetQuadTexCoordNoFlip(vec4 clipPos)
{
    return vec2(
        clipPos.x / clipPos.w * 0.5 + 0.5,
        -clipPos.y / clipPos.w * 0.5 + 0.5);
}

vec2 GetQuadTexCoordNoFlip(hvec3 worldPos)
{
    return vec2(
        worldPos.x * 0.5 + 0.5,
        -worldPos.y * 0.5 + 0.5);
}

hvec3 GetFarRay(hvec4 clipPos)
{
    hvec3 viewRay = hvec3_init(
        clipPos.x / clipPos.w * cFrustumSize.x,
        clipPos.y / clipPos.w * cFrustumSize.y,
        cFrustumSize.z);

    return mul(viewRay, GetCameraRot());
}

hvec3 GetNearRay(hvec4 clipPos)
{
    hvec3 viewRay = hvec3_init(
        clipPos.x / clipPos.w * cFrustumSize.x,
        clipPos.y / clipPos.w * cFrustumSize.y,
        0.0);

    return mul(viewRay, GetCameraRot()) * cDepthMode.x;
}
#endif

// Convert a direction expressed in clip/view XY orientation to screen-texture UV orientation.
vec2 GetScreenUVDirection(vec2 direction)
{
#if !BGFX_SHADER_LANGUAGE_GLSL
    direction.y = -direction.y;
#endif
    return direction;
}

// Unlit / pre-baked lighting passthrough: the resolve switch (StandardPBRDeferred) has no
// case for ID 0, so sceneLighting starts from RT3 emissive as-is — no direct light / IBL added.
#define SHADINGMODELID_UNLIT 0u
#define SHADINGMODELID_PBR_LIT 1u
#define SHADINGMODELID_LAMBERT_LIT 2u
// Toon (Surface Shader shading_model_toon) uses the PBR_LIT GBuffer layout.
// GBuffer A.a stores the 2-bit Toon Area Type; C.a stores the calculated Toon Ramp.
#define SHADINGMODELID_TOON_LIT 3u
#define SHADINGMODELID_TOON_OUTLINE 4u
#define SHADINGMODELID_CLEAR_COAT 5u
// PBR direct backlighting; GBuffer E stores nonnegative BACKLIGHT as RGBE8.
#define SHADINGMODELID_PBR_BACKLIGHT 6u

// Material properties that can be decoded independently from the native GBuffer layout.
bool GBufferHasMaterialScalars(uint model)
{
    return model == SHADINGMODELID_PBR_LIT || model == SHADINGMODELID_TOON_LIT || model == SHADINGMODELID_CLEAR_COAT ||
        model == SHADINGMODELID_PBR_BACKLIGHT;
}

bool GBufferHasMaterialColors(uint model)
{
    return GBufferHasMaterialScalars(model) || model == SHADINGMODELID_LAMBERT_LIT ||
        model == SHADINGMODELID_TOON_OUTLINE;
}

bool IsKnownGBufferShadingModel(uint model)
{
    return model == SHADINGMODELID_UNLIT || GBufferHasMaterialColors(model);
}

// Clear coat custom data: coverage, perceptual roughness, absolute octahedral bottom normal.
// Absolute encoding keeps the substrate stable when a GBuffer postprocess edits the top normal.
vec2 EncodeClearCoatBottomNormal(vec3 normal)
{
    normal /= abs(normal.x) + abs(normal.y) + abs(normal.z);
    if (normal.z < 0.0)
        normal.xy = (1.0 - abs(normal.yx)) * vec2(normal.x >= 0.0 ? 1.0 : -1.0, normal.y >= 0.0 ? 1.0 : -1.0);
    return normal.xy * 0.5 + 0.5;
}

vec3 DecodeClearCoatBottomNormal(vec4 coat)
{
    vec2 oct = coat.ba * 2.0 - 1.0;
    vec3 normal = vec3(oct, 1.0 - abs(oct.x) - abs(oct.y));
    float t = saturate(-normal.z);
    normal.xy += vec2(normal.x >= 0.0 ? -t : t, normal.y >= 0.0 ? -t : t);
    return normalize(normal);
}

float GetClearCoatSSRoughness(vec4 material, vec4 coat)
{
    return uint(round(material.a * 255.0)) == SHADINGMODELID_CLEAR_COAT ? mix(material.b, coat.g, coat.r) : material.b;
}

#if defined(DEFERRED) || defined(MATERIALBAKE)
#if defined(PAINTABLE) && defined(PAINTABLE_UV_AVAILABLE)
    #define ApplyGBufferPaintMapWrapper(diffuseColor, metallic, roughness) ApplyPaintMap(diffuseColor, metallic, roughness)
#else
    #define ApplyGBufferPaintMapWrapper(diffuseColor, metallic, roughness)
#endif

// Encode material AO as clamped [0, 1] visibility in base-color alpha for PBR/Clear Coat.
// Pass 1.0 when the material has no AO input.
// Callers with another shading model retain responsibility for that model's alpha payload.
#ifdef MOBILE_DEFERRED
#include "PBR/MobileGBuffer.sh"
#define EncodeGBufferPBR(diffuseColor, metallic, specular, roughness, normalDirection, emissiveColor, shadingModelID, materialAO) \
    { \
        vec3 mobileDiffuseColor = diffuseColor; \
        float mobileMetallic = metallic; \
        float mobileRoughness = roughness; \
        ApplyGBufferPaintMapWrapper(mobileDiffuseColor, mobileMetallic, mobileRoughness); \
        EncodeMobileGBuffer(mobileDiffuseColor, mobileMetallic, specular, mobileRoughness, normalDirection, emissiveColor, shadingModelID, materialAO); \
    }
#else
// vec3 diffuseColor, float metallic, float specular, float roughness, vec3 normalDirection, vec3 emissiveColor, float shadingModelID, float materialAO
#define EncodeGBufferPBR(diffuseColor, metallic, specular, roughness, normalDirection, emissiveColor, shadingModelID, materialAO) \
    { \
    vec3 gbufferDiffuseColor = diffuseColor; \
    float gbufferMetallic = metallic; \
    float gbufferRoughness = roughness; \
    ApplyGBufferPaintMapWrapper(gbufferDiffuseColor, gbufferMetallic, gbufferRoughness); \
    gl_FragData[0].rgb = EncodeNormal(normalDirection); \
    gl_FragData[1].r = gbufferMetallic; \
    gl_FragData[1].g = specular; \
    gl_FragData[1].b = gbufferRoughness; \
    gl_FragData[1].a = float(shadingModelID) / 255.0; \
    gl_FragData[2].rgb = gbufferDiffuseColor; \
    gl_FragData[2].a = saturate(materialAO); /* Toon overwrites with its ramp after encode */ \
    gl_FragData[3].rgb = emissiveColor; \
    }

#endif // MOBILE_DEFERRED

#ifdef MOBILE_DEFERRED
// Unsupported material models must fail compilation instead of silently writing the desktop layout.
#define EncodeGBufferLambert(diffColor, specColor, normalDirection, emissiveColor, shadingModelID) \
    MOBILE_DEFERRED_LAMBERT_REQUIRES_AN_EXPLICIT_MATERIAL_ADAPTER
#else
// vec3 diffColor, vec4 specColor, vec3 normalDirection, vec3 emissiveColor, float shadingModelID
#define EncodeGBufferLambert(diffColor, specColor, normalDirection, emissiveColor, shadingModelID) \
    gl_FragData[0].rgb = EncodeNormal(normalDirection); \
    gl_FragData[1].rgb = specColor.rgb; \
    gl_FragData[1].a = float(shadingModelID) / 255.0; \
    gl_FragData[2].rgb = diffColor; \
    gl_FragData[2].a = specColor.a / 255.0; \
    gl_FragData[3].rgb = emissiveColor;
#endif // MOBILE_DEFERRED

#ifdef COMPILEPS
// Reconstructs a flat geometric normal from screen-space derivatives of the world position
// (the unlit shaders have no normal varying). dFdy handedness differs per graphics API
// (GL NDC origin is bottom-left, D3D top-left); instead of per-API sign fixes, flip toward
// the camera — GBuffer consumers (SSAO/SSGI/SSR denoiser edge-stopping) only need a
// plausibly oriented surface normal.
vec3 GBufferFaceNormal(vec3 worldPos, vec3 cameraPos)
{
    vec3 faceNormal = cross(dFdx(worldPos), dFdy(worldPos));
    float len = length(faceNormal);
    if (len < 1e-8)
        return vec3(0.0, 1.0, 0.0);
    faceNormal /= len;
    return dot(faceNormal, cameraPos - worldPos) < 0.0 ? -faceNormal : faceNormal;
}
#endif

// vec3 unlitColor, vec3 normalDirection
// - RT1 roughness is written as 1: the SSR trace launches rays based on roughness, so 1 means
//   no rays (SSRComposite already filters by shadingModelID; this guards consumers that skip
//   the ID check)
// - RT3 stores the final color WITHOUT fog: GBuffer encode branches drop fog by convention and
//   the SceneFog quad re-applies it depth-based to all opaque pixels (see CEMapDeferred.xml);
//   fogging here would get fogged twice
#ifdef MOBILE_DEFERRED
#define EncodeGBufferUnlit(unlitColor, normalDirection) \
    EncodeMobileGBuffer(vec3_splat(0.0), 0.0, 0.0, 1.0, normalDirection, unlitColor, SHADINGMODELID_UNLIT, 1.0)
#else
#define EncodeGBufferUnlit(unlitColor, normalDirection) \
    { \
    gl_FragData[0] = vec4(EncodeNormal(normalDirection), 1.0); \
    gl_FragData[1] = vec4(0.0, 0.0, 1.0, float(SHADINGMODELID_UNLIT) / 255.0); \
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, 0.0); \
    gl_FragData[3] = vec4(unlitColor, 1.0); \
    }

#endif // MOBILE_DEFERRED

// Material baking is an independent output mode. Colors are linear; normals use
// the material's shading basis (model space when the baker uses an identity model).
// The reflected uniform identifies shaders that actually call this encoder. The
// baker supplies 1, so RT3.a also distinguishes written pixels from clear/discard.
#ifdef MATERIALBAKE
uniform vec4 u_MaterialBakeOutput;
#define EncodeGBufferBake(diffuseColor, diffuseAlpha, roughness, metallic, occlusion, normalDirection, emissiveColor) \
    { \
    vec3 bakeDiffuse = diffuseColor; \
    float bakeMetallic = metallic; \
    float bakeRoughness = roughness; \
    ApplyGBufferPaintMapWrapper(bakeDiffuse, bakeMetallic, bakeRoughness); \
    gl_FragData[0] = vec4(bakeDiffuse, diffuseAlpha); \
    gl_FragData[1] = vec4(bakeRoughness, bakeMetallic, occlusion, 1.0); \
    gl_FragData[2] = vec4(EncodeNormal(normalDirection), 1.0); \
    gl_FragData[3] = vec4(emissiveColor, u_MaterialBakeOutput.x); \
    }
#endif

#endif
#endif
