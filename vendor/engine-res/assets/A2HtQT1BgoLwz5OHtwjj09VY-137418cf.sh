#ifndef MATERIAL_ANISOTROPY_SH
#define MATERIAL_ANISOTROPY_SH

// Explicit-basis API: signed strength, perceptual roughness squared for GGX.
// The original USES_ANISOTROPY scalar-only API retains its material mapping.
void GetMaterialAnisotropyBasis(vec3 normal, vec3 tangent, vec3 binormal, vec2 flow,
    out vec3 axisT, out vec3 axisB)
{
    vec3 N = normalize(normal);
    vec3 T = tangent - N * dot(N, tangent);
    if (dot(T, T) < 1e-8)
        T = cross(abs(N.z) < 0.9 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0), N);
    T = normalize(T);
    vec3 B = cross(N, T);
    if (dot(B, binormal) < 0.0)
        B = -B;
    vec2 f = dot(flow, flow) > 1e-8 ? normalize(flow) : vec2(1.0, 0.0);
    axisT = T * f.x + B * f.y;
    axisB = -T * f.y + B * f.x;
}

void GetMaterialAnisotropicRoughness(float alpha, float strength, out float ax, out float ay)
{
    float aspect = sqrt(1.0 - 0.9 * clamp(strength, -1.0, 1.0));
    alpha = max(alpha, 0.002);
    ax = max(alpha / aspect, 0.001);
    ay = max(alpha * aspect, 0.001);
}

// Evaluate the distribution and visibility in full precision on mobile too.
// The normalized form avoids the legacy ax*ay squared intermediate underflow.
hfloat GetMaterialAnisotropicDistribution(hfloat ax, hfloat ay, hfloat NoH, hfloat XoH, hfloat YoH)
{
    hvec3 q = hvec3_init(XoH / ax, YoH / ay, NoH);
    hfloat d = dot(q, q);
    return 1.0 / max(M_PI * ax * ay * d * d, 1e-20);
}

hfloat GetMaterialAnisotropicVisibility(hfloat ax, hfloat ay, hfloat NoV, hfloat NoL,
    hfloat XoV, hfloat XoL, hfloat YoV, hfloat YoL)
{
    hfloat v = NoL * length(hvec3_init(ax * XoV, ay * YoV, NoV));
    hfloat l = NoV * length(hvec3_init(ax * XoL, ay * YoL, NoL));
    return 0.5 / max(v + l, 1e-8);
}

vec3 GetMaterialAnisotropicIBLNormal(vec3 normal, vec3 view, float roughness, float strength,
    vec3 axisT, vec3 axisB)
{
    vec3 axis = strength >= 0.0 ? axisB : axisT;
    vec3 bent = cross(cross(axis, view), axis);
    bent = mix(normal, bent, min(abs(strength), 1.0) * clamp(5.0 * roughness, 0.0, 1.0));
    return dot(bent, bent) > 1e-8 ? normalize(bent) : normal;
}
#endif
