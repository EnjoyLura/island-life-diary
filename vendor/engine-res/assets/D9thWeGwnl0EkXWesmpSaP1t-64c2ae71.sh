// Depth and attachment helpers shared by UE Mode 0 cloud passes.
#ifndef VOLUMETRIC_CLOUD_DEPTH_COMMON_SH
#define VOLUMETRIC_CLOUD_DEPTH_COMMON_SH

uniform hvec4 u_CloudDepthProjection;

/// Return the physical attachment size, including rounded viewport borders.
hvec2 CloudTextureSize(sampler2D source)
{
#if BGFX_SHADER_DIALECT_HLSL > 300
    uint width, height;
    source.m_texture.GetDimensions(width, height);
    return hvec2_init(width, height);
#else
    return hvec2_init(textureSize(source, 0));
#endif
}

/// Clamp integer loads to the valid extent, including negative neighbor offsets.
hvec4 CloudLoad(sampler2D source, hvec2 pixel)
{
    hvec2 size = CloudTextureSize(source);
    return texture2DLod(source, (clamp(floor(pixel), hvec2_init(0.0, 0.0), size - 1.0) + 0.5) / size, 0.0);
}

/// Match UE's bounded sky distance with the engine's finite-far projection.
hfloat CloudViewDepth(hfloat deviceZ)
{
    if (IsSceneFarDepth(deviceZ, 1e-12))
        return 65504000.0;
#if BGFX_SHADER_LANGUAGE_GLSL
    deviceZ = deviceZ * 2.0 - 1.0;
#endif
    return (u_CloudDepthProjection.y - deviceZ * u_CloudDepthProjection.w) /
        (deviceZ * u_CloudDepthProjection.z - u_CloudDepthProjection.x);
}

/// Project the representative cloud distance as view Z, as in UE's reconstruction approximation.
hfloat CloudDeviceDepth(hfloat viewZ)
{
    hfloat clipZ = u_CloudDepthProjection.x * viewZ + u_CloudDepthProjection.y;
    hfloat clipW = u_CloudDepthProjection.z * viewZ + u_CloudDepthProjection.w;
    hfloat deviceZ = clipZ / clipW;
#if BGFX_SHADER_LANGUAGE_GLSL
    deviceZ = deviceZ * 0.5 + 0.5;
#endif
    return deviceZ;
}

#endif
