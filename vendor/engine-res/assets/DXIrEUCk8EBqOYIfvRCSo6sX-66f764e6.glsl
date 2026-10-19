#include "varying_spine.def.sc"
#ifdef COMPILEVS
    $input a_position a_texcoord0 a_color0 a_color1
    $output vTexCoord vColor vDarkColor vScreenPos
#endif
#ifdef COMPILEPS
    $input vTexCoord vColor vDarkColor vScreenPos
#endif

#include "Common/common.sh"

// Preserve subpixel canvas and scissor coordinates on mobile; colors may use half precision.
uniform hvec4 u_viewSize;
uniform hvec4 u_viewOrigin;
uniform hmat3 u_scissorMat;
uniform hvec4 u_scissorExtScale;
uniform vec4 u_spineParams;

#define u_scissorExt   (u_scissorExtScale.xy)
#define u_scissorScale (u_scissorExtScale.zw)
#define u_isPMA        (u_spineParams.x)
#define u_darkAlphaAdd (u_spineParams.y)

#ifdef COMPILEPS
SAMPLER2D(s_tex, 0);

hfloat scissorMask(hvec2 p)
{
    hvec2 sc = abs(mul(u_scissorMat, hvec3_init(p, 1.0)).xy) - u_scissorExt;
    sc = hvec2_init(0.5, 0.5) - sc * u_scissorScale;
    return clamp(sc.x, 0.0, 1.0) * clamp(sc.y, 0.0, 1.0);
}
#endif

void VS()
{
    gl_Position = hvec4_init(
        2.0 * (a_position.x - u_viewOrigin.x) / u_viewSize.x - 1.0,
        1.0 - 2.0 * (a_position.y - u_viewOrigin.y) / u_viewSize.y,
        0.0, 1.0);
    // Share NanoVG's offscreen projection; scissor coordinates stay in logical canvas space.
    gl_Position.y *= 1.0 - 2.0 * u_viewSize.z;
    vTexCoord  = a_texcoord0;
    vColor     = a_color0;
    vDarkColor = a_color1;
    vScreenPos = hvec4_init(a_position.xy, 0.0, 0.0);
}

void PS()
{
    hfloat scissor = scissorMask(vScreenPos.xy);
    vec4 texColor = texture2D(s_tex, vTexCoord);

#ifdef TINTBLACK
    float a = texColor.a * vColor.a;

    // PMA: darkFactor = texColor.a - texColor.rgb; straight: darkFactor = 1.0 - texColor.rgb
    vec3 darkFactor = mix(vec3_splat(1.0), vec3_splat(texColor.a), u_isPMA) - texColor.rgb;
    vec3 lightColor = texColor.rgb * vColor.rgb;
    vec3 darkColor  = darkFactor * vDarkColor.rgb;
    gl_FragColor = vec4(lightColor + darkColor, a);

    // straight alpha 输入时 shader 手动预乘（blend mode 统一 PMA: One, InvSrcAlpha）
    if (u_isPMA < 0.5)
        gl_FragColor.rgb *= texColor.a;

    // additive 混合时 darkColor.a 控制 alpha 衰减
    if (u_darkAlphaAdd > 0.5)
        gl_FragColor.a = a * (1.0 - vDarkColor.a);
#else
    gl_FragColor = texColor * vColor;
#endif

    gl_FragColor *= scissor;
}
