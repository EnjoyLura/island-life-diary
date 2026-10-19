// UE DownsampleDepthPixelShader: checkerboard half depth, then quarter min/max.
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
#include "ScreenSpace/ScreenSpaceCommon.sh"
#ifdef COMPILEPS
SAMPLER2D(u_CloudSourceDepth0, 0);
#include "Volumetric/VolumetricCloudDepthCommon.sh"
#endif

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    gl_Position = GetClipPos(GetWorldPos(modelMatrix));
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS
void PS()
{
    hvec2 size = CloudTextureSize(u_CloudSourceDepth0);
    hvec2 pixel = floor(vTexCoord * ceil(size * 0.5));
    hfloat z0 = CloudLoad(u_CloudSourceDepth0, pixel * 2.0).r;
    hfloat z1 = CloudLoad(u_CloudSourceDepth0, pixel * 2.0 + hvec2_init(0.0, 1.0)).r;
    hfloat z2 = CloudLoad(u_CloudSourceDepth0, pixel * 2.0 + hvec2_init(1.0, 1.0)).r;
    hfloat z3 = CloudLoad(u_CloudSourceDepth0, pixel * 2.0 + hvec2_init(1.0, 0.0)).r;
    hfloat minZ = min(min(z0, z1), min(z2, z3));
    hfloat maxZ = max(max(z0, z1), max(z2, z3));
#ifdef CLOUD_DEPTH_MINMAX
    gl_FragColor = hvec4_init(minZ, maxZ, 0.0, 0.0);
#else
    hfloat parity = mod(pixel.x + pixel.y, 2.0);
    gl_FragColor = hvec4_init(parity > 0.0 ? maxZ : minZ, 0.0, 0.0, 0.0);
#endif
}
#endif
