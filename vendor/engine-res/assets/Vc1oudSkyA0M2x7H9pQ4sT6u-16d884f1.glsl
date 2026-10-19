// UE world-space cloud Sky AO hemisphere filter.
#include "varying_quad.def.sc"
#include "urho3d_compatibility.sh"

#ifdef COMPILEVS
    $input a_position
    $output vTexCoord, vScreenPos
#endif
#ifdef COMPILEPS
    $input vTexCoord, vScreenPos
#endif

#include "Common/common.sh"
#include "uniforms.sh"
#include "transform.sh"
#include "screen_pos.sh"

#ifdef COMPILEPS
SAMPLER2D(u_CloudShadow0, 0);
uniform hvec4 u_CloudShadowFilterParams;
#endif

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS
void PS()
{
    // UE PERMUTATION_SKYAO: its active 4 x 4 loop integrates hemisphere visibility.
    // Preserve the source's 0.125 starting index and aperture mapping, despite its "64 samples" comment.
    hvec3 sum = hvec3_init(0.0, 0.0, 0.0);
    hfloat transmittance = 0.0;
    LOOP for (int u = 0; u < 4; ++u)
    {
        LOOP for (int v = 0; v < 4; ++v)
        {
            hfloat phi = 6.28318530718 * ((hfloat_init(u) + 0.125) * 0.25);
            hfloat cosine = 1.0 - u_CloudShadowFilterParams.w + u_CloudShadowFilterParams.w * ((hfloat_init(v) + 0.125) * 0.25);
            hfloat sine = sqrt(saturate(1.0 - cosine * cosine));
            hvec2 offset = hvec2_init(cos(phi), sin(phi)) * sine * u_CloudShadowFilterParams.z / max(cosine, 0.0000001);
            hvec3 data = texture2DLod(u_CloudShadow0, vTexCoord + offset, 0.0).rgb;
            sum += data;
            transmittance += exp(-data.b);
        }
    }
    gl_FragColor = hvec4_init(sum.rg * 0.0625, transmittance > 0.0 ? -log(transmittance * 0.0625) : 100.0, 1.0);
}
#endif
