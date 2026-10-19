#ifndef CLUSTER_UTIL_SH_HEADER_GUARD
#define CLUSTER_UTIL_SH_HEADER_GUARD

#include <Common/bgfx_shader.sh>

// from screen coordinates (gl_FragCoord) to eye space
// 注意这里之前是屏幕空间，现在改成了viewport空间
vec4 screen2Eye(vec4 coord)
{
#if BGFX_SHADER_LANGUAGE_GLSL
    // https://www.khronos.org/opengl/wiki/Compute_eye_space_from_window_space
//    vec3 ndc = vec3(
//        2.0 * (coord.x - u_viewRect.x) / u_viewRect.z - 1.0,
//        2.0 * (coord.y - u_viewRect.y) / u_viewRect.w - 1.0,
//        2.0 * coord.z - 1.0 // -> [-1, 1]
//    );

    vec3 ndc = vec3(
        2.0 * (coord.x - 0.0) / u_viewRect.z - 1.0,
        2.0 * (coord.y - 0.0) / u_viewRect.w - 1.0,
        2.0 * coord.z - 1.0 // -> [-1, 1]
    );
#else
//    vec3 ndc = vec3(
//        2.0 * (coord.x - u_viewRect.x) / u_viewRect.z - 1.0,
//        2.0 * (u_viewRect.w - coord.y - 1 - u_viewRect.y) / u_viewRect.w - 1.0, // y is flipped
//        coord.z // -> [0, 1]
//    );
    vec3 ndc = vec3(
        2.0 * (coord.x - 0.0) / u_viewRect.z - 1.0,
        2.0 * (u_viewRect.w - coord.y - 1 - 0.0) / u_viewRect.w - 1.0, // y is flipped
        coord.z // -> [0, 1]
    );
#endif

    // https://stackoverflow.com/a/16597492/862300
    // 注意行列矩阵，sample和我们相反
    vec4 eye = mul(vec4(ndc, 1.0), u_invProj);
    eye = eye / eye.w;

    return eye;
}

// Reconstruct positive perspective eye depth from [0, 1] hardware depth.
// depthReconstruct contains the CPU-provided offset and numerator for either Z convention.
hfloat screen2EyeDepth(hfloat depth, hvec2 depthReconstruct)
{
    return depthReconstruct.y / (depth - depthReconstruct.x);
}

// convert normal from tangent space to space of normal_ref and tangent_ref
vec3 convertTangentNormal(vec3 normal_ref, vec3 tangent_ref, vec3 normal)
{
    vec3 bitangent = cross(normal_ref, tangent_ref);
    mat3 TBN = mtxFromCols(
        normalize(tangent_ref),
        normalize(bitangent),
        normalize(normal_ref)
    );
    return normalize(mul(TBN, normal));
}

// compress viewspace normal into two components
// spheremap transform used by Cry Engine 3
// https://aras-p.info/texts/CompactNormalStorage.html#method04spheremap
// must be viewspace so we can hide z-pole
// both (0,0,1) and (0,0,-1) have the same encoding
// the original implementation always decoded to (0,0,1)
// changed it to return normals pointing towards the camera for
// a left-handed coordinate system

vec2 packNormal(vec3 normal)
{
    float f = sqrt(8.0 * -normal.z + 8.0);
    return normal.xy / f + 0.5;
}

vec3 unpackNormal(vec2 encoded)
{
    vec2 fenc = encoded * 4.0 - 2.0;
    float f = dot(fenc, fenc);
    float g = sqrt(1.0 - f * 0.25);
    return vec3(fenc * g, -(1.0 - f * 0.5));
}

#endif // UTIL_SH_HEADER_GUARD
