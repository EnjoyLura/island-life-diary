#ifndef SURFACE_COVERAGE_HEADER
#define SURFACE_COVERAGE_HEADER

// Hash/edge equations adapted from Godot scene_forward_aa_inc.glsl (MIT).
// Godot's license is retained in engine/Source/Urho3D/Graphics/SurfaceShader/GodotFrontend/GODOT_LICENSE.txt.
#if COMPILEVS && defined(SURFACE_USES_ALPHA_HASH)
hvec3 SurfaceCoverageObjectPosition(hvec3 worldPosition, hmat4 modelMatrix)
{
    hvec3 origin = mul(hvec4_init(0.0, 0.0, 0.0, 1.0), modelMatrix).xyz;
    return mul(transpose(SurfaceGodotNormalMatrix(modelMatrix)), worldPosition - origin);
}
#endif

#ifdef SURFACE_VELOCITY_ONLY
uniform hmat4 u_UnjitteredViewProj;
uniform hmat4 u_PrevViewProj;
uniform hmat4 u_PrevModel;

#if COMPILEVS
void SurfaceCoverageVelocity(hvec4 currentClip, hvec4 previousClip)
{
    vSurfaceCurrClip = currentClip;
    vSurfacePrevClip = previousClip;
}
#else
vec2 SurfaceCoverageMotion()
{
    hvec2 motion = (vSurfaceCurrClip.xy / max(vSurfaceCurrClip.w, 1e-6)
        - vSurfacePrevClip.xy / max(vSurfacePrevClip.w, 1e-6)) * 0.5;
    #if !BGFX_SHADER_LANGUAGE_GLSL
        motion.y = -motion.y;
    #endif
    return clamp(motion, vec2_splat(-0.5), vec2_splat(0.5));
}
#endif
#endif

#if COMPILEPS
#ifdef SURFACE_USES_ALPHA_HASH
// Hash inputs and intermediates require FP32; FP16 loses the fractional entropy.
hfloat SurfaceHash2D(hvec2 p)
{
    return fract(1.0e4 * sin(17.0 * p.x + 0.1 * p.y) * (0.1 + abs(sin(13.0 * p.y + p.x))));
}
hfloat SurfaceHash3D(hvec3 p)
{
    return SurfaceHash2D(hvec2_init(SurfaceHash2D(p.xy), p.z));
}
hfloat SurfaceAlphaHashThreshold(hvec3 position, hfloat hashScale)
{
    hfloat footprint = max(length(dFdx(position)), length(dFdy(position)));
    if (footprint < 1e-8)
        return 0.5;
    hfloat logScale = clamp(log2(1.0 / max(max(hashScale, 0.0) * footprint, 1e-8)), -16.0, 16.0);
    hvec2 scales = exp2(hvec2_init(floor(logScale), ceil(logScale)));
    hvec2 thresholds = hvec2_init(SurfaceHash3D(floor(scales.x * position)), SurfaceHash3D(floor(scales.y * position)));
    hfloat blend = fract(logScale);
    hfloat threshold = mix(thresholds.x, thresholds.y, blend);
    hfloat a = min(blend, 1.0 - blend);
    if (a > 1e-5)
    {
        if (threshold < a)
            threshold = threshold * threshold / (2.0 * a * (1.0 - a));
        else if (threshold < 1.0 - a)
            threshold = (threshold - 0.5 * a) / (1.0 - a);
        else
            threshold = 1.0 - (1.0 - threshold) * (1.0 - threshold) / (2.0 * a * (1.0 - a));
    }
    return clamp(threshold, 0.00001, 1.0);
}
#endif

#ifdef SURFACE_ALPHA_TO_COVERAGE
float SurfaceAlphaEdge(float alpha, vec2 texelCoordinate, float edge)
{
    vec2 dx = dFdx(texelCoordinate);
    vec2 dy = dFdy(texelCoordinate);
    float mip = max(0.0, 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-8)));
    alpha *= 1.0 + mip * 0.25;
    return clamp((alpha - edge) / max(fwidth(alpha), 0.0001) + 0.5, 0.0, 1.0);
}
#endif

void SurfaceAdditionalCoverage(inout float alpha, float scissorThreshold, float hashScale, float edge, vec2 texelCoordinate)
{
    #ifdef SURFACE_USES_ALPHA_HASH
        if (alpha < SurfaceAlphaHashThreshold(vSurfaceHashPosition, hashScale))
            discard;
    #endif
    #ifdef SURFACE_ALPHA_TO_COVERAGE
        #ifdef SURFACE_ALPHA_ANTIALIASING_EDGE
            #ifdef SURFACE_USES_ALPHA_SCISSOR
                edge = clamp(scissorThreshold + edge, 0.0, 1.0);
            #endif
            alpha = SurfaceAlphaEdge(alpha, texelCoordinate, edge);
        #endif
        #if defined(SURFACE_SHADOW_ONLY) || defined(MATERIALBAKE)
            if (alpha < 0.5)
                discard;
        #endif
    #elif defined(SURFACE_USES_ALPHA_HASH)
        alpha = 1.0;
    #endif
}
#endif
#endif
