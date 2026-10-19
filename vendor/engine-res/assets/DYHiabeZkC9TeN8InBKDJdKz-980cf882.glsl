#include "varying_scenepass.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position _NORMAL _TEXCOORD0 _COLOR0 _TEXCOORD1 _ATANGENT _SKINNED _INSTANCED _INSTANCED_EXTRA1 _INSTANCED_EXTRA2 _INSTANCED_EXTRA3
    #ifdef PERPIXEL
        $output vTexCoord _VTANGENT, vNormal, vWorldPos _VPAINTUV _VSHADOWPOS _VSPOTPOS _VCUBEMASKVEC _VCOLOR _AOUV _VCLUSTERVS _VLIGHTMAPUV
    #else
        $output vTexCoord _VTANGENT, vNormal, vWorldPos _VPAINTUV, vVertexLight, vScreenPos _VREFLECTIONVEC _VTEXCOORD2 _VCOLOR _AOUV _VCLUSTERVS _VLIGHTMAPUV
    #endif
#endif
#ifdef COMPILEPS
    #ifdef PERPIXEL
        $input vTexCoord _VTANGENT, vNormal, vWorldPos _VPAINTUV _VSHADOWPOS _VSPOTPOS _VCUBEMASKVEC _VCOLOR _AOUV _VCLUSTERVS _VLIGHTMAPUV
    #else
        $input vTexCoord _VTANGENT, vNormal, vWorldPos _VPAINTUV, vVertexLight, vScreenPos _VREFLECTIONVEC _VTEXCOORD2 _VCOLOR _AOUV _VCLUSTERVS _VLIGHTMAPUV
    #endif
#endif

#ifdef PAINTABLE
#define PAINTABLE_UV_AVAILABLE 1
#endif

#include "Common/common.sh"

#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "lighting.sh"
#include "fog.sh"
#include "constants.sh"
#ifdef LIGHTMAP
#include "LightMap.sh"
#endif
#if defined(COMPILEVS) && defined(CLUSTER_VS)
#include "PBR/GI.sh"
#include "Cluster/clusterlights.sh"
#include "Cluster/clusters.sh"
#endif
#if COMPILEPS
#include "PBR/StandardPBR.sh"

uniform float u_TextureMetallicFactor;
uniform float u_TextureRoughnessFactor;
uniform vec4 u_TintColor;
uniform float u_Anisotropy;

#define cTextureMetallicFactor u_TextureMetallicFactor
#define cTextureRoughnessFactor u_TextureRoughnessFactor
#define cTintColor u_TintColor
#define cAnisotropy u_Anisotropy
#endif

#ifdef VOXELJITTER
// Per-voxel brightness jitter amplitude, ported from LitSolid.glsl (see NoTextureVCol
// technique). Attribute/varying plumbing is shared via
// urho3d_compatibility.sh, which routes the lattice frame through the tangent stream.
uniform float u_VoxelJitter;
#endif

#ifdef VOXELPALETTE
// This material's palette slot row offset (slot * 4); set per (world, bank) material clone
// and kept current by the engine's slot pool. In the Legacy layout slot == bank.
// See VoxelPhysicsWorld::GetPaletteTexture.
uniform hfloat u_VoxelPaletteBank;
// Palette atlas height in texels and banks per 4-row group (atlas width = banksPerRow * 256).
// Both fed from VoxelRenderResources::ApplyPaletteLayoutParameters, the single C++ source
// of truth, so the shader carries no literal copy of the layout.
uniform hfloat u_VoxelPaletteAtlasHeight;
uniform hfloat u_VoxelPaletteBanksPerRow;
#endif

#ifdef VOXELPACKED
// Packed voxel route: per-drawable lattice frame replacing the tangent stream — see
// LitSolid.glsl for the layout (xyz = lattice + chunk origin, w = voxel size).
uniform vec4 u_VoxelLatticeFrame;
#endif

void VS()
{
    #ifdef NOUV
    vec2 iTexCoord = vec2(0.0, 0.0);
    #endif
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vNormal = GetWorldNormal(modelMatrix);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));

    vNormal *= cNormalOddNegativeScale;

    #ifdef VERTEXCOLOR
        vColor = iColor;
    #endif

    #if defined(NORMALMAP) || defined(DIRBILLBOARD)
        vec4 tangent = GetWorldTangent(modelMatrix);
        vec3 bitangent = cross(tangent.xyz, vNormal) * tangent.w * cBitangentOddNegativeScale;
        vTexCoord = vec4(GetTexCoord(iTexCoord), bitangent.xy);
        vTangent = vec4(tangent.xyz, bitangent.z);
    #else
        vTexCoord = GetTexCoord(iTexCoord);
    #endif

    #if defined(VOXELJITTER) && !defined(NORMALMAP) && !defined(DIRBILLBOARD)
        #ifdef VOXELPACKED
            // Same lattice frame, from the per-drawable constant instead of the tangent
            // stream: chunk-local corner * voxel size + (lattice origin + chunk origin).
            vTangent = vec4(iPos.xyz * u_VoxelLatticeFrame.w + u_VoxelLatticeFrame.xyz,
                u_VoxelLatticeFrame.w);
        #else
            // Not a UV tangent: the voxel mesher packs (spawn lattice origin, voxel size) here.
            // Object-space position plus that origin is a frame that is identical before and
            // after a piece breaks off, so the per-voxel hash downstream never pops or swims.
            vTangent = vec4(iPos.xyz + iTangent.xyz, iTangent.w);
        #endif
    #endif

    #ifdef PAINTABLE
        vPaintUV = iTexCoord1.xy;
    #endif

    #if defined(AO)
        #if defined(SSAO)
            vAOUV = GetSSAOTexCoord(gl_Position);
        #else
            vAOUV = iTexCoord1.xy;
        #endif
    #endif

    #if defined(LIGHTMAP)
        #if defined(SPEED_GRASS) || defined(SCE_GRASS)
            vLightMapUV = GetTileLightMapUV(vWorldPos.xy - cTerrainOffset, vec2(256.0, 256.0));
        #else
            vLightMapUV = GetLightMapUV(iTexCoord1.xy);
        #endif
    #endif

    #ifdef PERPIXEL
        // Per-pixel forward lighting
        vec4 projWorldPos = vec4(worldPos, 1.0);

        #ifdef SHADOW
            // Shadow projection: transform from world space to shadow space
            GetShadowPos(projWorldPos, vNormal, vShadowPos);
        #endif

        #ifdef SPOTLIGHT
            // Spotlight projection: transform from world space to projector texture coordinates
            vSpotPos = mul(projWorldPos, cLightMatrices[0]);
        #endif
    
        #ifdef POINTLIGHT
            vCubeMaskVec = mul((worldPos - cLightPos.xyz), mat3(cLightMatrices[0][0].xyz, cLightMatrices[0][1].xyz, cLightMatrices[0][2].xyz));
        #endif
    #else
        // Ambient & per-vertex lighting
        #if defined(LIGHTMAP) || defined(AO)
            // If using lightmap, disregard zone ambient light
            // If using AO, calculate ambient in the PS
            vVertexLight = vec3(0.0, 0.0, 0.0);
            vTexCoord2 = iTexCoord1;
        #else
            vVertexLight = GetAmbient(GetZonePos(worldPos));
        #endif

        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
                vVertexLight += GetVertexLight(i, worldPos, vNormal) * cVertexLights[i * 3].rgb;
        #endif

        vScreenPos = GetScreenPos(gl_Position);

        #ifdef ENVCUBEMAP
            vReflectionVec = worldPos - cCameraPos;
        #endif
    #endif
}

void PS()
{
    // Get material diffuse albedo
    #ifdef DIFFMAP
        #ifdef NOT_SUPPORT_SRGB
            vec4 diffInput = GammaToLinearSpace(texture2D(sDiffMap, vTexCoord.xy));
        #else
            vec4 diffInput = texture2D(sDiffMap, vTexCoord.xy);
        #endif
        vec4 baseColor = cMatDiffColor * diffInput;
    #else
        vec4 baseColor = cMatDiffColor;
    #endif

    baseColor.rgb = lerp(baseColor.rgb, GetIntensity(baseColor.rgb) * cTintColor.rgb, cTintColor.a);

    #if defined(VERTEXCOLOR) && !defined(VOXELPALETTE)
        baseColor *= vColor;
    #endif

    #ifdef VOXELPALETTE
        // Voxel palette path: the vertex colour is not a colour. R = palette index / 255,
        // G = interior flag (cut face). sDiffMap is the palette atlas
        // (VoxelPhysicsWorld::GetPaletteTexture): each resident bank owns a 256 x 4 slot —
        //   row0 albedo RGBA | row1 roughness/metallic/specular | row2 emissive rgb +
        //   intensity/16 | row3 cut-face colour
        // u_VoxelPaletteBank carries this material's slot row offset (slot * 4). Slot s
        // sits at column (s % banksPerRow) * 256, rows (s / banksPerRow) * 4 .. +3; the
        // Legacy layout has one bank per row group, so this reduces to rows slot * 4.
        // Sampled nearest + clamp; normalised coordinates instead of texelFetch for
        // ESSL/GLES compatibility. Full precision: Virtualized texel columns reach 2047,
        // past fp16's exact integer range.
        // texture2D is a bgfx macro: each call must stay on ONE line or the shader
        // preprocessor mis-expands it (X3000 on the next token).
        hfloat voxelPalBanksPerRow = max(u_VoxelPaletteBanksPerRow, 1.0);
        hfloat voxelPalSlot = floor(u_VoxelPaletteBank * 0.25 + 0.5);
        hfloat voxelPalColumn = voxelPalSlot - floor(voxelPalSlot / voxelPalBanksPerRow) * voxelPalBanksPerRow;
        hfloat voxelPalU = (voxelPalColumn * 256.0 + floor(vColor.r * 255.0 + 0.5) + 0.5) / (voxelPalBanksPerRow * 256.0);
        hfloat voxelPalRow0 = floor(voxelPalSlot / voxelPalBanksPerRow) * 4.0 + 0.5;
        hvec2 voxelAlbedoUV = hvec2_init(voxelPalU,
            (voxelPalRow0 + (vColor.g > 0.5 ? 3.0 : 0.0)) / u_VoxelPaletteAtlasHeight);
        hvec2 voxelPbrUV = hvec2_init(voxelPalU, (voxelPalRow0 + 1.0) / u_VoxelPaletteAtlasHeight);
        hvec2 voxelEmissiveUV = hvec2_init(voxelPalU, (voxelPalRow0 + 2.0) / u_VoxelPaletteAtlasHeight);
        vec4 voxelAlbedo = texture2D(sDiffMap, voxelAlbedoUV);
        vec4 voxelPBR = texture2D(sDiffMap, voxelPbrUV);
        vec4 voxelEmissive = texture2D(sDiffMap, voxelEmissiveUV);
        // The palette texture is plain RGBA8 (no hardware sRGB view,
        // VoxelPhysicsWorld::GetPaletteTexture) holding sRGB-authored bytes (.vox
        // convention). Decode to linear before lighting like every other albedo source,
        // otherwise voxels render brighter/washed-out vs the same colour on a regular
        // material. Row1 PBR params are scalar data -- no decode. Alpha channels
        // (coverage / emissive intensity) pass through untouched.
        voxelAlbedo = GammaToLinearSpace(voxelAlbedo);
        voxelEmissive.rgb = GammaToLinearSpace(voxelEmissive.rgb);
        baseColor *= voxelAlbedo;
    #endif

    #ifdef VOXELJITTER
        // Teardown-style per-voxel brightness variation (port of LitSolid.glsl block; see
        // there for why it is per-pixel, lattice-framed and full precision).
        hvec3 jitterCell = floor(vTangent.xyz / vTangent.w);
        hfloat jitterHash =
            fract(sin(dot(jitterCell, hvec3_init(127.1, 311.7, 74.7))) * 43758.5453);
        baseColor.rgb *= 1.0 + u_VoxelJitter * (jitterHash - 0.5);
    #endif

    #ifdef METALLIC
        vec4 roughMetalSrc = texture2D(sSpecMap, vTexCoord.xy);

        float roughness = roughMetalSrc.r * cTextureRoughnessFactor;
        float metallic = roughMetalSrc.g * cTextureMetallicFactor;
        float occlusion = roughMetalSrc.b;

        #ifdef ALPHAMASK
            if (roughMetalSrc.a < 0.5)
                discard;
        #endif
    #else
        float roughness = cRoughness;
        float metallic = cMetallic;
        float occlusion = 1.0;
    #endif

    // 为了兼容延迟渲染，只能使用max了（GBuffer编码不够用，实际上虚幻也是这样搞的）
    // 缺点就是无法支持带颜色的高光
    float specular = max(cMatSpecColor.r, max(cMatSpecColor.g, cMatSpecColor.b));

    #ifdef VOXELPALETTE
        // Per-voxel PBR overrides the material constants (row1: R=roughness G=metallic
        // B=specular).
        roughness = voxelPBR.r;
        metallic = voxelPBR.g;
        specular = voxelPBR.b;
    #endif

    // Get normal
    #if defined(NORMALMAP) || defined(DIRBILLBOARD)
        vec3 tangent = vTangent.xyz;
        vec3 bitangent = vec3(vTexCoord.zw, vTangent.w);
        mat3 tbn = TR(mat3(tangent, bitangent, vNormal));
    #endif

    #ifdef NORMALMAP
        vec3 nn = DecodeNormal(texture2D(sNormalMap, vTexCoord.xy));
        //nn.rg *= 2.0;
        vec3 normalDirection = normalize(mul(tbn, nn));
    #else
        vec3 normalDirection = normalize(vNormal);
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(distance(vWorldPos.xyz, cCameraPosPS), __GET_HEIGHT__(vWorldPos));
    #else
        float fogFactor = GetFogFactor(distance(vWorldPos.xyz, cCameraPosPS));
    #endif

    vec4 shadowColor = vec4(1.0, 1.0, 1.0, 1.0);

    // Get shadow
    #ifdef SHADOW  
        shadowColor.rgb = shadowColor.rgb * GetShadow(vShadowPos, vWorldPos.w);
    #endif

    // Get view dir (eyes dir)
    hvec3 _WorldPos = vWorldPos.xyz;
    vec3 viewDirection = normalize(cCameraPosPS - _WorldPos);

// Deferred
#if defined(MATERIALBAKE)
    vec3 bakeEmission = cMatEmissiveColor;
    #if defined(VOXELPALETTE)
        bakeEmission = voxelEmissive.rgb * (voxelEmissive.a * 16.0);
    #elif defined(EMISSIVEMAP)
        bakeEmission *= texture2D(sEmissiveMap, vTexCoord.xy).rgb;
    #endif
    EncodeGBufferBake(baseColor.rgb, baseColor.a, roughness, metallic, occlusion, normalDirection, bakeEmission);
#elif defined(DEFERRED)
    vec3 deferredEmission = cMatEmissiveColor;
    #ifdef VOXELPALETTE
        deferredEmission = voxelEmissive.rgb * (voxelEmissive.a * 16.0);
    #elif defined(MOBILE_DEFERRED) && defined(EMISSIVEMAP)
        deferredEmission *= texture2D(sEmissiveMap, vTexCoord.xy).rgb;
    #endif
    EncodeGBufferPBR(baseColor.rgb, metallic, specular, roughness, normalDirection, deferredEmission, SHADINGMODELID_PBR_LIT, occlusion);
#else
    // PBR calc
    vec3 finalColor = MetallicPBR(baseColor.rgb, metallic, specular, roughness, vWorldPos.xyz, normalDirection, viewDirection, shadowColor.rgb, occlusion
    #ifdef USES_ANISOTROPY
        ,  cAnisotropy
    #endif
        );

    // Add emissive color
    #ifdef AMBIENT
        #if defined(VOXELPALETTE)
            // row2: rgb = emissive colour, a = intensity/16 (compressed at upload,
            // restored to 0..16 here).
            finalColor += voxelEmissive.rgb * (voxelEmissive.a * 16.0);
        #elif defined(EMISSIVEMAP)
            finalColor += cMatEmissiveColor * texture2D(sEmissiveMap, vTexCoord.xy).rgb;
        #else
            finalColor += cMatEmissiveColor;
        #endif
    #endif

    // Mix final color and fog
    finalColor = GetFog(finalColor, fogFactor);

    // Final color
    gl_FragColor = vec4(finalColor, baseColor.a);

    // Gamma in shadering
    #if defined(GAMMA_IN_SHADERING) || defined(USEGAMMA)
        gl_FragColor.rgb = LinearToGammaSpace(toAcesFilmic(gl_FragColor.rgb));
    #endif
#endif
}
