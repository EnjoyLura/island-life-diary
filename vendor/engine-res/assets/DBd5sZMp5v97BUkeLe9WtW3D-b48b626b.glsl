// SURFACE_SLOT_FEATURE_MACROS
#ifdef SURFACE_VELOCITY_ONLY
#define VELOCITY_PASS
#endif

// Unlit lighting ignores normal maps, but material baking exports their value.
#if defined(MATERIALBAKE) && defined(SURFACE_USES_NORMAL_MAP)
    #ifndef SURFACE_USES_FRAGMENT_NORMAL
        #define SURFACE_USES_FRAGMENT_NORMAL
    #endif
    #ifndef SURFACE_USES_FRAGMENT_TANGENT
        #define SURFACE_USES_FRAGMENT_TANGENT
    #endif
#endif

#ifdef SURFACE_GENERIC_OUTLINE
    #define INSTANCED_STROKE_PARAMS
#endif
#include "varying_surface_unlit.def.sc"
#include "urho3d_compatibility.sh"
#include "SurfaceShaderCompatibility.sh"
#ifdef COMPILEVS
    #ifdef SURFACE_GENERIC_OUTLINE
        $input a_position, a_color0 _NORMAL _TEXCOORD0 _TEXCOORD1 _ATANGENT _SKINNED _INSTANCED _INSTANCED_EXTRA1 _INSTANCED_EXTRA2 _INSTANCED_EXTRA3
    #else
        $input a_position _NORMAL _TEXCOORD0 _COLOR0 _TEXCOORD1 _ATANGENT _SKINNED _INSTANCED _INSTANCED_EXTRA1 _INSTANCED_EXTRA2 _INSTANCED_EXTRA3
    #endif
    #ifdef SURFACE_GENERIC_OUTLINE
        $output vTexCoord _VTANGENT _VSURFACENORMAL, vWorldPos _VCOLOR _VOUTLINECOLOR, vOutlineParams _VSCREENPOS /* SURFACE_SLOT_VARYING_LIST */
    #else
        $output vTexCoord _VTANGENT _VSURFACENORMAL, vWorldPos _VCOLOR _VSCREENPOS /* SURFACE_SLOT_VARYING_LIST */
    #endif
#endif
#ifdef COMPILEPS
    #ifdef SURFACE_GENERIC_OUTLINE
        $input vTexCoord _VTANGENT _VSURFACENORMAL, vWorldPos _VCOLOR _VOUTLINECOLOR, vOutlineParams _VSCREENPOS /* SURFACE_SLOT_VARYING_LIST */
    #else
        $input vTexCoord _VTANGENT _VSURFACENORMAL, vWorldPos _VCOLOR _VSCREENPOS /* SURFACE_SLOT_VARYING_LIST */
    #endif
#endif

#include "Common/common.sh"
#include "PBR/MaterialEnvironment.sh"

#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "SurfaceGodotMatrices.sh"
#include "SurfaceCoverage.sh"
#ifdef SURFACE_GENERIC_OUTLINE
    #include "SurfaceOutline.sh"
#endif
#include "screen_pos.sh"
#include "fog.sh"
#if COMPILEPS
    #include "SurfaceAlphaScissor.sh"
#endif

// SURFACE_SLOT_CUSTOM_DECLARATIONS
// Generated declarations use UrhoX-side names only. Godot-style built-ins are
// lowered before insertion, e.g. ALBEDO -> surfaceAlbedo and UV -> surfaceUV.

#if COMPILEPS
    hfloat SurfaceGodotRawDepthFromLinear(hfloat linearDepth)
    {
        return DelinearizeDepth(max(linearDepth, 0.0001), cNearClipPS, cFarClipPS);
    }
#endif

#if COMPILEPS && defined(SURFACE_USES_GODOT_PROJECTION)
    hfloat SurfaceGodotLinearDepth(hfloat rawDepth)
    {
        return LinearizeDepth(rawDepth, cNearClipPS, cFarClipPS);
    }

    hvec4 SurfaceGodotInvProjectionMul(hvec4 ndc)
    {
        hvec4 clipPos = ndc;
        #if BGFX_SHADER_LANGUAGE_GLSL
            clipPos.z = clipPos.z * 2.0 - 1.0;
        #else
            clipPos.y = -clipPos.y;
        #endif
        hvec4 viewPos = mul(clipPos, cInvProj);
        hfloat linearDepth = SurfaceGodotLinearDepth(ndc.z);
        hfloat depthScale = linearDepth / max(abs(viewPos.z), 0.0001);
        viewPos.xyz *= depthScale;
        viewPos.z = -linearDepth;
        viewPos.w = 1.0;
        return viewPos;
    }

#endif

void VS()
{
    // SURFACE_SLOT_VERTEX_MOTION_BODY
    hfloat surfaceZClipScale = 1.0;
    hvec4 surfaceClipPosition = hvec4_init(1.0, 1.0, 1.0, 1.0);
    #ifdef NOUV
        vec2 iTexCoord = vec2(0.0, 0.0);
    #endif
    hmat4 modelMatrix = iModelMatrix;
    #ifdef SURFACE_USES_ALPHA_HASH
        hmat4 surfaceCoverageModel = modelMatrix;
    #endif
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
    #ifdef SURFACE_USES_TANGENT
        hvec4 surfaceVertexTangent = iTangent;
    #else
        hvec4 surfaceVertexTangent = hvec4_init(1.0, 0.0, 0.0, 1.0);
    #endif
    #ifndef SURFACE_WORLD_VERTEX_COORDS
        hvec3 surfacePosition = surfaceVertexPos.xyz;
        vec3 surfaceNormal = surfaceVertexNormal;
        vec3 surfaceTangent = surfaceVertexTangent.xyz;
        vec3 surfaceBinormal = cross(surfaceTangent, surfaceNormal) * surfaceVertexTangent.w;
        vec2 surfaceUV = GetTexCoord(iTexCoord);
        vec2 surfaceUV2 = SurfaceGetUV2();
        DECLARE_SURFACE_COLOR_INPUTS
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
    hvec3 worldPos = GetWorldPos(modelMatrix);

    #ifdef SURFACE_WORLD_VERTEX_COORDS
        hvec3 surfacePosition = worldPos;
        vec3 surfaceNormal = GetWorldNormal(modelMatrix);
        #ifdef SURFACE_USES_TANGENT
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
        worldPos = surfacePosition;
        surfaceVertexNormal = surfaceNormal;
        surfaceWorldTangent.xyz = surfaceTangent;
    #endif

    #ifdef SURFACE_USES_FRAGMENT_NORMAL
        #ifdef SURFACE_WORLD_VERTEX_COORDS
            vNormal = normalize(surfaceNormal);
        #else
            vNormal = GetWorldNormal(modelMatrix);
        #endif
        vNormal *= cNormalOddNegativeScale;
    #endif

    #ifdef SURFACE_USES_FRAGMENT_TANGENT
        #ifdef SURFACE_WORLD_VERTEX_COORDS
            vec4 tangent = surfaceWorldTangent;
            tangent.xyz = normalize(tangent.xyz);
        #else
            vec4 tangent = GetWorldTangent(modelMatrix);
        #endif
        vec3 bitangent = cross(tangent.xyz, vNormal) * tangent.w * cBitangentOddNegativeScale;
        vTexCoord = vec4(GetTexCoord(iTexCoord), bitangent.xy);
        vTangent = vec4(tangent.xyz, bitangent.z);
    #else
        #ifndef NOUV
            vTexCoord.xy = GetTexCoord(iTexCoord);
        #endif
    #endif

    #ifdef SURFACE_GENERIC_OUTLINE
        // world_vertex_coords: vertex() already left a world-space normal in surfaceVertexNormal.
        #ifdef SURFACE_WORLD_VERTEX_COORDS
            hvec3 worldNormal = normalize(surfaceVertexNormal) * cNormalOddNegativeScale;
        #else
            hvec3 worldNormal = GetWorldNormal(modelMatrix) * cNormalOddNegativeScale;
        #endif
        hvec4 surfaceOutlineBodyClip = GetClipPos(worldPos);
        worldPos = ExpandSurfaceOutline(worldPos, worldNormal, modelMatrix);
        surfaceClipPosition = SurfaceOutlineClipPosition(surfaceClipPosition, surfaceOutlineBodyClip, GetClipPos(worldPos));
    #endif

    #ifdef SURFACE_USES_ALPHA_HASH
        vSurfaceHashPosition = SurfaceCoverageObjectPosition(worldPos, surfaceCoverageModel);
    #endif
    #ifdef SURFACE_VELOCITY_ONLY
        SurfaceCoverageVelocity(surfaceCurrentClip, surfacePreviousClip);
    #endif
    gl_Position = SurfaceApplyZClipScale(SurfaceSelectClipPosition(GetClipPos(worldPos), surfaceClipPosition), surfaceZClipScale);
    #ifdef SURFACE_GENERIC_OUTLINE
        gl_Position.z += SurfaceOutlineZBias(gl_Position);
    #endif
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));
    #ifdef SURFACE_USES_SCREENPOS
        vScreenPos = GetScreenPos(gl_Position);
    #endif

    #ifdef SURFACE_USES_COLOR
        vColor = surfaceColor;
    #elif defined(VERTEXCOLOR)
        vColor = iColor;
    #endif
    #ifdef SURFACE_GENERIC_OUTLINE
        hvec4 outlineColor = GetSurfaceOutlineColor();
        vOutlineColor = vec4(outlineColor.rgb, 1.0);
        vOutlineParams = vec2(outlineColor.a, iSurfaceOutlineBrightness);
    #endif

    #undef iPos
    #undef iNormal
    #undef iTangent
    #define iPos a_position
    #define iNormal a_normal
    #define iTangent a_tangent
}

void PS()
{
    // Surface material defaults. Generated fragment code owns all texture sampling and material output mapping.
    // Godot-style material outputs are lowered to UrhoX-side surface* variables
    // before this slot is inserted.
    vec3 surfaceAlbedo = vec3(1.0, 1.0, 1.0);
    float surfaceAlpha = 1.0;
    #ifdef SURFACE_USES_DEPTH
        float surfaceDepth = gl_FragCoord.z;
    #endif
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
    vec3 surfaceEmission = vec3(0.0, 0.0, 0.0);
    float surfaceRoughness = 1.0;
    float surfaceMetallic = 0.0;
    float surfaceOcclusion = 1.0;
    float surfaceAOLightAffect = 0.0;
    float surfaceSpecular = 0.5;
    #ifdef SURFACE_USES_FRAGMENT_NORMAL
        vec3 surfaceNormal = normalize(vNormal);
    #else
        vec3 surfaceNormal = vec3(0.0, 0.0, 1.0);
    #endif
    #ifdef SURFACE_USES_FRAGMENT_TANGENT
        vec3 surfaceTangent = SurfaceNormalizeOrZero(vTangent.xyz);
        vec3 surfaceBinormal = SurfaceNormalizeOrZero(vec3(vTexCoord.zw, vTangent.w));
    #endif
    vec2 surfaceUV = vTexCoord.xy;
    #ifdef SURFACE_USES_UV2
        vec2 surfaceUV2 = vSurfaceUV2;
    #else
        vec2 surfaceUV2 = vec2(0.0, 0.0);
    #endif
    #ifdef SURFACE_USES_SCREENPOS
        hvec2 surfaceScreenUV = vScreenPos.xy / vScreenPos.w;
        hvec4 surfaceFragCoord = hvec4_init(0.0, 0.0, 0.0, 0.0);
        surfaceFragCoord.xy = gl_FragCoord.xy;
        surfaceFragCoord.z = gl_FragCoord.z;
        surfaceFragCoord.w = 1.0 / max(vScreenPos.w, 0.0001);
    #endif
    hvec2 surfaceViewportSize = hvec2_init(1.0, 1.0) / cGBufferInvSize;
    hmat4 surfaceGodotInvProjectionMatrix = cInvProj;
    #ifdef SURFACE_USES_FRAGMENT_MODEL_MATRIX
        hmat4 modelMatrix = cModel;
    #endif
    #ifdef SURFACE_USES_COLOR
        vec4 surfaceColor = vColor;
    #endif
    hvec3 surfacePosition = vWorldPos.xyz;
    hvec3 surfaceViewDir = normalize(cCameraPosPS - surfacePosition);
    #ifdef SURFACE_USES_LIGHT_VERTEX
        // LIGHT_VERTEX keeps the native view-space contract; fragment VERTEX remains world-space.
        hvec3 surfaceLightVertex = mul(hvec4_init(surfacePosition, 1.0), cView).xyz;
    #endif
    #ifdef SURFACE_USES_NORMAL_MAP
        vec3 surfaceNormalMap = vec3(0.5, 0.5, 1.0);
    #endif
    // SURFACE_SLOT_FRAGMENT_MATERIAL_BODY
    SurfaceAlphaScissor(surfaceAlpha, surfaceAlphaScissorThreshold);
    SurfaceAdditionalCoverage(surfaceAlpha, surfaceAlphaScissorThreshold, surfaceAlphaHashScale,
        surfaceAlphaAntialiasingEdge, surfaceAlphaTextureCoordinate);
    #ifdef SURFACE_VELOCITY_ONLY
        gl_FragColor = vec4(SurfaceCoverageMotion(), 0.0, surfaceAlpha);
        return;
    #endif
    #ifdef SURFACE_DEPTH_ONLY
        #ifdef SURFACE_WRITES_DEPTH
            gl_FragDepth = surfaceDepth;
        #endif
        gl_FragColor = vec4(1.0, 1.0, 1.0, surfaceAlpha);
        return;
    #endif

    #ifdef SURFACE_GENERIC_OUTLINE
        vec3 finalColor = MixSurfaceOutlineColor(surfaceAlbedo, vOutlineColor.rgb, vOutlineParams.x, vOutlineParams.y);
    #else
        vec3 finalColor = surfaceAlbedo + surfaceEmission;
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(distance(vWorldPos.xyz, cCameraPosPS), __GET_HEIGHT__(vWorldPos));
    #else
        float fogFactor = GetFogFactor(distance(vWorldPos.xyz, cCameraPosPS));
    #endif

    #if defined(MATERIALBAKE)
        #if defined(SURFACE_USES_NORMAL_MAP) && defined(SURFACE_USES_FRAGMENT_TANGENT)
            surfaceNormal = SurfaceApplyNormalMap(surfaceNormalMap, surfaceNormalMapDepth, SURFACE_NORMAL_MAP_BASIS);
        #elif !defined(SURFACE_USES_FRAGMENT_NORMAL)
            surfaceNormal = GBufferFaceNormal(vWorldPos.xyz, cCameraPosPS);
        #endif
        EncodeGBufferBake(surfaceAlbedo, surfaceAlpha, surfaceRoughness, surfaceMetallic, surfaceOcclusion, surfaceNormal, surfaceEmission);
    #elif defined(DEFERRED)
        // Unlit passthrough encode (shadingModelID=0, resolve outputs RT3 color as-is).
        // No fog and no gamma here: the deferred pipeline is linear HDR and the SceneFog
        // quad applies fog uniformly to all opaque pixels
        EncodeGBufferUnlit(finalColor, GBufferFaceNormal(vWorldPos.xyz, cCameraPosPS));
    #else
        gl_FragColor = vec4(GetMaterialFog(finalColor, fogFactor, surfaceCustomFog, SURFACE_FOG_ADDITIVE), surfaceAlpha);
        #ifdef SURFACE_PREMULTIPLIED_ALPHA
            gl_FragColor.rgb *= surfacePremulAlphaFactor;
        #endif

        #if defined(GAMMA_IN_SHADERING) || defined(USEGAMMA)
            gl_FragColor.rgb = LinearToGammaSpace(toAcesFilmic(gl_FragColor.rgb));
        #endif
    #endif
    // Commit after all raster-coordinate reads and coverage tests (DX SV_Depth aliases input storage).
    #if defined(SURFACE_WRITES_DEPTH) && !defined(SURFACE_SHADOW_ONLY) && !defined(MATERIALBAKE)
        gl_FragDepth = surfaceDepth;
    #endif
}
