// Float sampler operations shared by generated shader stages.
// Each block is emitted only when the corresponding operation is present.
#if defined(SURFACE_TEXTURE_SIZE) && !defined(SURFACE_TEXTURE_SIZE_DECLARED)
#define SURFACE_TEXTURE_SIZE_DECLARED
ivec2 SurfaceTextureSize(sampler2D source, int lod)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    uint w, h, levels;
    source.m_texture.GetDimensions(lod, w, h, levels);
    return ivec2(w, h);
#else
    return textureSize(source, lod);
#endif
}
ivec3 SurfaceTextureSize(sampler2DArray source, int lod)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    uint w, h, d, levels;
    source.m_texture.GetDimensions(lod, w, h, d, levels);
    return ivec3(w, h, d);
#else
    return textureSize(source, lod);
#endif
}
ivec3 SurfaceTextureSize(sampler3D source, int lod)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    uint w, h, d, levels;
    source.m_texture.GetDimensions(lod, w, h, d, levels);
    return ivec3(w, h, d);
#else
    return textureSize(source, lod);
#endif
}
ivec2 SurfaceTextureSize(samplerCube source, int lod)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    uint w, h, levels;
    source.m_texture.GetDimensions(lod, w, h, levels);
    return ivec2(w, h);
#else
    return textureSize(source, lod);
#endif
}
#endif

#if defined(SURFACE_TEXTURE_QUERY_LEVELS) && !defined(SURFACE_TEXTURE_QUERY_LEVELS_DECLARED)
#define SURFACE_TEXTURE_QUERY_LEVELS_DECLARED
int SurfaceTextureQueryLevels(sampler2D source)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    uint w, h, levels;
    source.m_texture.GetDimensions(0, w, h, levels);
    return int(levels);
#else
    return textureQueryLevels(source);
#endif
}
int SurfaceTextureQueryLevels(sampler2DArray source)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    uint w, h, d, levels;
    source.m_texture.GetDimensions(0, w, h, d, levels);
    return int(levels);
#else
    return textureQueryLevels(source);
#endif
}
int SurfaceTextureQueryLevels(sampler3D source)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    uint w, h, d, levels;
    source.m_texture.GetDimensions(0, w, h, d, levels);
    return int(levels);
#else
    return textureQueryLevels(source);
#endif
}
int SurfaceTextureQueryLevels(samplerCube source)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    uint w, h, levels;
    source.m_texture.GetDimensions(0, w, h, levels);
    return int(levels);
#else
    return textureQueryLevels(source);
#endif
}
#endif

#if defined(SURFACE_TEXTURE_QUERY_LOD) && defined(COMPILEPS) && !defined(SURFACE_TEXTURE_QUERY_LOD_DECLARED)
#define SURFACE_TEXTURE_QUERY_LOD_DECLARED
hvec2 SurfaceTextureQueryLod(sampler2D source, hvec2 coordinate)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return hvec2_init(source.m_texture.CalculateLevelOfDetail(source.m_sampler, coordinate),
        source.m_texture.CalculateLevelOfDetailUnclamped(source.m_sampler, coordinate));
#else
    return textureQueryLod(source, coordinate);
#endif
}
hvec2 SurfaceTextureQueryLod(sampler2DArray source, hvec2 coordinate)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return hvec2_init(source.m_texture.CalculateLevelOfDetail(source.m_sampler, coordinate),
        source.m_texture.CalculateLevelOfDetailUnclamped(source.m_sampler, coordinate));
#else
    return textureQueryLod(source, coordinate);
#endif
}
hvec2 SurfaceTextureQueryLod(sampler3D source, hvec3 coordinate)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return hvec2_init(source.m_texture.CalculateLevelOfDetail(source.m_sampler, coordinate),
        source.m_texture.CalculateLevelOfDetailUnclamped(source.m_sampler, coordinate));
#else
    return textureQueryLod(source, coordinate);
#endif
}
hvec2 SurfaceTextureQueryLod(samplerCube source, hvec3 coordinate)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return hvec2_init(source.m_texture.CalculateLevelOfDetail(source.m_sampler, coordinate),
        source.m_texture.CalculateLevelOfDetailUnclamped(source.m_sampler, coordinate));
#else
    return textureQueryLod(source, coordinate);
#endif
}
#endif

#if defined(SURFACE_TEXTURE_GATHER) && !defined(SURFACE_TEXTURE_GATHER_DECLARED)
#define SURFACE_TEXTURE_GATHER_DECLARED
hvec4 SurfaceTextureResolveGather(hvec4 values, int component, bool sourceColor)
{
#if defined(COMPILEPS) && defined(NOT_SUPPORT_SRGB)
    if (sourceColor && component != 3)
    {
        // All four components represent RGB-channel samples, including values.w.
        values = hvec4_init(GammaToLinearSpace(vec3(values.xyz)), GammaToLinearSpace(vec3_splat(values.w)).x);
    }
#endif
    return values;
}
hvec4 SurfaceTextureGather(sampler2D source, hvec2 coordinate, int component, bool sourceColor)
{
    hvec4 values;
#if BGFX_SHADER_DIALECT_HLSL > 300
    if (component == 0) values = source.m_texture.GatherRed(source.m_sampler, coordinate);
    else if (component == 1) values = source.m_texture.GatherGreen(source.m_sampler, coordinate);
    else if (component == 2) values = source.m_texture.GatherBlue(source.m_sampler, coordinate);
    else values = source.m_texture.GatherAlpha(source.m_sampler, coordinate);
#else
    if (component == 0) values = textureGather(source, coordinate, 0);
    else if (component == 1) values = textureGather(source, coordinate, 1);
    else if (component == 2) values = textureGather(source, coordinate, 2);
    else values = textureGather(source, coordinate, 3);
#endif
    return SurfaceTextureResolveGather(values, component, sourceColor);
}
hvec4 SurfaceTextureGather(sampler2DArray source, hvec3 coordinate, int component, bool sourceColor)
{
    hvec4 values;
#if BGFX_SHADER_DIALECT_HLSL > 300
    if (component == 0) values = source.m_texture.GatherRed(source.m_sampler, coordinate);
    else if (component == 1) values = source.m_texture.GatherGreen(source.m_sampler, coordinate);
    else if (component == 2) values = source.m_texture.GatherBlue(source.m_sampler, coordinate);
    else values = source.m_texture.GatherAlpha(source.m_sampler, coordinate);
#else
    if (component == 0) values = textureGather(source, coordinate, 0);
    else if (component == 1) values = textureGather(source, coordinate, 1);
    else if (component == 2) values = textureGather(source, coordinate, 2);
    else values = textureGather(source, coordinate, 3);
#endif
    return SurfaceTextureResolveGather(values, component, sourceColor);
}
hvec4 SurfaceTextureGather(samplerCube source, hvec3 coordinate, int component, bool sourceColor)
{
    hvec4 values;
#if BGFX_SHADER_DIALECT_HLSL > 300
    if (component == 0) values = source.m_texture.GatherRed(source.m_sampler, coordinate);
    else if (component == 1) values = source.m_texture.GatherGreen(source.m_sampler, coordinate);
    else if (component == 2) values = source.m_texture.GatherBlue(source.m_sampler, coordinate);
    else values = source.m_texture.GatherAlpha(source.m_sampler, coordinate);
#else
    if (component == 0) values = textureGather(source, coordinate, 0);
    else if (component == 1) values = textureGather(source, coordinate, 1);
    else if (component == 2) values = textureGather(source, coordinate, 2);
    else values = textureGather(source, coordinate, 3);
#endif
    return SurfaceTextureResolveGather(values, component, sourceColor);
}
#endif

#if defined(SURFACE_TEXTURE_COLOR) && !defined(SURFACE_TEXTURE_COLOR_DECLARED)
#define SURFACE_TEXTURE_COLOR_DECLARED
hvec4 SurfaceResolveSamplerSourceColor(hvec4 color, bool sourceColor)
{
#if defined(COMPILEPS) && defined(NOT_SUPPORT_SRGB)
    if (sourceColor)
        return hvec4_init(GammaToLinearSpace(vec4(color)));
#endif
    return color;
}
#endif

#if defined(SURFACE_TEXTURE_SAMPLING)
#include "SurfaceGodotSampling.sh"
#endif
