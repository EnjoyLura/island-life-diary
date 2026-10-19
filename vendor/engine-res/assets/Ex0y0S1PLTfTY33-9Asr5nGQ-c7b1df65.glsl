// UE cloud shadow 2 x 2 spatial downsample.
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
    hvec2 step = hvec2_init(u_CloudShadowFilterParams.y, u_CloudShadowFilterParams.y) * 0.5;
    hvec3 a = texture2DLod(u_CloudShadow0, vTexCoord + step * hvec2_init(-1.0, -1.0), 0.0).rgb;
    hvec3 b = texture2DLod(u_CloudShadow0, vTexCoord + step * hvec2_init( 1.0, -1.0), 0.0).rgb;
    hvec3 c = texture2DLod(u_CloudShadow0, vTexCoord + step * hvec2_init( 1.0,  1.0), 0.0).rgb;
    hvec3 d = texture2DLod(u_CloudShadow0, vTexCoord + step * hvec2_init(-1.0,  1.0), 0.0).rgb;
    // Preserve UE MainShadowFilterCS's sum/deviation expression, including its unnormalized Mean.
    hfloat mean = a.r + b.r + c.r + d.r;
    hfloat deviation = (abs(a.r - mean) + abs(b.r - mean) + abs(c.r - mean) + abs(d.r - mean)) * 0.25;
    gl_FragColor = hvec4_init(mean - deviation, (a.gb + b.gb + c.gb + d.gb) * 0.25, 1.0);
}
#endif
