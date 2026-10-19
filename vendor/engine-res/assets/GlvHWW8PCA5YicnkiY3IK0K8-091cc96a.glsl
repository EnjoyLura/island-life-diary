#include "EnvBake/varying_envbake.def.sc"
$input v_texcoord0

#include "Common/common.sh"

SAMPLERCUBE(s_tex0, 0);
uniform hvec4 u_EnvBakeParams;
uniform hvec4 u_EnvBakeFace; // x=faceIndex, y=RGBM output (range 6)

hfloat ReflectionRadicalInverse(uint bits)
{
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    hfloat reversed = hfloat_init(bits);
    return reversed * 2.3283064365386963e-10;
}

hvec3 ReflectionCubeVector(int face, hvec2 uv)
{
    hvec2 p = uv * 2.0 - 1.0;
    if (face == 0) return hvec3_init(1.0, -p.y, -p.x);
    if (face == 1) return hvec3_init(-1.0, -p.y, p.x);
    if (face == 2) return hvec3_init(p.x, 1.0, p.y);
    if (face == 3) return hvec3_init(p.x, -1.0, -p.y);
    if (face == 4) return hvec3_init(p.x, -p.y, 1.0);
    return hvec3_init(-p.x, -p.y, -1.0);
}

void main()
{
    hvec3 n = normalize(ReflectionCubeVector(int(u_EnvBakeFace.x), v_texcoord0));
    hfloat roughness = u_EnvBakeParams.x;
    hvec4 result = hvec4_init(0.0, 0.0, 0.0, 0.0);
    if (roughness < 0.01)
        result = textureCubeLod(s_tex0, n, 0.0);
    else
    {
        // UE's Duff basis and source-texel solid-angle bias are part of the asset version.
        hfloat basisSign = n.z >= 0.0 ? 1.0 : -1.0;
        hfloat a = -1.0 / (basisSign + n.z);
        hfloat b = n.x * n.y * a;
        hvec3 tangentX = hvec3_init(1.0 + basisSign * a * n.x * n.x, basisSign * b, -basisSign * n.x);
        hvec3 tangentY = hvec3_init(b, basisSign + a * n.y * n.y, -n.y);
        hfloat a2 = roughness * roughness * roughness * roughness;
        hfloat solidAngle = 8.0 * 3.14159265 / (6.0 * u_EnvBakeParams.w * u_EnvBakeParams.w);
        hfloat weight = 0.0;
        int samples = int(u_EnvBakeParams.z);
        for (int i = 0; i < samples; ++i)
        {
            hfloat phi = 2.0 * 3.14159265 * hfloat_init(i) / hfloat_init(samples);
            hfloat e = ReflectionRadicalInverse(uint(i)) * (roughness > 0.99 ? 1.0 : 0.995);
            hfloat cosTheta = sqrt(roughness > 0.99 ? e : (1.0 - e) / (1.0 + (a2 - 1.0) * e));
            hfloat sinTheta = sqrt(max(1.0 - cosTheta * cosTheta, 0.0));
            hvec3 l = hvec3_init(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
            hfloat pdf;
            hfloat sampleWeight;
            if (roughness > 0.99)
            {
                pdf = l.z / 3.14159265;
                sampleWeight = 1.0;
            }
            else
            {
                hfloat d = (cosTheta * a2 - cosTheta) * cosTheta + 1.0;
                pdf = a2 / (4.0 * 3.14159265 * d * d);
                l = 2.0 * cosTheta * l - hvec3_init(0.0, 0.0, 1.0);
                sampleWeight = max(l.z, 0.0);
            }
            if (sampleWeight > 0.0)
            {
                hfloat lod = pdf > 0.0 ? 0.5 * log2(1.0 / (hfloat_init(samples) * pdf * solidAngle)) :
                    log2(u_EnvBakeParams.w);
                result += textureCubeLod(s_tex0, tangentX * l.x + tangentY * l.y + n * l.z, lod) * sampleWeight;
                weight += sampleWeight;
            }
        }
        result /= max(weight, 0.000001);
    }
    result = clamp(result, hvec4_init(0.0, 0.0, 0.0, 0.0), hvec4_init(65504.0, 65504.0, 65504.0, 1.0));
    if (result.a < 0.00000003)
        result = hvec4_init(0.0, 0.0, 0.0, 0.0);
    if (u_EnvBakeFace.y > 0.5)
    {
        // Encode only the filtered result; convolution and diffuse SH use the linear HDR source.
        hvec3 rgb = min(result.rgb, hvec3_init(6.0, 6.0, 6.0));
        hfloat multiplier = ceil(max(max(rgb.r, max(rgb.g, rgb.b)) / 6.0, 1.0 / 255.0) * 255.0) / 255.0;
        result = hvec4_init(rgb / (multiplier * 6.0), multiplier);
    }
    gl_FragColor = result;
}
