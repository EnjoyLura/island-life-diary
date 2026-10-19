// SURFACE_SLOT_FEATURE_MACROS
#ifdef SURFACE_USES_NORMAL_MAP
    #ifndef NORMALMAP
        #define NORMALMAP
    #endif
#endif

#define VELOCITY_PASS
#define SURFACE_OUTLINE_VELOCITY
#define INSTANCED_STROKE_PARAMS

#include "varying_surface_velocity.def.sc"
#include "urho3d_compatibility.sh"
#include "SurfaceShaderCompatibility.sh"
#ifdef COMPILEVS
    $input a_position, a_color0 _NORMAL _TEXCOORD0 _TEXCOORD1 _ATANGENT _SKINNED _INSTANCED _INSTANCED_EXTRA1 _INSTANCED_EXTRA2 _INSTANCED_EXTRA3
    $output vTexCoord, vCurrClip, vPrevClip _VCOLOR /* SURFACE_SLOT_VARYING_LIST */
#endif
#ifdef COMPILEPS
    $input vTexCoord, vCurrClip, vPrevClip _VCOLOR /* SURFACE_SLOT_VARYING_LIST */
#endif

#include "Common/common.sh"
#include "PBR/MaterialEnvironment.sh"
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "SurfaceGodotMatrices.sh"
#include "SurfaceCoverage.sh"
#include "SurfaceOutline.sh"
#include "SurfaceAlphaScissor.sh"
#include "Toon/ToonDitherClip.sh"
#include "constants.sh"

uniform hmat4 u_UnjitteredViewProj;
uniform hmat4 u_PrevViewProj;
uniform hmat4 u_PrevModel;

// Keep this vertex-stage scaffold aligned with the main Surface templates:
// custom vertex() order, object/world-space paths, skinning, inputs, and varyings.
// SURFACE_SLOT_CUSTOM_DECLARATIONS

void VS()
{
    // SURFACE_SLOT_VERTEX_MOTION_BODY
    hfloat surfaceZClipScale = 1.0;
    hvec4 surfaceClipPosition = hvec4_init(1.0, 1.0, 1.0, 1.0);
    #ifdef NOUV
        vec2 iTexCoord = vec2(0.0, 0.0);
    #endif
    hmat4 modelMatrix = iModelMatrix;
    #ifdef SURFACE_USES_MODELVIEW
        hmat4 surfaceModelViewMatrix = SurfaceGodotMatrix(mul(modelMatrix, cView));
        hmat3 surfaceModelViewNormalMatrix = SurfaceGodotNormalMatrix(mul(modelMatrix, cView));
    #endif
    #ifdef SURFACE_USES_FRAGMENT_MODEL_NORMAL
        hmat3 surfaceModelNormalMatrix = SurfaceGodotNormalMatrix(modelMatrix);
        vSurfaceNormalMatrixX = mul(surfaceModelNormalMatrix, hvec3_init(1.0, 0.0, 0.0));
        vSurfaceNormalMatrixY = mul(surfaceModelNormalMatrix, hvec3_init(0.0, 1.0, 0.0));
        vSurfaceNormalMatrixZ = mul(surfaceModelNormalMatrix, hvec3_init(0.0, 0.0, 1.0));
    #endif

    hvec4 surfaceVertexPos = iPos;
    hvec3 surfaceVertexNormal = iNormal;
    #if defined(NORMALMAP) || defined(SURFACE_USES_TANGENT) || defined(DIRBILLBOARD)
        hvec4 surfaceVertexTangent = iTangent;
    #else
        hvec4 surfaceVertexTangent = hvec4_init(1.0, 0.0, 0.0, 1.0);
    #endif

    #ifndef SURFACE_WORLD_VERTEX_COORDS
        vec2 surfaceUV = GetTexCoord(iTexCoord);
        vec2 surfaceUV2 = SurfaceGetUV2();
        DECLARE_SURFACE_COLOR_INPUTS
        hvec3 surfacePosition = surfaceVertexPos.xyz;
        vec3 surfaceNormal = surfaceVertexNormal;
        vec3 surfaceTangent = surfaceVertexTangent.xyz;
        vec3 surfaceBinormal = cross(surfaceTangent, surfaceNormal) * surfaceVertexTangent.w;
        // SURFACE_SLOT_VERTEX_OBJECT_BODY
        #ifdef SURFACE_USES_UV2
            vSurfaceUV2 = surfaceUV2;
        #endif
        surfaceVertexPos.xyz = surfacePosition;
        surfaceVertexNormal = surfaceNormal;
        surfaceVertexTangent.xyz = surfaceTangent;
    #endif

    // SURFACE_SLOT_VERTEX_VARYING_BODY

    #undef iPos
    #undef iNormal
    #undef iTangent
    #define iPos surfaceVertexPos
    #define iNormal surfaceVertexNormal
    #define iTangent surfaceVertexTangent

    #ifdef SURFACE_SKIP_VERTEX_TRANSFORM
        // vertex() returned view-space values; recover world-space lighting data without
        // applying the model, skinning or billboard expansion a second time.
        modelMatrix = cViewInv;
        #undef GetWorldPos
        #undef GetWorldNormal
        #undef GetWorldTangent
        #define GetWorldPos(matrix) mul(iPos, cViewInv).xyz
        #define GetWorldNormal(matrix) normalize(mul(hvec4_init(iNormal, 0.0), cViewInv).xyz)
        #define GetWorldTangent(matrix) hvec4_init(normalize(mul(hvec4_init(iTangent.xyz, 0.0), cViewInv).xyz), iTangent.w)
    #endif
    hvec3 surfaceOriginalWorldPos = GetWorldPos(modelMatrix);
    hvec3 bodyWorldPos = surfaceOriginalWorldPos;
    hvec3 bodyWorldNormal = GetWorldNormal(modelMatrix) * cNormalOddNegativeScale;

    #ifdef SURFACE_WORLD_VERTEX_COORDS
        hvec3 surfacePosition = bodyWorldPos;
        vec3 surfaceNormal = bodyWorldNormal;
        #if defined(NORMALMAP) || defined(SURFACE_USES_TANGENT) || defined(DIRBILLBOARD)
            vec4 surfaceWorldTangent = GetWorldTangent(modelMatrix);
        #else
            vec4 surfaceWorldTangent = vec4(1.0, 0.0, 0.0, 1.0);
        #endif
        vec3 surfaceTangent = surfaceWorldTangent.xyz;
        vec3 surfaceBinormal = cross(surfaceTangent, surfaceNormal) * surfaceWorldTangent.w * cBitangentOddNegativeScale;
        vec2 surfaceUV = GetTexCoord(iTexCoord);
        vec2 surfaceUV2 = SurfaceGetUV2();
        DECLARE_SURFACE_COLOR_INPUTS
        // SURFACE_SLOT_VERTEX_WORLD_BODY
        #ifdef SURFACE_USES_UV2
            vSurfaceUV2 = surfaceUV2;
        #endif
        bodyWorldPos = surfacePosition;
        bodyWorldNormal = normalize(surfaceNormal);
    #endif

    #ifdef SURFACE_USES_COLOR
        vColor = surfaceColor;
    #elif defined(VERTEXCOLOR)
        vColor = iColor;
    #endif

    hvec3 currentOutlineWorldPos = ExpandSurfaceOutline(bodyWorldPos, bodyWorldNormal, modelMatrix);

    #undef iPos
    #undef iNormal
    #undef iTangent
    #define iPos a_position
    #define iNormal a_normal
    #define iTangent a_tangent

    #ifdef SURFACE_USES_ALPHA_HASH
        vSurfaceHashPosition = SurfaceCoverageObjectPosition(currentOutlineWorldPos, iModelMatrix);
    #endif
    surfaceClipPosition = SurfaceOutlineClipPosition(surfaceClipPosition, GetClipPos(bodyWorldPos), GetClipPos(currentOutlineWorldPos));
    gl_Position = SurfaceApplyZClipScale(SurfaceSelectClipPosition(GetClipPos(currentOutlineWorldPos), surfaceClipPosition), surfaceZClipScale);
    gl_Position.z += SurfaceOutlineZBias(gl_Position);
    vCurrClip = surfaceCurrentClip;
    vPrevClip = surfacePreviousClip;
    vTexCoord = GetTexCoord(iTexCoord);
}

void PS()
{
    vec3 surfaceAlbedo = vec3(1.0, 1.0, 1.0);
    float surfaceAlpha = 1.0;
    float surfaceClearCoat = 0.0;
    float surfaceClearCoatRoughness = 0.0;
    float surfaceAnisotropy = 0.0;
    vec2 surfaceAnisotropyFlow = vec2(1.0, 0.0);
    float surfaceRim = 0.0;
    float surfaceRimTint = 0.0;
    vec3 surfaceBacklight = vec3_splat(0.0);
    float surfaceNormalMapDepth = 1.0;
    float surfacePremulAlphaFactor = 1.0;
    vec4 surfaceCustomFog = vec4_splat(0.0);
    float surfaceAlphaScissorThreshold = 0.0;
    float surfaceAlphaHashScale = 1.0;
    float surfaceAlphaAntialiasingEdge = 0.0;
    vec2 surfaceAlphaTextureCoordinate = vec2_splat(0.0);
    float surfaceDitherOpacity = 1.0;
    float surfaceRoughness = 1.0;
    float surfaceMetallic = 0.0;
    float surfaceOcclusion = 1.0;
    float surfaceAOLightAffect = 0.0;
    float surfaceSpecular = 0.5;
    float surfaceToonAreaType = 0.0;
    float surfaceToonRamp = 1.0;
    float surfaceSoftness = 0.0;
    vec3 surfaceEmission = vec3(0.0, 0.0, 0.0);
    #ifdef SURFACE_USES_NORMAL_MAP
        vec3 surfaceNormalMap = vec3(0.5, 0.5, 1.0);
    #endif
    vec2 surfaceUV = vTexCoord.xy;
    #ifdef SURFACE_USES_UV2
        vec2 surfaceUV2 = vSurfaceUV2;
    #else
        vec2 surfaceUV2 = vec2(0.0, 0.0);
    #endif
    #ifdef SURFACE_USES_COLOR
        vec4 surfaceColor = vColor;
    #endif
    // SURFACE_SLOT_FRAGMENT_MATERIAL_BODY
    // 与本体一致：镂空处不写运动向量，避免 TAA 在洞边拉残影。
    SurfaceAlphaScissor(surfaceAlpha, surfaceAlphaScissorThreshold);
    ToonDitherClip(surfaceDitherOpacity, gl_FragCoord.xy);
    SurfaceAdditionalCoverage(surfaceAlpha, surfaceAlphaScissorThreshold, surfaceAlphaHashScale,
        surfaceAlphaAntialiasingEdge, surfaceAlphaTextureCoordinate);

    hvec2 currNDC = vCurrClip.xy / max(vCurrClip.w, 1e-6);
    hvec2 prevNDC = vPrevClip.xy / max(vPrevClip.w, 1e-6);
    hvec2 currUV = currNDC * 0.5 + 0.5;
    hvec2 prevUV = prevNDC * 0.5 + 0.5;

    #if !BGFX_SHADER_LANGUAGE_GLSL
        currUV.y = 1.0 - currUV.y;
        prevUV.y = 1.0 - prevUV.y;
    #endif

    hvec2 motion = clamp(currUV - prevUV, hvec2_init(-0.5, -0.5), hvec2_init(0.5, 0.5));
    gl_FragColor = hvec4_init(motion.x, motion.y, 0.0, surfaceAlpha);
}
