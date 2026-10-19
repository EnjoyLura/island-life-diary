// UE direct sky integration, unexposed and without the solar disk in reflection captures.
#include "EnvBake/varying_envbake.def.sc"
$input v_texcoord0
#include "Common/common.sh"
#include "Sky/SkyAtmosphereIntegration.sh"

uniform hvec4 u_EnvBakeFace;
uniform hvec4 u_AtmosphereCaptureOrigin;
uniform hvec4 u_AtmosphereCaptureSampling;

#include "Sky/SkyAtmosphereCaptureCommon.sh"

void main()
{
    ATMOSPHERE_GEOMETRY_PRECISE hvec3 direction = normalize(AtmosphereCaptureDirection(int(u_EnvBakeFace.x), v_texcoord0));
    ATMOSPHERE_GEOMETRY_PRECISE hvec3 origin = u_AtmosphereCaptureOrigin.xyz;
    hfloat height = length(origin);
    origin = (height > 0.0 ? origin / height : hvec3_init(0.0, 1.0, 0.0)) * max(height, u_AtmosphereRadii.x + 0.005);
    if (!AtmosphereMoveToTop(origin, direction))
    {
        gl_FragColor = hvec4_init(0.0, 0.0, 0.0, 1.0);
        return;
    }
    origin += direction * u_AtmosphereCaptureOrigin.w;
    AtmosphereIntegral integral = IntegrateAtmosphere(origin, direction, false, true, 0.0,
        true, u_AtmosphereCaptureSampling.x, u_AtmosphereCaptureSampling.y, u_AtmosphereCaptureSampling.z,
        u_AtmosphereLightDirection0.xyz, u_AtmosphereLightDirection1.xyz,
        u_AtmosphereLightColor0.rgb, u_AtmosphereLightColor1.rgb, 1.0, 9000000.0, 0.3);
    gl_FragColor = hvec4_init(integral.luminance * u_AtmosphereSky.rgb, 1.0);
}
