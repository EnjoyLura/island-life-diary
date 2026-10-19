// Unified deferred reflection composition. SSR, captures and Zone supply radiance; apply EnvBRDF once.
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
#include "uniforms.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "ScreenSpace/ScreenSpaceCommon.sh"

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    gl_Position = GetClipPos(GetWorldPos(modelMatrix));
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS
SAMPLER2D(u_ReflectionNormal0, 0);
SAMPLER2D(u_ReflectionMaterial1, 1);
SAMPLER2D(u_ReflectionBaseColor2, 2);
#ifdef DEFERRED_CLEAR_COAT
SAMPLER2D(u_ReflectionCoat3, 3);
#endif
SAMPLER2D(u_ReflectionDepth4, 4);
SAMPLER2D(u_SceneLighting6, 6);
SAMPLER2D(u_ReflectionSSR7, 7);
SAMPLER2D(u_ReflectionAO8, 8);
#ifdef SSGI_COMPOSITE
SAMPLER2D(u_EnvDiffuse10, 10);
SAMPLER2D(u_ReflectionSSGI12, 12);
uniform hfloat u_SSGIIntensity;
#endif
uniform hfloat u_SSRIntensity;
#include "ScreenSpace/SSR/ReflectionEnvironment.sh"
#ifdef DEFERRED_CLEAR_COAT
#include "PBR/ClearCoatEnvironment.sh"
#endif

void PS()
{
    hvec2 uv = vTexCoord;
    hvec3 color = texture2D(u_SceneLighting6, uv).rgb;
    hvec4 material = texture2D(u_ReflectionMaterial1, uv);
    hvec4 baseColorAndAO = texture2D(u_ReflectionBaseColor2, uv);
    hvec3 baseColor = baseColorAndAO.rgb;
    uint model = uint(round(material.a * 255.0));
    hfloat depth = texture2D(u_ReflectionDepth4, uv).r;
    hvec3 diffuseColor = baseColor * (1.0 - material.r);
    if (!IsSceneFarDepth(depth, 1e-7) && GBufferHasMaterialScalars(model))
    {
        hvec3 viewPosition = ReconstructViewPos(uv, depth);
        hvec3 position = mul(hvec4_init(viewPosition, 1.0), cViewInv).xyz;
        hvec3 viewDirection = abs(u_ReflectionEnvironment.w) > 0.5 ?
            hvec3_init(0.0, 0.0, -u_ReflectionEnvironment.w) : normalize(-viewPosition);
        hvec3 view = normalize(mul(hvec4_init(viewDirection, 0.0), cViewInv).xyz);
        hvec3 normal = DecodeGBufferNormal(texture2D(u_ReflectionNormal0, uv).rgb);
        hfloat roughness = saturate(mix(material.b, cGlobalRoughness, cGlobalRoughnessOn));
        hvec3 f0 = mix(hvec3_init(0.08, 0.08, 0.08) * material.g, baseColor, material.r);
        hvec4 ssr = hvec4_init(0.0, 0.0, 0.0, 0.0);
        // Disabled SSR must not read stale or uninitialized SSRFiltered contents.
        if (u_SSRIntensity > 0.0)
            ssr = texture2D(u_ReflectionSSR7, uv) * u_SSRIntensity;
        // Toon stores its ramp in C.a; the PBR variants store material AO there.
        hfloat materialAO = (model == SHADINGMODELID_PBR_LIT || model == SHADINGMODELID_CLEAR_COAT || model == SHADINGMODELID_PBR_BACKLIGHT) ? baseColorAndAO.a : 1.0;
        hfloat ao = materialAO * texture2D(u_ReflectionAO8, uv).r;
#ifdef DEFERRED_CLEAR_COAT
        if (model == SHADINGMODELID_CLEAR_COAT)
        {
            hvec4 coat = texture2D(u_ReflectionCoat3, uv);
            hvec3 bottomNormal = DecodeClearCoatBottomNormal(coat);
            hfloat topNoV = saturate(dot(normal, view));
            hvec3 remappedDiffuse;
            hvec3 remappedSpecular = f0;
            RemapClearCoatEnvironmentColors(baseColor, material.r, roughness, topNoV, coat.r,
                remappedDiffuse, remappedSpecular);
            diffuseColor = remappedDiffuse;
            f0 = remappedSpecular;
            // UE ReflectionEnvironmentPixelShader: one SSR signal, distributed between both layers.
            hvec4 bottomSSR = ssr * (1.0 - coat.r);
            // UE's non-energy-conservation path uses the top NoV and base roughness
            // for both layers' occlusion, and mirror directions for the two gathers.
            hfloat specularOcclusion = ReflectionSpecularOcclusion(topNoV, roughness, ao);
            hvec3 bottomRay = 2.0 * dot(bottomNormal, view) * bottomNormal - view;
            hvec3 topRay = 2.0 * dot(normal, view) * normal - view;
            hvec3 bottom = ReflectionRadianceForRay(uv, abs(viewPosition.z), position, bottomRay, roughness, specularOcclusion, bottomSSR);
            hvec2 bottomAB = ReflectionBRDFTerms(roughness, topNoV);
            hvec3 bottomBRDF = f0 * bottomAB.x + saturate(50.0 * f0.g) * bottomAB.y * (1.0 - coat.r);
            hfloat topF = ReflectionBRDF(hvec3_init(0.04, 0.04, 0.04), coat.g, topNoV).x * coat.r;
            hvec3 top = ReflectionRadianceForRay(uv, abs(viewPosition.z), position, topRay, coat.g, specularOcclusion, ssr);
            color += bottom * bottomBRDF * (1.0 - topF) + top * topF;
        }
        else
#endif
        {
            hvec3 radiance = ReflectionRadiance(uv, abs(viewPosition.z), position, normal, view, roughness, ao, ssr);
            color += radiance * ReflectionBRDF(f0, roughness, saturate(dot(normal, view)));
        }
    }
#ifdef SSGI_COMPOSITE
    // Clear coat uses the same remapped diffuse color as deferred ambient lighting.
    hvec3 diffuseIndirect = texture2D(u_EnvDiffuse10, uv).rgb;
    if (model == SHADINGMODELID_PBR_LIT || model == SHADINGMODELID_CLEAR_COAT || model == SHADINGMODELID_PBR_BACKLIGHT)
    {
        hvec4 ssgi = texture2D(u_ReflectionSSGI12, uv);
        hvec3 ssgiResult = diffuseIndirect * saturate(ssgi.a) + ssgi.rgb * diffuseColor * baseColorAndAO.a;
        diffuseIndirect = max(mix(diffuseIndirect, ssgiResult, u_SSGIIntensity), hvec3_init(0.0, 0.0, 0.0));
    }
    color += diffuseIndirect;
#endif
    gl_FragColor = hvec4_init(color, 1.0);
}
#endif
