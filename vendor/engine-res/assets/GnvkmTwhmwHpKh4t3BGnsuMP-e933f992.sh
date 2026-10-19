#ifndef LOCAL_LIGHT_SHADOWS_SH
#define LOCAL_LIGHT_SHADOWS_SH

#if defined(CLUSTER_LOCAL_SHADOWS) && defined(COMPILEPS)
// Evaluate derivatives before entering the per-light loop or any shadow-dependent branch.
hvec3 GetClusterShadowNormal(hvec3 position, hvec3 shadingNormal)
{
    hvec3 geometricNormal = cross(dFdx(position), dFdy(position));
    hfloat lengthSquared = dot(geometricNormal, geometricNormal);
    if (lengthSquared > 0.00000001)
    {
        geometricNormal *= inversesqrt(lengthSquared);
        return dot(geometricNormal, shadingNormal) < 0.0 ? -geometricNormal : geometricNormal;
    }
    return shadingNormal;
}
#endif

#if defined(CLUSTER_LOCAL_SHADOWS) && (defined(COMPILEPS) || defined(COMPILECS))
// FP32 records: three vectors per light, seven vectors per face. Offsets are numeric floats.
BUFFER_RO(b_ClusterShadowData, hvec4, 11);
SAMPLER2DARRAYSHADOW(u_ClusterShadowAtlas, 12);
#define sLocalShadowAtlas u_ClusterShadowAtlas

hvec4 LocalShadowProject(uint face, hvec3 position)
{
    hvec4 p = hvec4_init(position, 1.0);
    return hvec4_init(dot(b_ClusterShadowData[face], p), dot(b_ClusterShadowData[face + 1u], p),
                dot(b_ClusterShadowData[face + 2u], p), dot(b_ClusterShadowData[face + 3u], p));
}

hvec2 LocalShadowClipToUV(hvec2 xy)
{
#if BGFX_SHADER_LANGUAGE_GLSL
    return xy * 0.5 + 0.5;
#else
    return xy * hvec2_init(0.5, -0.5) + 0.5;
#endif
}

uint LocalShadowCubeFace(hvec3 direction)
{
    hvec3 a = abs(direction);
    if (a.x >= a.y && a.x >= a.z)
        return direction.x >= 0.0 ? 0u : 1u;
    if (a.y >= a.z)
        return direction.y >= 0.0 ? 2u : 3u;
    return direction.z >= 0.0 ? 4u : 5u;
}

hvec3 LocalShadowCubeDirection(uint face, hvec2 uv)
{
    hvec2 xy = uv * 2.0 - 1.0;
#if !BGFX_SHADER_LANGUAGE_GLSL
    xy.y = -xy.y;
#endif
    if (face == 0u) return hvec3_init(1.0, xy.y, -xy.x);
    if (face == 1u) return hvec3_init(-1.0, xy.y, xy.x);
    if (face == 2u) return hvec3_init(xy.x, 1.0, -xy.y);
    if (face == 3u) return hvec3_init(xy.x, -1.0, xy.y);
    if (face == 4u) return hvec3_init(xy.x, xy.y, 1.0);
    return hvec3_init(-xy.x, xy.y, -1.0);
}

hfloat LocalShadowTap(uint firstFace, uint faceIndex, hvec2 tapUV, hfloat depth, bool cubeShadow,
                     hvec3 lightPosition, hfloat lightDistance, hfloat receiverBias)
{
    uint face = firstFace + faceIndex * 7u;
    // Point and rect taps crossing a cube edge use the adjacent face's projection and comparison depth.
    if (cubeShadow && (any(lessThan(tapUV, hvec2_splat(0.0))) || any(greaterThan(tapUV, hvec2_splat(1.0)))))
    {
        hvec3 direction = normalize(LocalShadowCubeDirection(faceIndex, tapUV));
        faceIndex = LocalShadowCubeFace(direction);
        face = firstFace + faceIndex * 7u;
        hvec4 projected = LocalShadowProject(face, lightPosition + direction * lightDistance);
        tapUV = LocalShadowClipToUV(projected.xy / projected.w);
        depth = projected.z / projected.w;
    }
    hvec4 atlas = b_ClusterShadowData[face + 4u];
    hvec4 bounds = b_ClusterShadowData[face + 5u];
    hvec2 uv = clamp(tapUV * atlas.xy + atlas.zw, bounds.xy, bounds.zw);
    hfloat layer = b_ClusterShadowData[face + 6u].w;
    return shadow2DArray(sLocalShadowAtlas, hvec4_init(uv, layer, depth - receiverBias));
}

hfloat SampleClusterLocalShadow(hfloat shadowIndex, hvec3 position, hvec3 normal)
{
    if (shadowIndex < 0.0)
        return 1.0;
    uint record = uint(shadowIndex + 0.5);
    hvec4 meta = b_ClusterShadowData[record];
    hvec4 light = b_ClusterShadowData[record + 1u];
    hvec4 quality = b_ClusterShadowData[record + 2u];
    hvec3 worldPos = position + normal * quality.x;
    hvec3 direction = worldPos - light.xyz;
    hfloat distance = sqrt(dot(direction, direction));
    if (distance >= light.w || distance < 0.00001)
        return 1.0;
    bool cubeShadow = meta.z > 0.5;
    uint firstFace = uint(meta.x + 0.5);
    uint faceIndex = cubeShadow ? LocalShadowCubeFace(direction) : 0u;
    uint face = firstFace + faceIndex * 7u;
    hvec4 projected = LocalShadowProject(face, worldPos);
    if (projected.w <= 0.0)
        return 1.0;
    hvec3 ndc = projected.xyz / projected.w;
    if (ndc.z <= 0.0 || ndc.z >= 1.0 || any(greaterThan(abs(ndc.xy), hvec2_splat(1.0))))
        return 1.0;
    hvec2 uv = LocalShadowClipToUV(ndc.xy);
    hfloat invResolution = b_ClusterShadowData[face + 6u].z;
#if defined(COMPILEPS) && !defined(URHO3D_MOBILE) && !defined(URHO3D_EMSCRIPTEN) && defined(RENDER_QUALITY) && RENDER_QUALITY == RENDER_QUALITY_FULL
    hvec2 texel = uv / invResolution;
    hvec2 baseUV = (floor(texel) + 0.5) * invResolution;
    hvec2 weights = fract(texel);
    // Bilinearly blend adjacent 2x2 box kernels over nine texels for continuous subtexel filtering.
    hvec3 weightsX = hvec3_init(1.0 - weights.x, 1.0, weights.x);
    hvec3 weightsY = hvec3_init(1.0 - weights.y, 1.0, weights.y);
    // Keep every tap on the atlas-safe path, including cube-edge remapping.
    hfloat visibility =
        LocalShadowTap(firstFace, faceIndex, baseUV + hvec2_init(-1.0, -1.0) * invResolution, ndc.z, cubeShadow, light.xyz, distance, quality.y) * weightsX.x * weightsY.x +
        LocalShadowTap(firstFace, faceIndex, baseUV + hvec2_init(0.0, -1.0) * invResolution, ndc.z, cubeShadow, light.xyz, distance, quality.y) * weightsX.y * weightsY.x +
        LocalShadowTap(firstFace, faceIndex, baseUV + hvec2_init(1.0, -1.0) * invResolution, ndc.z, cubeShadow, light.xyz, distance, quality.y) * weightsX.z * weightsY.x +
        LocalShadowTap(firstFace, faceIndex, baseUV + hvec2_init(-1.0, 0.0) * invResolution, ndc.z, cubeShadow, light.xyz, distance, quality.y) * weightsX.x * weightsY.y +
        LocalShadowTap(firstFace, faceIndex, baseUV, ndc.z, cubeShadow, light.xyz, distance, quality.y) * weightsX.y * weightsY.y +
        LocalShadowTap(firstFace, faceIndex, baseUV + hvec2_init(1.0, 0.0) * invResolution, ndc.z, cubeShadow, light.xyz, distance, quality.y) * weightsX.z * weightsY.y +
        LocalShadowTap(firstFace, faceIndex, baseUV + hvec2_init(-1.0, 1.0) * invResolution, ndc.z, cubeShadow, light.xyz, distance, quality.y) * weightsX.x * weightsY.z +
        LocalShadowTap(firstFace, faceIndex, baseUV + hvec2_init(0.0, 1.0) * invResolution, ndc.z, cubeShadow, light.xyz, distance, quality.y) * weightsX.y * weightsY.z +
        LocalShadowTap(firstFace, faceIndex, baseUV + hvec2_init(1.0, 1.0) * invResolution, ndc.z, cubeShadow, light.xyz, distance, quality.y) * weightsX.z * weightsY.z;
    visibility *= 0.25;
#else
    hvec2 texel = uv / invResolution - 0.5;
    hvec2 baseUV = (floor(texel) + 0.5) * invResolution;
    hvec2 weights = fract(texel);
    hfloat s00 = LocalShadowTap(firstFace, faceIndex, baseUV, ndc.z, cubeShadow, light.xyz, distance, quality.y);
    hfloat s10 = LocalShadowTap(firstFace, faceIndex, baseUV + hvec2_init(invResolution, 0.0), ndc.z, cubeShadow, light.xyz, distance, quality.y);
    hfloat s01 = LocalShadowTap(firstFace, faceIndex, baseUV + hvec2_init(0.0, invResolution), ndc.z, cubeShadow, light.xyz, distance, quality.y);
    hfloat s11 = LocalShadowTap(firstFace, faceIndex, baseUV + hvec2_splat(invResolution), ndc.z, cubeShadow, light.xyz, distance, quality.y);
    hfloat visibility = mix(mix(s00, s10, weights.x), mix(s01, s11, weights.x), weights.y);
#endif
    return 1.0 - (1.0 - visibility) * (1.0 - meta.w) * quality.z;
}
#endif

#endif
