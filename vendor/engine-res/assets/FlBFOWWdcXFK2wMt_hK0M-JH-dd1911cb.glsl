#include "varying_quad.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
$input a_position
$output vTexCoord, vScreenPos
#endif
#ifdef COMPILEPS
$input vTexCoord, vScreenPos
#endif
#ifdef REFLECTION_PROBES
#define CUBEARRAY
#endif
#include "Common/common.sh"
#ifndef DEFERRED
#define DEFERRED
#endif
#define DEFERRED_REFLECTIONS
#define ENVCUBE
#define MOBILE_GBUFFER_INPUTS
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "ScreenSpace/ScreenSpaceCommon.sh"
#include "PBR/MobileGBuffer.sh"

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    gl_Position = GetClipPos(GetWorldPos(modelMatrix));
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS
#ifndef MOBILE_DEPTH_AUX
SAMPLER2D_PRECISION(u_MobileDepth0, 0, highp);
#endif
SAMPLER2D(u_MobileAO1, 1);
#include "constants.sh"
// Use the shared .sh entry: Shader::ProcessSource skips top-level .glsl includes.
#include "PBR/SimpleBRDF.sh"
#include "PBR/GI.sh"
#include "ScreenSpace/SSR/ReflectionEnvironment.sh"
#ifdef MOBILE_SSR
#include "ScreenSpace/SSR/MobileSSR.sh"
#endif

void PS()
{
    hvec2 uv = vTexCoord;
#ifdef MOBILE_DEPTH_AUX
    hfloat depth = READ_INPUT_ATTACHMENT(3).r;
#else
    hfloat depth = texture2D(u_MobileDepth0, uv).r;
#endif
    MobileGBuffer material = FetchMobileGBuffer();
    if (IsSceneFarDepth(depth, 1e-7) || material.model != SHADINGMODELID_PBR_LIT)
    {
        gl_FragColor = vec4_splat(0.0);
        return;
    }
    hvec3 viewPosition = ReconstructViewPos(uv, depth);
    hvec3 worldPosition = mul(hvec4_init(viewPosition, 1.0), cViewInv).xyz;
    hvec3 viewDirection = abs(u_ReflectionEnvironment.w) > 0.5 ?
        hvec3_init(0.0, 0.0, -u_ReflectionEnvironment.w) : normalize(-viewPosition);
    hvec3 view = normalize(mul(hvec4_init(viewDirection, 0.0), cViewInv).xyz);
    hfloat roughness = saturate(mix(material.roughness, cGlobalRoughness, cGlobalRoughnessOn));
    hfloat ao = material.materialAO * (material.isDDA ? material.localAO : texture2D(u_MobileAO1, uv).r);
    hvec3 diffuseColor = material.baseColor * (1.0 - material.metallic);
    hvec3 f0 = mix(hvec3_init(0.08, 0.08, 0.08) * material.specular, material.baseColor, material.metallic);
    hfloat noV = saturate(dot(material.normal, view));
    hfloat a = roughness * roughness;
    hvec3 reflected = 2.0 * dot(material.normal, view) * material.normal - view;
    hvec3 ray = mix(material.normal, reflected, (1.0 - a) * (sqrt(1.0 - a) + a));
    hvec4 ssr = hvec4_init(0.0, 0.0, 0.0, 0.0);
#ifdef MOBILE_SSR
    ssr = MobileSSR(uv, viewPosition, ray, roughness);
#endif
    hvec3 radiance = ReflectionRadianceForRay(uv, abs(viewPosition.z), worldPosition, ray, roughness,
        ReflectionSpecularOcclusion(noV, roughness, ao), ssr);
    hvec3 color = GI_IndirectDiffuse(material.normal, ao) * diffuseColor;
    color += radiance * ReflectionBRDF(f0, roughness, saturate(dot(material.normal, view)));
    gl_FragColor = hvec4_init(color, 0.0);
}
#endif
