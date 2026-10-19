// UE real-time sky capture cloud branch: unjittered reflection rays and capture-owned 360 aerial perspective.
#include "EnvBake/varying_envbake.def.sc"
$input v_texcoord0
#include "Common/common.sh"
#include "uniforms.sh"
#include "ScreenSpace/ScreenSpaceCommon.sh"
#include "Volumetric/VolumetricCloudTrace.sh"
#include "Sky/SkyAtmosphereCaptureCommon.sh"

uniform hvec4 u_EnvBakeFace;

void main()
{
    hvec3 direction = normalize(AtmosphereCaptureDirection(int(u_EnvBakeFace.x), v_texcoord0));
    hvec4 color, nearestColor, debug;
    hfloat representativeDepth;
    bool minMaxApplied;
    TraceVolumetricCloud(u_CloudCamera.xyz, direction, 65504000.0, 65504000.0, 65504000.0,
        v_texcoord0, 0.5, color, nearestColor, representativeDepth, minMaxApplied, debug);
    gl_FragColor = hvec4_init(color.rgb, 1.0 - color.a);
}
