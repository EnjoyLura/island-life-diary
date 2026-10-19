// Fixed renderer-owned volumetric cloud evaluator.
// This shader is deliberately a cloud-domain pass and does not use SurfaceShader ABI.
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
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "ScreenSpace/ScreenSpaceCommon.sh"

#ifdef COMPILEPS
#include "Volumetric/VolumetricCloudTrace.sh"

#ifdef CLOUD_MRT
#define WRITE_CLOUD_RESULT(scattering, transmittance, frontDepth) \
    gl_FragData[0] = hvec4_init(scattering, 1.0); \
    gl_FragData[1] = hvec4_init(transmittance, transmittance, transmittance, 1.0); \
    gl_FragData[2] = hvec4_init(frontDepth, 0.0, 0.0, 1.0); \
    gl_FragData[3] = hvec4_init(1.0 - transmittance, 0.0, 0.0, 1.0)
#else
#define WRITE_CLOUD_RESULT(scattering, transmittance, frontDepth) \
    gl_FragColor = hvec4_init(scattering, 1.0 - transmittance)
#endif
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
#ifdef CLOUD_SHADOW
    // UE SHADER_SHADOW_PS: march from the orthographic near plane toward the surface.
    hvec4 origin4 = mul(hvec4_init(CloudShadowUVToClip(vTexCoord), 1.0, 1.0), u_CloudShadowInvViewProj);
    hvec3 origin = origin4.xyz / origin4.w;
    hvec3 direction = u_CloudShadowDirection.xyz;
    hfloat topNear;
    hfloat topFar;
    if (!IntersectCloudSphere(origin, direction, u_CloudPlanetCenter.xyz, u_CloudLayerRadii.y, topNear, topFar))
    {
        gl_FragColor = hvec4_init(u_CloudShadowParams.x, 0.0, 0.0, 1.0);
        return;
    }
    hfloat begin = topNear;
    hfloat end = topFar;
    hfloat bottomNear;
    hfloat bottomFar;
    if (IntersectCloudSphere(origin, direction, u_CloudPlanetCenter.xyz, u_CloudLayerRadii.x, bottomNear, bottomFar))
    {
        if (bottomNear <= 0.0 || bottomFar <= 0.0)
        {
            gl_FragColor = hvec4_init(0.0, 0.0, 0.0, 1.0);
            return;
        }
        begin = max(0.0, topNear);
        end = bottomNear;
    }
    begin = max(0.0, begin);
    end = max(0.0, end);
    hfloat stepLength = (end - begin) / u_CloudShadowParams.w;
    hfloat firstHit = u_CloudShadowParams.x * 1000.0;
    hfloat extinctionSum = 0.0;
    hfloat opticalDepth = 0.0;
    hfloat nonemptyCount = 0.0;
    LOOP for (hfloat i = 0.5; i < u_CloudShadowParams.w; i += 1.0)
    {
        hfloat distance = i * stepLength;
        hvec3 position = origin + direction * (begin + distance);
        CLOUD_GEOMETRY_PRECISE hfloat height = (length(position - u_CloudPlanetCenter.xyz) - u_CloudLayerRadii.x) /
            (u_CloudLayerRadii.y - u_CloudLayerRadii.x);
        hfloat extinction = CloudDensity(position, height);
        if (extinction > 0.0)
        {
            firstHit = min(firstHit, distance);
            nonemptyCount += 1.0;
        }
        extinctionSum += extinction;
        opticalDepth += extinction * stepLength;
    }
    hfloat front = nonemptyCount > 0.0 ? (begin + firstHit) * 0.001 : end * 0.001;
    gl_FragColor = hvec4_init(max(0.0, front + u_CloudShadowParams.z),
        u_CloudShadowParams.y * extinctionSum / max(1.0, nonemptyCount),
        u_CloudShadowParams.y * opticalDepth, 1.0);
#else
    hvec2 uv = vTexCoord;
    hfloat rawDepth = texture2D(u_DepthBuffer0, uv).r;
    hvec3 cameraPosition = u_CloudCamera.xyz;
    hvec3 rayDirection;
    hfloat sceneDistance = 65504000.0;

    if (IsSceneFarDepth(rawDepth, 0.00001))
    {
        hvec4 farWorld = ReconstructCloudWorldPosition(uv, rawDepth);
        rayDirection = normalize(farWorld.xyz - cameraPosition);
    }
    else
    {
        hvec4 sceneWorld = ReconstructCloudWorldPosition(uv, rawDepth);
        hvec3 sceneRay = sceneWorld.xyz - cameraPosition;
        sceneDistance = length(sceneRay);
        if (sceneDistance <= 0.0001)
        {
            WRITE_CLOUD_RESULT(hvec3_init(0.0, 0.0, 0.0), 1.0, 1.0);
            return;
        }
        rayDirection = sceneRay / sceneDistance;
    }

    hvec4 farResult, nearResult, debug;
    hfloat representativeDepth;
    bool minMaxApplied;
    TraceVolumetricCloud(cameraPosition, rayDirection, sceneDistance, sceneDistance, sceneDistance, uv,
        CloudRayJitter(uv), farResult, nearResult, representativeDepth, minMaxApplied, debug);
    WRITE_CLOUD_RESULT(farResult.rgb, farResult.a, debug.y * 1000.0 / cFarClipPS);
#ifdef CLOUD_MRT
    gl_FragData[0].a = representativeDepth * 1000.0 / cFarClipPS;
    gl_FragData[3] = debug;
#endif
#endif
}
#endif
