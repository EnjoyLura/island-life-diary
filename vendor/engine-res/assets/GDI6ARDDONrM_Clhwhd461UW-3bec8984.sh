// Stage-correct floating-point sampling with full-precision coordinates/gradients.
#ifndef SURFACE_GODOT_SAMPLING
#define SURFACE_GODOT_SAMPLING
#if BGFX_SHADER_DIALECT_HLSL && BGFX_SHADER_DIALECT_HLSL <= 300
#define samplerCube samplerCUBE
#endif
hvec4 SurfaceTextureSample(sampler2D source, hvec2 coordinate)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
#if defined(COMPILEVS)
    return source.m_texture.SampleLevel(source.m_sampler, coordinate, 0.0);
#else
    return source.m_texture.Sample(source.m_sampler, coordinate);
#endif
#elif BGFX_SHADER_DIALECT_HLSL
#if defined(COMPILEVS)
    return tex2Dlod(source,hvec4_init(coordinate,0.0,0.0));
#else
    return tex2D(source,coordinate);
#endif
#else
#if defined(COMPILEVS)
    return textureLod(source, coordinate, 0.0);
#else
    return texture(source, coordinate);
#endif
#endif
}
#if defined(COMPILEPS)
hvec4 SurfaceTextureSample(sampler2D source, hvec2 coordinate, hfloat bias)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleBias(source.m_sampler, coordinate, bias);
#elif BGFX_SHADER_DIALECT_HLSL
    return tex2Dbias(source,hvec4_init(coordinate,0.0,bias));
#else
    return texture(source, coordinate, bias);
#endif
}
#endif
hvec4 SurfaceTextureLod(sampler2D source, hvec2 coordinate, hfloat lod)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleLevel(source.m_sampler, coordinate, lod);
#elif BGFX_SHADER_DIALECT_HLSL
    return tex2Dlod(source,hvec4_init(coordinate,0.0,lod));
#else
    return textureLod(source, coordinate, lod);
#endif
}
hvec4 SurfaceTextureGrad(sampler2D source, hvec2 coordinate, hvec2 dx, hvec2 dy)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleGrad(source.m_sampler, coordinate, dx, dy);
#elif BGFX_SHADER_DIALECT_HLSL
    return tex2Dgrad(source,coordinate,dx,dy);
#else
    return textureGrad(source, coordinate, dx, dy);
#endif
}
#if !BGFX_SHADER_DIALECT_HLSL || BGFX_SHADER_DIALECT_HLSL > 300
hvec4 SurfaceTextureSample(sampler2DArray source, hvec3 coordinate)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
#if defined(COMPILEVS)
    return source.m_texture.SampleLevel(source.m_sampler, coordinate, 0.0);
#else
    return source.m_texture.Sample(source.m_sampler, coordinate);
#endif
#else
#if defined(COMPILEVS)
    return textureLod(source, coordinate, 0.0);
#else
    return texture(source, coordinate);
#endif
#endif
}
#if defined(COMPILEPS)
hvec4 SurfaceTextureSample(sampler2DArray source, hvec3 coordinate, hfloat bias)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleBias(source.m_sampler, coordinate, bias);
#else
    return texture(source, coordinate, bias);
#endif
}
#endif
hvec4 SurfaceTextureLod(sampler2DArray source, hvec3 coordinate, hfloat lod)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleLevel(source.m_sampler, coordinate, lod);
#else
    return textureLod(source, coordinate, lod);
#endif
}
hvec4 SurfaceTextureGrad(sampler2DArray source, hvec3 coordinate, hvec2 dx, hvec2 dy)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleGrad(source.m_sampler, coordinate, dx, dy);
#else
    return textureGrad(source, coordinate, dx, dy);
#endif
}
#endif
hvec4 SurfaceTextureSample(sampler3D source, hvec3 coordinate)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
#if defined(COMPILEVS)
    return source.m_texture.SampleLevel(source.m_sampler, coordinate, 0.0);
#else
    return source.m_texture.Sample(source.m_sampler, coordinate);
#endif
#elif BGFX_SHADER_DIALECT_HLSL
#if defined(COMPILEVS)
    return tex3Dlod(source,hvec4_init(coordinate,0.0));
#else
    return tex3D(source,coordinate);
#endif
#else
#if defined(COMPILEVS)
    return textureLod(source, coordinate, 0.0);
#else
    return texture(source, coordinate);
#endif
#endif
}
#if defined(COMPILEPS)
hvec4 SurfaceTextureSample(sampler3D source, hvec3 coordinate, hfloat bias)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleBias(source.m_sampler, coordinate, bias);
#elif BGFX_SHADER_DIALECT_HLSL
    return tex3Dbias(source,hvec4_init(coordinate,bias));
#else
    return texture(source, coordinate, bias);
#endif
}
#endif
hvec4 SurfaceTextureLod(sampler3D source, hvec3 coordinate, hfloat lod)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleLevel(source.m_sampler, coordinate, lod);
#elif BGFX_SHADER_DIALECT_HLSL
    return tex3Dlod(source,hvec4_init(coordinate,lod));
#else
    return textureLod(source, coordinate, lod);
#endif
}
hvec4 SurfaceTextureGrad(sampler3D source, hvec3 coordinate, hvec3 dx, hvec3 dy)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleGrad(source.m_sampler, coordinate, dx, dy);
#elif BGFX_SHADER_DIALECT_HLSL
    return tex3Dgrad(source,coordinate,dx,dy);
#else
    return textureGrad(source, coordinate, dx, dy);
#endif
}
hvec4 SurfaceTextureSample(samplerCube source, hvec3 coordinate)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
#if defined(COMPILEVS)
    return source.m_texture.SampleLevel(source.m_sampler, coordinate, 0.0);
#else
    return source.m_texture.Sample(source.m_sampler, coordinate);
#endif
#elif BGFX_SHADER_DIALECT_HLSL
#if defined(COMPILEVS)
    return texCUBElod(source,hvec4_init(coordinate,0.0));
#else
    return texCUBE(source,coordinate);
#endif
#else
#if defined(COMPILEVS)
    return textureLod(source, coordinate, 0.0);
#else
    return texture(source, coordinate);
#endif
#endif
}
#if defined(COMPILEPS)
hvec4 SurfaceTextureSample(samplerCube source, hvec3 coordinate, hfloat bias)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleBias(source.m_sampler, coordinate, bias);
#elif BGFX_SHADER_DIALECT_HLSL
    return texCUBEbias(source,hvec4_init(coordinate,bias));
#else
    return texture(source, coordinate, bias);
#endif
}
#endif
hvec4 SurfaceTextureLod(samplerCube source, hvec3 coordinate, hfloat lod)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleLevel(source.m_sampler, coordinate, lod);
#elif BGFX_SHADER_DIALECT_HLSL
    return texCUBElod(source,hvec4_init(coordinate,lod));
#else
    return textureLod(source, coordinate, lod);
#endif
}
hvec4 SurfaceTextureGrad(samplerCube source, hvec3 coordinate, hvec3 dx, hvec3 dy)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    return source.m_texture.SampleGrad(source.m_sampler, coordinate, dx, dy);
#elif BGFX_SHADER_DIALECT_HLSL
    return texCUBEgrad(source,coordinate,dx,dy);
#else
    return textureGrad(source, coordinate, dx, dy);
#endif
}
hvec4 SurfaceTextureProj(sampler2D source, hvec3 coordinate)
{
    return SurfaceTextureSample(source, coordinate.xy / coordinate.z);
}
hvec4 SurfaceTextureProjLod(sampler2D source, hvec3 coordinate, hfloat lod)
{
    return SurfaceTextureLod(source, coordinate.xy / coordinate.z, lod);
}
hvec4 SurfaceTextureProjGrad(sampler2D source, hvec3 coordinate, hvec2 dx, hvec2 dy)
{
    return SurfaceTextureGrad(source, coordinate.xy / coordinate.z, dx, dy);
}
#if defined(COMPILEPS)
hvec4 SurfaceTextureProj(sampler2D source, hvec3 coordinate, hfloat bias)
{
    return SurfaceTextureSample(source, coordinate.xy / coordinate.z, bias);
}
#endif
hvec4 SurfaceTextureProj(sampler2D source, hvec4 coordinate)
{
    return SurfaceTextureSample(source, coordinate.xy / coordinate.w);
}
hvec4 SurfaceTextureProjLod(sampler2D source, hvec4 coordinate, hfloat lod)
{
    return SurfaceTextureLod(source, coordinate.xy / coordinate.w, lod);
}
hvec4 SurfaceTextureProjGrad(sampler2D source, hvec4 coordinate, hvec2 dx, hvec2 dy)
{
    return SurfaceTextureGrad(source, coordinate.xy / coordinate.w, dx, dy);
}
#if defined(COMPILEPS)
hvec4 SurfaceTextureProj(sampler2D source, hvec4 coordinate, hfloat bias)
{
    return SurfaceTextureSample(source, coordinate.xy / coordinate.w, bias);
}
#endif
hvec4 SurfaceTextureProj(sampler3D source, hvec4 coordinate)
{
    return SurfaceTextureSample(source, coordinate.xyz / coordinate.w);
}
hvec4 SurfaceTextureProjLod(sampler3D source, hvec4 coordinate, hfloat lod)
{
    return SurfaceTextureLod(source, coordinate.xyz / coordinate.w, lod);
}
hvec4 SurfaceTextureProjGrad(sampler3D source, hvec4 coordinate, hvec3 dx, hvec3 dy)
{
    return SurfaceTextureGrad(source, coordinate.xyz / coordinate.w, dx, dy);
}
#if defined(COMPILEPS)
hvec4 SurfaceTextureProj(sampler3D source, hvec4 coordinate, hfloat bias)
{
    return SurfaceTextureSample(source, coordinate.xyz / coordinate.w, bias);
}
#endif
#endif
