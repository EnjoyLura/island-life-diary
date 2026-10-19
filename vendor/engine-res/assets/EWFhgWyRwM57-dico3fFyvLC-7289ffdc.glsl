#ifdef VOXEL_SPARSE4
    // TU_CUSTOM2 (slot 7) is exclusively the Sparse4 Directory. Renderer-wide
    // variation defines may otherwise make Paint/LightMap slot-7 paths
    // reachable in this shader. Remove them before any varying or shader include.
    #undef PAINTABLE
    #undef PAINTABLE_UV_AVAILABLE
    #undef LIGHTMAP
    #undef LIGHTMAP_DIRECTIONALITY
#endif

#include "varying_scenepass.def.sc"
#include "urho3d_compatibility.sh"
#ifdef INSTANCED
    #define _VOXINSTANCED , i_data0, i_data1, i_data2, i_data3
#else
    #define _VOXINSTANCED
#endif
#ifdef COMPILEVS
    $input a_position _VOXINSTANCED
    $output vTexCoord, vNormal, vWorldPos, vShadowPos0, vColor
#endif
#ifdef COMPILEPS
    $input vTexCoord, vNormal, vWorldPos, vShadowPos0, vColor
#endif

#include "Common/common.sh"
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "constants.sh"

#ifdef COMPILEPS
#include "PBR/StandardPBR.sh"
#endif

// Per-volume parameters live in the volume-info table (RGBA32F, TU_CUSTOM1); the
// instance stream carries only the row index (i_data3.x). The non-instanced fallback
// (single-instance batch group) delivers the same index through this material
// constant — everything else still comes from the table, so the material stays
// shared per atlas page. u_VoxelJitter / u_VoxelPaletteAtlasHeight are the only
// remaining true material uniforms. Scalar: this bgfx fork supports float uniforms,
// and setUniform copies by declared type so the fallback's Vector4 write is safe.
uniform hfloat u_VoxelVolumeIndex;
uniform hfloat u_VoxelJitter;
uniform hfloat u_VoxelPaletteAtlasHeight;
// Banks per 4-row palette group (1 Legacy, 8 Virtualized); see VoxelRenderResources.
uniform hfloat u_VoxelPaletteBanksPerRow;

#define cVoxelJitter u_VoxelJitter

#include "Voxel/VoxelDdaCommon.sh"

#ifdef COMPILEPS
#ifdef VELOCITY_PASS
uniform hmat4 u_UnjitteredViewProj;
uniform hmat4 u_PrevViewProj;
uniform hmat4 u_PrevModel;
#endif
#ifdef LOCAL_SHADOW_DEPTH
uniform hvec4 u_LocalShadowDepthBias;
#endif
#ifdef TEMPORAL_SHADOW_DEPTH
uniform hvec4 u_TemporalShadowDepthParams; // xyz = parallel world ray, w = hit slope bias
#endif
#include "Voxel/VoxelDdaOccupancy.sh"
#if defined(MOBILE_DEFERRED) && VOXEL_STATIC_AO && !defined(SHADOW) && !defined(VELOCITY_PASS)
#include "Voxel/VoxelStaticAO.sh"
#endif

// paletteSlot comes from the volume table (texel 4 .w): the GPU slot of the volume's bank,
// equal to the bank in the Legacy layout.
void SamplePalette(float indexByte, bool interior, hfloat paletteSlot,
    out vec3 albedo, out vec3 pbr, out vec4 emissive)
{
    hfloat voxelPalBanksPerRow = max(u_VoxelPaletteBanksPerRow, 1.0);
    hfloat voxelPalSlot = floor(paletteSlot + 0.5);
    hfloat voxelPalRowGroup = floor(voxelPalSlot / voxelPalBanksPerRow);
    hfloat voxelPalColumn = voxelPalSlot - voxelPalRowGroup * voxelPalBanksPerRow;
    hfloat voxelPalU = (voxelPalColumn * 256.0 + floor(indexByte + 0.5) + 0.5) / (voxelPalBanksPerRow * 256.0);
    hfloat voxelPalRow0 = voxelPalRowGroup * 4.0 + 0.5;
    hvec2 voxelAlbedoUV = hvec2_init(voxelPalU,
        (voxelPalRow0 + (interior ? 3.0 : 0.0)) / u_VoxelPaletteAtlasHeight);
    hvec2 voxelPbrUV = hvec2_init(voxelPalU, (voxelPalRow0 + 1.0) / u_VoxelPaletteAtlasHeight);
    hvec2 voxelEmissiveUV = hvec2_init(voxelPalU, (voxelPalRow0 + 2.0) / u_VoxelPaletteAtlasHeight);
    vec4 voxelAlbedo = texture2D(sDiffMap, voxelAlbedoUV);
    vec4 voxelPBR = texture2D(sDiffMap, voxelPbrUV);
    vec4 voxelEmissive = texture2D(sDiffMap, voxelEmissiveUV);
    voxelAlbedo = GammaToLinearSpace(voxelAlbedo);
    voxelEmissive.rgb = GammaToLinearSpace(voxelEmissive.rgb);
    albedo = voxelAlbedo.rgb;
    pbr = voxelPBR.rgb;
    emissive = voxelEmissive;
}
#endif

#ifdef COMPILEVS
void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vWorldPos = hvec4_init(worldPos, GetDepth(gl_Position));
    vNormal = hvec3_init(0.0, 1.0, 0.0);
    vColor = vec4(1.0, 1.0, 1.0, 1.0);
    vTexCoord = vec2(0.0, 0.0);
    // Volume-table row index. All 8 hull verts write the same value, so interpolation
    // is exact; vShadowPos0 is an fp32 interpolator (vColor is half on DX and rounds
    // past 2048 volumes).
#ifdef INSTANCED
    hfloat volumeIndex = i_data3.x;
#else
    hfloat volumeIndex = u_VoxelVolumeIndex;
#endif
    hfloat hullHwZ = gl_Position.z / max(gl_Position.w, 1e-6);
#if BGFX_SHADER_LANGUAGE_GLSL
    hullHwZ = hullHwZ * 0.5 + 0.5;
#endif
    vShadowPos0 = hvec4_init(volumeIndex, 0.0, 0.0, hullHwZ);
}
#endif

#ifdef COMPILEPS
// CONSERVATIVE_DEPTH_FARTHER permits early depth rejection in either depth convention.
// Discard can delay depth writes; it does not inherently disable early rejection.
// Forward-Z GBuffer avoids discard; Reverse-Z and velocity clip misses instead of writing a clamped endpoint.
// Teardown customDiscard writes 1.1 — outside
// the [0,1] depth range — so a miss is not a valid far-plane surface. Writing 1.0
// instead lets a later overlapping hull overwrite a neighbour's hit (view-dependent
// GBuffer pit at volume seams).
#if (defined(CONSERVATIVE_DEPTH_FARTHER) || defined(CONSERVATIVE_DEPTH_GE)) && !defined(VELOCITY_PASS) && !defined(REVERSED_Z) && !defined(MOBILE_DEFERRED)
    // GBuffer misses write all four outputs. Velocity has one output and clips misses.
    // Depth 1.1 prevents a later hull from overwriting a neighbour's far-plane hit.
    #define VOXEL_MISS_CLIP(_x) \
        { \
        if ((_x) < 0.0) \
        { \
            gl_FragDepth = 1.1; \
            gl_FragData[0] = vec4_splat(0.0); \
            gl_FragData[1] = vec4_splat(0.0); \
            gl_FragData[2] = vec4_splat(0.0); \
            gl_FragData[3] = vec4_splat(0.0); \
            return; \
        } \
        }
#elif BGFX_SHADER_DIALECT_GLSL
    #define VOXEL_MISS_CLIP(_x) { if ((_x) < 0.0) discard; }
#else
    #define VOXEL_MISS_CLIP(_x) clip(_x)
#endif

void PS()
{
    // Per-volume parameters from the info table (fp32 fetches into hvec4).
    int row = int(vShadowPos0.x + 0.5);
    hvec4 wtl0 = texelFetch(sVoxelDdaTable, ivec2(0, row), 0);
    hvec4 wtl1 = texelFetch(sVoxelDdaTable, ivec2(1, row), 0);
    hvec4 wtl2 = texelFetch(sVoxelDdaTable, ivec2(2, row), 0);
    hvec4 dimRow = texelFetch(sVoxelDdaTable, ivec2(3, row), 0);
    hvec4 atlasRow = texelFetch(sVoxelDdaTable, ivec2(4, row), 0);
    hvec4 latticeRow = texelFetch(sVoxelDdaTable, ivec2(5, row), 0);
    hvec3 size = dimRow.xyz;
#ifdef VOXEL_SPARSE4
    int directoryBase = int(atlasRow.x + 0.5);
#else
    ivec3 atlasBase = ivec3(int(atlasRow.x + 0.5), int(atlasRow.y + 0.5),
        int(atlasRow.z + 0.5));
#endif

    // Camera and hull point in voxel space, both rebuilt in fp32 from fp32 sources
    // (cCameraPosPS uniform; vWorldPos fp32 interpolator). cCameraPosPS is this pass's
    // camera — the shadow camera in the shadow pass.
    hvec3 worldCam = cCameraPosPS;
#ifdef TEMPORAL_SHADOW_DEPTH
    // A directional shadow has parallel rays, with one origin per pixel on the camera plane.
    hvec3 shadowDirection = u_TemporalShadowDepthParams.xyz;
    hfloat shadowHullZ = dot(vWorldPos.xyz - worldCam, shadowDirection);
    worldCam = vWorldPos.xyz - shadowDirection * shadowHullZ;
#endif
    hvec3 localCam = hvec3_init(
        dot(wtl0.xyz, worldCam) + wtl0.w,
        dot(wtl1.xyz, worldCam) + wtl1.w,
        dot(wtl2.xyz, worldCam) + wtl2.w) * size;
    hvec3 hullLocal01 = hvec3_init(
        dot(wtl0.xyz, vWorldPos.xyz) + wtl0.w,
        dot(wtl1.xyz, vWorldPos.xyz) + wtl1.w,
        dot(wtl2.xyz, vWorldPos.xyz) + wtl2.w);
    hvec3 localPos = hullLocal01 * size;
    hvec3 localDir = localPos - localCam;
    // Not length(): bgfx_shader.sh's length(vec3) is fp16 on DX11 hlslcc and
    // overflows when |localDir| > ~256 voxels. Intrinsics stay fp32.
    hfloat hullDist = sqrt(dot(localDir, localDir));
    VOXEL_MISS_CLIP(hullDist - 1e-5);
    localDir /= max(hullDist, 1e-5);

    int entryAxis = 0;
    hvec3 boxDir = localDir;
#ifdef TEMPORAL_SHADOW_DEPTH
    // Parallel shadow rays can have exact zero components. Keep slab division finite without tilting the DDA ray.
    boxDir = max(abs(localDir), hvec3_init(1e-8, 1e-8, 1e-8))
        * (step(hvec3_init(0.0, 0.0, 0.0), localDir) * 2.0 - 1.0);
#endif
    hfloat minDist = VoxelDistanceToBox(localCam, boxDir, size, entryAxis);
    hfloat backDist = VoxelDistanceToBoxBack(localCam, boxDir, size);
    // Teardown gbuffervox: start just BEFORE the first voxel, do not clamp inside.
    // Starting inside + clamp(size-eps) can step past a 1-voxel-thick slab at a seam.
    hfloat originDist = minDist - 0.001;
#ifdef TEMPORAL_SHADOW_DEPTH
    originDist = max(originDist, 0.0);
    minDist = originDist;
#endif
#ifdef LOCAL_SHADOW_DEPTH
    // DDA writes its own depth: clip traversal to the shadow near plane before looking for an occluder.
    hfloat nearDist = hullDist * cNearClipPS / max(vWorldPos.w * cFarClipPS, cNearClipPS);
    originDist = max(originDist, nearDist);
    minDist = originDist;
#endif
    VOXEL_MISS_CLIP(backDist - minDist);
    hfloat rmd = backDist - minDist;
    VOXEL_MISS_CLIP(rmd - 1e-5);

    hvec3 origin = localCam + localDir * originDist;

    vec4 hitSamp = vec4(0.0, 0.0, 0.0, 0.0);
    int hitAxis = 0;
#ifdef VOXEL_SPARSE4
    hfloat hitT = RaycastSparse4Occupancy(origin, localDir, rmd, entryAxis, size,
        directoryBase, hitSamp, hitAxis);
#else
    hfloat hitT = RaycastOccupancy(origin, localDir, rmd, entryAxis, size, atlasBase,
        hitSamp, hitAxis);
#endif
    // Plain variant: DX ignores discard after SV_Depth is assigned; clip() kills the
    // pixel for real. GE variant: miss writes far depth instead (early-Z stays on).
    VOXEL_MISS_CLIP(rmd - hitT - 1e-5);

    hfloat hitDist = hitT + minDist;
    hvec3 hitLocal = localCam + localDir * hitDist;
    hvec3 localNormal;
    if (hitAxis == 0)
        localNormal = hvec3_init(-sign(localDir.x), 0.0, 0.0);
    else if (hitAxis == 1)
        localNormal = hvec3_init(0.0, -sign(localDir.y), 0.0);
    else
        localNormal = hvec3_init(0.0, 0.0, -sign(localDir.z));

    // Never use gl_FragCoord.z after writing SV_Depth — on DX it can read as 0,
    // so every hit lands on the near plane (far blocks in front, cascade all-near).
    hfloat tAlong = hitDist / max(hullDist, 1e-5);
    hfloat n = cNearClipPS;
    hfloat f = cFarClipPS;
// Legacy directional shadows are orthographic; local atlas faces use perspective depth.
#ifdef TEMPORAL_SHADOW_DEPTH
    // Translate from hull depth to hit depth; the projection's constant bias must not be scaled by tAlong.
    gl_FragDepth = vShadowPos0.w + (tAlong - 1.0) * shadowHullZ / max(f - n, 1e-5);
#elif defined(SHADOW) && !defined(LOCAL_SHADOW_DEPTH)
    gl_FragDepth = tAlong * vShadowPos0.w + (tAlong - 1.0) * n / max(f - n, 1e-5);
#else
    hfloat hullViewZ = max(vWorldPos.w * f, n);
    hfloat hitViewZ = max(hullViewZ * tAlong, n + 1e-3);
    gl_FragDepth = DelinearizeDepth(hitViewZ, n, f);
#endif

#ifdef TEMPORAL_SHADOW_DEPTH
    // SV_Depth replaces the hull's raster slope bias. Bias the actual voxel hit instead.
    hfloat hitSlope = max(abs(dFdx(gl_FragDepth)), abs(dFdy(gl_FragDepth)));
    gl_FragDepth += min(hitSlope * u_TemporalShadowDepthParams.w, 0.01);
#endif

#ifdef LOCAL_SHADOW_DEPTH
    // SV_Depth replaces raster depth, so the fixed-function hull bias cannot bias the ray hit.
    hfloat hitSlope = max(abs(dFdx(gl_FragDepth)), abs(dFdy(gl_FragDepth)));
    gl_FragDepth += u_LocalShadowDepthBias.x + min(hitSlope * u_LocalShadowDepthBias.y, 0.01);
#endif

#ifdef VELOCITY_PASS
    // The hull only bounds traversal. Reproject the actual occupied surface using
    // the previous published unit-box transform, including the volume dimensions.
    hvec3 hitWorld = worldCam + (vWorldPos.xyz - worldCam) * tAlong;
    hvec4 previousWorld = mul(hvec4_init(hitLocal / size, 1.0), u_PrevModel);
    hvec4 currentClip = mul(hvec4_init(hitWorld, 1.0), u_UnjitteredViewProj);
    hvec4 previousClip = mul(previousWorld, u_PrevViewProj);
    hvec2 motion = (currentClip.xy / max(currentClip.w, 1e-6)
        - previousClip.xy / max(previousClip.w, 1e-6)) * 0.5;
#if !BGFX_SHADER_LANGUAGE_GLSL
    motion.y = -motion.y;
#endif
    gl_FragColor = hvec4_init(clamp(motion, hvec2_init(-0.5, -0.5), hvec2_init(0.5, 0.5)), 0.0, 1.0);
    return;
#endif

    // Normal transform without cModel (wrong under instancing): for a normal the
    // correct map is (localToWorld^-1)^T = worldToLocal^T, i.e. the axis-aligned
    // local normal picks a column of the table matrix.
    hvec3 worldNormal = normalize(
        wtl0.xyz * localNormal.x + wtl1.xyz * localNormal.y + wtl2.xyz * localNormal.z);
    if (dot(worldNormal, worldNormal) < 1e-6)
        worldNormal = hvec3_init(0.0, 1.0, 0.0);

#ifdef SHADOW
    #ifdef VSM_SHADOW
        float zd = gl_FragDepth;
        gl_FragColor = vec4(zd, zd * zd, 1.0, 1.0);
    #else
        gl_FragColor = vec4_splat(1.0);
    #endif
    return;
#endif

    vec3 albedo;
    vec3 pbr;
    vec4 emissive;
    SamplePalette(hitSamp.r * 255.0, hitSamp.g > 0.75, atlasRow.w, albedo, pbr, emissive);

    hvec3 jitterCell = floor(hitLocal + latticeRow.xyz);
    hfloat jitterHash =
        fract(sin(dot(jitterCell, hvec3_init(127.1, 311.7, 74.7))) * 43758.5453);
    albedo *= 1.0 + cVoxelJitter * (jitterHash - 0.5);

#if defined(DEFERRED)
    EncodeGBufferPBR(albedo, pbr.g, pbr.b, pbr.r, worldNormal, emissive.rgb * (emissive.a * 16.0), SHADINGMODELID_PBR_LIT, 1.0);
#ifdef MOBILE_DEFERRED
    float staticAO = 1.0;
#if VOXEL_STATIC_AO
#ifdef VOXEL_SPARSE4
    staticAO = VoxelStaticAO(hitLocal, localNormal, hitAxis, size, ivec3(0, 0, 0), directoryBase);
#else
    staticAO = VoxelStaticAO(hitLocal, localNormal, hitAxis, size, atlasBase, 0);
#endif
#endif
    // Keep the existing material/BRDF signatures. This source flag also bypasses Mesh GTAO when AO is disabled.
    gl_FragData[1].ba = vec2(staticAO, 1.0);
    WRITE_MOBILE_DEPTH(gl_FragDepth);
#endif
#else
    gl_FragColor = vec4(albedo, 1.0);
#endif
}
#endif
