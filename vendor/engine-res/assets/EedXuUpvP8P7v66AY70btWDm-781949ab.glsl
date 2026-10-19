#include "varying_deferred.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
    $input a_position
    $output vScreenPos, vFarRay
#endif
#ifdef COMPILEPS
    $input vScreenPos, vFarRay
#endif
#include "Common/common.sh"
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    gl_Position = GetClipPos(GetWorldPos(modelMatrix));
    vScreenPos = hvec4_init(GetScreenPosPreDiv(gl_Position), 0.0, 1.0);
    vFarRay = GetFarRay(gl_Position);
}

#ifdef COMPILEPS
SAMPLER2D(u_CaptureColor0, 0);
SAMPLER2D(u_CaptureDepth1, 1);
#endif

void PS()
{
    hfloat depth = ReconstructDepth(texture2D(u_CaptureDepth1, vScreenPos.xy).r);
    hvec3 hitPosition = vFarRay * depth;
    hfloat radialDistance = sqrt(dot(hitPosition, hitPosition));
    hfloat coverage = 1.0 - smoothstep(cFarClipPS * 0.8, cFarClipPS, radialDistance);
    hvec3 radiance = clamp(texture2D(u_CaptureColor0, vScreenPos.xy).rgb,
        hvec3_init(0.0, 0.0, 0.0), hvec3_init(65504.0, 65504.0, 65504.0));
    gl_FragColor = hvec4_init(radiance * coverage, coverage);
}
