#ifndef MOBILE_GBUFFER_SH
#define MOBILE_GBUFFER_SH

// UE mobile layout: octahedral world normal, material scalars/model, and an sRGB base-color attachment.
// Scene color is separate so emissive never needs an external-memory GBuffer.
hvec2 MobileEncodeNormal(hvec3 normal)
{
    normal /= max(abs(normal.x) + abs(normal.y) + abs(normal.z), 1e-8);
    if (normal.z < 0.0)
        normal.xy = (1.0 - abs(normal.yx)) * hvec2_init(normal.x >= 0.0 ? 1.0 : -1.0, normal.y >= 0.0 ? 1.0 : -1.0);
    return normal.xy * 0.5 + 0.5;
}

hvec3 MobileDecodeNormal(hvec2 encoded)
{
    hvec2 oct = encoded * 2.0 - 1.0;
    hvec3 normal = hvec3_init(oct, 1.0 - abs(oct.x) - abs(oct.y));
    hfloat fold = saturate(-normal.z);
    normal.xy += hvec2_init(normal.x >= 0.0 ? -fold : fold, normal.y >= 0.0 ? -fold : fold);
    return normalize(normal);
}

// The framebuffer converts linear BaseColor to sRGB on write and back to linear on attachment read.
// Normal B/A carry DDA visibility/source; base-color alpha carries material AO independently.
#ifdef MOBILE_DEPTH_AUX
#define WRITE_MOBILE_DEPTH(value) gl_FragData[4] = hvec4_init(value, 0.0, 0.0, 0.0)
#else
#define WRITE_MOBILE_DEPTH(value)
#endif
#define EncodeMobileGBuffer(baseColor, metallic, specular, roughness, normal, emission, model, materialAO) \
    { \
        gl_FragData[0] = vec4(emission, 1.0); \
        gl_FragData[1] = vec4(MobileEncodeNormal(normal), 1.0, 0.0); \
        gl_FragData[2] = vec4(saturate(metallic), saturate(specular), saturate(roughness), float(model) / 255.0); \
        gl_FragData[3] = vec4(saturate(baseColor), saturate(materialAO)); \
        WRITE_MOBILE_DEPTH(gl_FragCoord.z); \
    }

struct MobileGBuffer
{
    hvec3 normal;
    vec3 baseColor;
    float metallic;
    float specular;
    float roughness;
    uint model;
    float materialAO;
    float localAO;
    bool isDDA;
};

MobileGBuffer DecodeMobileGBuffer(hvec4 normal, hvec4 material, hvec4 color)
{
    MobileGBuffer result;
    result.normal = MobileDecodeNormal(normal.rg);
    result.baseColor = color.rgb;
    result.materialAO = color.a;
    result.metallic = material.r;
    result.specular = material.g;
    result.roughness = material.b;
    result.model = uint(round(material.a * 255.0));
    result.localAO = normal.b;
    result.isDDA = normal.a > 0.5;
    return result;
}

#if defined(COMPILEPS) && defined(MOBILE_GBUFFER_INPUTS)
#include "Common/AttachmentFetch.sh"
DECLARE_INPUT_ATTACHMENT(0, 1)
DECLARE_INPUT_ATTACHMENT(1, 2)
DECLARE_INPUT_ATTACHMENT(2, 3)
#ifdef MOBILE_DEPTH_AUX
// Preserve R32F device-depth precision through framebuffer fetch.
DECLARE_INPUT_ATTACHMENT(3, 4)
#endif

MobileGBuffer FetchMobileGBuffer()
{
    return DecodeMobileGBuffer(READ_INPUT_ATTACHMENT(0), READ_INPUT_ATTACHMENT(1), READ_INPUT_ATTACHMENT(2));
}
#endif

#endif
