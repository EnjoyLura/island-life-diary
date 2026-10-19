// SURFACE_SLOT_FEATURE_MACROS
#include "varying_quad.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position
    $output vScreenPos
#endif
#ifdef COMPILEPS
    $input vScreenPos
#endif

#include "Common/common.sh"
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "SurfaceShaderCompatibility.sh"
#include "SurfaceGodotMatrices.sh"

// Fullscreen geometry uses identity transforms; author inputs retain the scene camera.
uniform hmat4 u_SurfaceGBufferView;
uniform hmat4 u_SurfaceGBufferInvView;
uniform hmat4 u_SurfaceGBufferProjection;
uniform hmat4 u_SurfaceGBufferInvProjection;

// SURFACE_SLOT_CUSTOM_DECLARATIONS

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    gl_Position = GetClipPos(GetWorldPos(modelMatrix));
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS
SAMPLER2D(u_SurfaceGBufferA0, 0);
SAMPLER2D(u_SurfaceGBufferB1, 1);
SAMPLER2D(u_SurfaceGBufferC2, 2);
SAMPLER2D(u_SurfaceGBufferD3, 3);
SAMPLER2D(u_SurfaceGBufferDepth4, 4);
uniform hmat4 u_SurfaceGBufferInvViewProj;

bool SurfaceGBufferFinite(float value)
{
    // Inspect the exponent so fast-math cannot fold away NaN/Infinity guards.
    return (floatBitsToUint(value) & 0x7f800000u) != 0x7f800000u;
}

bool SurfaceGBufferFinite3(vec3 value)
{
    return SurfaceGBufferFinite(value.x) && SurfaceGBufferFinite(value.y) && SurfaceGBufferFinite(value.z);
}

// User code edits material properties; the engine entry point owns MRT output.
void SurfaceGBufferFragment(inout vec3 surfaceAlbedo, inout float surfaceRoughness,
    inout float surfaceSpecular, inout float surfaceMetallic, inout vec3 surfaceNormal,
    inout vec3 surfaceEmission, vec3 surfacePosition, vec3 surfaceViewDir,
    vec2 surfaceScreenUV, uint surfaceShadingModel)
{
    // SURFACE_SLOT_FRAGMENT_MATERIAL_BODY
}

void PS()
{
    hvec2 uv = vScreenPos;
    hvec4 originalA = texture2D(u_SurfaceGBufferA0, uv);
    hvec4 originalB = texture2D(u_SurfaceGBufferB1, uv);
    hvec4 originalC = texture2D(u_SurfaceGBufferC2, uv);
    hvec4 originalD = texture2D(u_SurfaceGBufferD3, uv);
    hfloat depth = texture2D(u_SurfaceGBufferDepth4, uv).r;
    uint model = uint(floor(originalB.a * 255.0 + 0.5));
#ifdef REVERSED_Z
    bool validSurface = depth > 0.0;
#else
    bool validSurface = depth < 1.0;
#endif
    if (validSurface && IsKnownGBufferShadingModel(model))
    {
        bool hasScalars = GBufferHasMaterialScalars(model);
        bool hasColors = GBufferHasMaterialColors(model);
        vec3 albedo = hasColors ? originalC.rgb : vec3(0.0, 0.0, 0.0);
        vec3 emission = hasColors ? originalD.rgb : vec3(0.0, 0.0, 0.0);
        vec3 inputNormal = DecodeNormal(originalA.rgb);
        vec3 normal = inputNormal;
        float roughness = hasScalars ? originalB.b : 1.0;
        float specular = hasScalars ? originalB.g : 0.0;
        float metallic = hasScalars ? originalB.r : 0.0;
        vec3 worldPosition = vec3(0.0, 0.0, 0.0);
        vec3 viewDirection = vec3(0.0, 0.0, 0.0);
#ifdef SURFACE_GBUFFER_WORLD_POSITION
        // Same hardware-depth and clip-space convention as the deferred motion-vector path.
        hvec4 clipPosition = hvec4_init(uv.x * 2.0 - 1.0, uv.y * 2.0 - 1.0, depth, 1.0);
#if BGFX_SHADER_LANGUAGE_GLSL || BGFX_SHADER_LANGUAGE_GLSL_HLSLCC
        clipPosition.z = depth * 2.0 - 1.0;
#else
        clipPosition.y = -clipPosition.y;
#endif
        hvec4 position = mul(clipPosition, u_SurfaceGBufferInvViewProj);
        worldPosition = position.xyz / position.w;
        viewDirection = normalize(cCameraPositionWorld - worldPosition);
#endif
        SurfaceGBufferFragment(albedo, roughness, specular, metallic, normal, emission,
            worldPosition, viewDirection, uv, model);

        // Patch only changed, supported properties. Preserve all auxiliary channels verbatim.
#ifdef SURFACE_GBUFFER_WRITE_NORMAL
        hfloat lengthSquared = dot(normal, normal);
        if (any(notEqual(normal, inputNormal)) && SurfaceGBufferFinite3(normal) &&
            SurfaceGBufferFinite(lengthSquared) && lengthSquared > 1e-12)
            originalA.rgb = EncodeNormal(normal * inversesqrt(lengthSquared));
#endif
#ifdef SURFACE_GBUFFER_WRITE_METALLIC
        if (hasScalars && metallic != originalB.r && SurfaceGBufferFinite(metallic))
            originalB.r = clamp(metallic, 0.0, 1.0);
#endif
#ifdef SURFACE_GBUFFER_WRITE_SPECULAR
        if (hasScalars && specular != originalB.g && SurfaceGBufferFinite(specular))
            originalB.g = clamp(specular, 0.0, 1.0);
#endif
#ifdef SURFACE_GBUFFER_WRITE_ROUGHNESS
        if (hasScalars && roughness != originalB.b && SurfaceGBufferFinite(roughness))
            originalB.b = clamp(roughness, 0.0, 1.0);
#endif
#ifdef SURFACE_GBUFFER_WRITE_ALBEDO
        if (hasColors && any(notEqual(albedo, originalC.rgb)) && SurfaceGBufferFinite3(albedo))
            originalC.rgb = clamp(albedo, 0.0, 1.0);
#endif
#ifdef SURFACE_GBUFFER_WRITE_EMISSION
        if (hasColors && any(notEqual(emission, originalD.rgb)) && SurfaceGBufferFinite3(emission))
            originalD.rgb = clamp(emission, -65504.0, 65504.0);
#endif
    }
#ifdef SURFACE_GBUFFER_OUTPUT_0
    gl_FragData[SURFACE_GBUFFER_OUTPUT_0] = originalA;
#endif
#ifdef SURFACE_GBUFFER_OUTPUT_1
    gl_FragData[SURFACE_GBUFFER_OUTPUT_1] = originalB;
#endif
#ifdef SURFACE_GBUFFER_OUTPUT_2
    gl_FragData[SURFACE_GBUFFER_OUTPUT_2] = originalC;
#endif
#ifdef SURFACE_GBUFFER_OUTPUT_3
    gl_FragData[SURFACE_GBUFFER_OUTPUT_3] = originalD;
#endif
}
#endif
