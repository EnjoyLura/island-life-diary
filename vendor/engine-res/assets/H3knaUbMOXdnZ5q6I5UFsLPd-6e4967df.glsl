#include "varying_deferred.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
$input a_position
$output vTexCoord, vScreenPos, vFarRay _VNEARRAY
#endif
#ifdef COMPILEPS
$input vTexCoord, vScreenPos, vFarRay _VNEARRAY
#endif

#ifndef DEFERRED
#define DEFERRED
#endif
#include "Common/common.sh"
// Direct lights accumulate into the emissive color already written by the material pass.
#undef AMBIENT
#define SPLIT_LIGHTING
#define DEFERRED_REFLECTIONS
#define MOBILE_GBUFFER_INPUTS
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "lighting.sh"
#include "constants.sh"
#include "ScreenSpace/ScreenSpaceCommon.sh"
#include "PBR/MobileGBuffer.sh"
#ifdef COMPILEPS
#include "PBR/StandardPBR.sh"
#ifndef MOBILE_DEPTH_AUX
SAMPLER2D_PRECISION(u_MobileDepth0, 0, highp);
#endif
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
    hfloat inverseW = 1.0;
#ifndef DIRLIGHT
    inverseW = 1.0 / max(vScreenPos.w, 0.0001);
#endif
    hvec2 uv = vScreenPos.xy * inverseW;
#ifdef MOBILE_DEPTH_AUX
    hfloat deviceDepth = READ_INPUT_ATTACHMENT(3).r;
#else
    hfloat deviceDepth = texture2D(u_MobileDepth0, uv).r;
#endif
    MobileGBuffer material = FetchMobileGBuffer();
    if (IsSceneFarDepth(deviceDepth, 1e-7) || material.model != SHADINGMODELID_PBR_LIT)
    {
        gl_FragColor = vec4_splat(0.0);
        return;
    }
    hfloat depth = ReconstructDepth(deviceDepth);
#ifdef ORTHO
    hvec3 relativePosition = mix(vNearRay, vFarRay, depth) * inverseW;
#else
    hvec3 relativePosition = vFarRay * depth * inverseW;
#endif
    hvec3 worldPosition = relativePosition + cCameraPosPS;
#ifdef ORTHO
    vec3 viewDirection = normalize(vNearRay - vFarRay);
#else
    vec3 viewDirection = normalize(-relativePosition);
#endif
    float shadow = 1.0;
#ifdef SHADOW
    shadow = GetShadowDeferred(hvec4_init(worldPosition, 1.0), material.normal, depth);
#endif
    vec3 direct, unusedSpecular, unusedDiffuse;
    MetallicPBR_Split(material.baseColor, material.metallic, material.specular, material.roughness,
        worldPosition, material.normal, viewDirection, vec3_splat(shadow), 1.0
#ifdef DEFERRED_CLUSTER
        , depth * cFarClipPS
#endif
        , direct, unusedSpecular, unusedDiffuse);
    gl_FragColor = vec4(direct, 0.0);
}
