// NanoVG fill shader shared by offline precompilation and runtime compilation.
// The engine owns its cached program; NanoVG borrows it for each frame.

#include "varying_nanovg.def.sc"
#ifdef COMPILEVS
    $input a_position a_texcoord0
    $output v_position v_texcoord0
#endif
#ifdef COMPILEPS
    $input v_position v_texcoord0
#endif

#include "Common/common.sh"

#define EDGE_AA 1
#define NEED_HALF_TEXEL (BGFX_SHADER_LANGUAGE_HLSL > 0 && BGFX_SHADER_LANGUAGE_HLSL < 400)

uniform hvec4 u_viewSize;
uniform hvec4 u_viewOrigin;
uniform hmat3 u_scissorMat;
uniform hmat3 u_paintMat;
uniform hvec4 u_innerCol;
uniform hvec4 u_outerCol;
uniform hvec4 u_scissorExtScale;
uniform hvec4 u_extentRadius;
uniform hvec4 u_params;
#if NEED_HALF_TEXEL
uniform hvec4 u_halfTexel;
#endif // NEED_HALF_TEXEL

#define u_scissorExt   (u_scissorExtScale.xy)
#define u_scissorScale (u_scissorExtScale.zw)
#define u_extent       (u_extentRadius.xy)
#define u_radius       (u_extentRadius.z)
#define u_feather      (u_params.x)
#define u_strokeMult   (u_params.y)
#define u_texType      (u_params.z)
#define u_type         (u_params.w)

#ifdef COMPILEPS
// Match float texture sampling in offline HLSLcc and runtime SPIR-V compilation.
SAMPLER2D_PRECISION(s_tex, 0, highp);

hfloat sdroundrect(hvec2 pt, hvec2 ext, hfloat rad)
{
    hvec2 ext2 = ext - hvec2_init(rad, rad);
    hvec2 d = abs(pt) - ext2;
    return min(max(d.x, d.y), 0.0) + length(max(d, hvec2_init(0.0, 0.0))) - rad;
}

#ifdef GAUSSIAN_GLOW
// erf approximation (Abramowitz & Stegun 7.1.27): polynomial, no exp, no branches.
// Max abs error is about 3e-4. Gives a true Gaussian edge falloff for type 4.
hfloat nvgErf(hfloat x)
{
    hfloat s = sign(x);
    hfloat a = abs(x);
    hfloat v = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
    v *= v;
    return s - s / (v * v);
}
#endif // GAUSSIAN_GLOW

hfloat scissorMask(hvec2 p)
{
    hvec2 sc = abs(mul(u_scissorMat, hvec3_init(p, 1.0)).xy) - u_scissorExt;
    sc = hvec2_init(0.5, 0.5) - sc * u_scissorScale;
    return clamp(sc.x, 0.0, 1.0) * clamp(sc.y, 0.0, 1.0);
}

hfloat strokeMask(hvec2 _texcoord)
{
#if EDGE_AA
    return min(1.0, (1.0 - abs(_texcoord.x * 2.0 - 1.0)) * u_strokeMult) * min(1.0, _texcoord.y);
#else
    return 1.0;
#endif // EDGE_AA
}
#endif // COMPILEPS

void VS()
{
#if !NEED_HALF_TEXEL
    const hvec4 u_halfTexel = hvec4_init(0.0, 0.0, 0.0, 0.0);
#endif // !NEED_HALF_TEXEL

    v_position  = a_position;
    v_texcoord0 = a_texcoord0 + u_halfTexel.xy;
    gl_Position = hvec4_init(2.0 * (v_position.x - u_viewOrigin.x) / u_viewSize.x - 1.0, 1.0 - 2.0 * (v_position.y - u_viewOrigin.y) / u_viewSize.y, 0.0, 1.0);
    // Normalize offscreen output without changing logical paint or scissor coordinates.
    gl_Position.y *= 1.0 - 2.0 * u_viewSize.z;
}

void PS()
{
    hvec4 result = hvec4_init(0.0, 0.0, 0.0, 0.0);
    hfloat scissor = scissorMask(v_position);
    hfloat strokeAlpha = strokeMask(v_texcoord0);

#ifdef GAUSSIAN_GLOW
    hvec2 pt = mul(u_paintMat, hvec3_init(v_position, 1.0)).xy;
    hfloat dist = sdroundrect(pt, u_extent, u_radius);
    hfloat sigma = max(u_feather * 0.5, 0.001);
    hfloat d = 0.5 * (1.0 + nvgErf(dist / (1.4142135 * sigma)));
    result = mix(u_innerCol, u_outerCol, d) * (strokeAlpha * scissor);
#else
    BRANCH if (u_type == 0.0) // Gradient
    {
        hvec2 pt = mul(u_paintMat, hvec3_init(v_position, 1.0)).xy;
        hfloat d = clamp((sdroundrect(pt, u_extent, u_radius) + u_feather * 0.5) / u_feather, 0.0, 1.0);
        hvec4 color = mix(u_innerCol, u_outerCol, d);
        color *= strokeAlpha * scissor;
        result = color;
    }
    else BRANCH if (u_type == 1.0) // Image
    {
        hvec2 pt = mul(u_paintMat, hvec3_init(v_position, 1.0)).xy / u_extent;
        hvec4 color = texture2D(s_tex, pt);
        if (u_texType == 1.0) color = hvec4_init(color.xyz * color.w, color.w);
        if (u_texType == 2.0) color = color.xxxx;
        color *= u_innerCol;
        color *= strokeAlpha * scissor;
        result = color;
    }
    else BRANCH if (u_type == 2.0) // Stencil fill
    {
        result = hvec4_init(1.0, 1.0, 1.0, 1.0);
    }
    else BRANCH if (u_type == 3.0) // Textured tris
    {
        hvec4 color = texture2D(s_tex, v_texcoord0.xy);
        if (u_texType == 1.0) color = hvec4_init(color.xyz * color.w, color.w);
        if (u_texType == 2.0) color = color.xxxx;
        color *= scissor;
        result = color * u_innerCol;
    }
    else BRANCH if (u_type == 5.0 || u_type == 6.0) // 5 = multi-stop linear, 6 = multi-stop radial.
    {
        hvec2 pt = mul(u_paintMat, hvec3_init(v_position, 1.0)).xy;
        hfloat t = pt.x;
        bool valid = true;
        if (u_type == 6.0 && u_extent.x == 0.0 && u_extent.y == 0.0 && u_outerCol.r == 0.0)
            t = length(pt); // Concentric radial gradient with zero start radius.
        else if (u_type == 6.0)
        {
            // SVG 2 radial gradients: interpolate the start and end circles.
            // Solve |P - (F + t * (C - F))|^2 = (fr + t * (r - fr))^2.
            hvec2 focus = u_extent;
            hvec2 delta = pt - focus;
            hfloat fr = u_outerCol.r;
            hfloat dr = 1.0 - fr;
            hfloat a = dot(focus, focus) - dr * dr;
            hfloat b = -dot(delta, focus) + fr * dr;
            hfloat c = dot(delta, delta) - fr * fr;
            hfloat discriminant = b * b - a * c;
            if (a == 0.0)
            {
                valid = b != 0.0;
                t = valid ? c / (2.0 * b) : 0.0;
                valid = valid && fr + dr * t >= 0.0;
            }
            else
            {
                valid = discriminant >= 0.0;
                hfloat root = sqrt(max(0.0, discriminant));
                hfloat t0 = (b - root) / a;
                hfloat t1 = (b + root) / a;
                if (t0 > t1) { hfloat swap = t0; t0 = t1; t1 = swap; }
                t = fr + dr * t1 >= 0.0 ? t1 : t0;
                valid = valid && fr + dr * t >= 0.0;
            }
        }
        if (u_feather == 1.0) t = fract(t);
        else if (u_feather == 2.0) t = 1.0 - abs(mod(t, 2.0) - 1.0);
        else t = clamp(t, 0.0, 1.0);
        hfloat count = u_radius;
        // Upper bound preserves the last stop at coincident offsets, including hard stops.
        // Skia GrGradientShader.cpp uses the same interval-search approach.
        hfloat low = 0.0;
        hfloat high = count;
        for (int i = 0; i < 9; ++i)
        {
            if (low >= high) break;
            hfloat mid = floor((low + high) * 0.5);
            hfloat offset = texture2D(s_tex, hvec2_init((mid + 0.5) / count, 0.25)).r;
            if (t < offset) high = mid;
            else low = mid + 1.0;
        }
        hfloat first = max(0.0, low - 1.0);
        hfloat second = min(count - 1.0, low);
        hvec4 left = texture2D(s_tex, hvec2_init((first + 0.5) / count, 0.75));
        hvec4 right = texture2D(s_tex, hvec2_init((second + 0.5) / count, 0.75));
        hfloat begin = texture2D(s_tex, hvec2_init((first + 0.5) / count, 0.25)).r;
        hfloat end = texture2D(s_tex, hvec2_init((second + 0.5) / count, 0.25)).r;
        hfloat fraction = end > begin ? clamp((t - begin) / (end - begin), 0.0, 1.0) : 0.0;
        // Stop colors are cached in the requested interpolation space.
        hvec4 color = mix(left, right, fraction);
        if (u_outerCol.g != 0.0)
            color.rgb = toGamma(color.rgb);
        color.rgb *= color.a;
        result = valid ? color * u_innerCol * strokeAlpha * scissor : hvec4_init(0.0, 0.0, 0.0, 0.0);
    }

#endif // GAUSSIAN_GLOW

    gl_FragColor = result;
}
