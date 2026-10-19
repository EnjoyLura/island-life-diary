// UE VolumetricRenderTarget default upsampling mode 4 (opaque composition).
// The scene color input is already fogged. Cloud radiance is integrated along
// the view ray; composition is radiance + scene * transmittance.
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
SAMPLER2D(u_SceneColor0, 0);
SAMPLER2D(u_CloudColor1, 1);
SAMPLER2D(u_CloudDepth2, 2);
SAMPLER2D(u_SceneDepth3, 3);
uniform hvec2 u_CameraJitterOffset;
uniform hvec4 u_CloudReconstructSize;
#include "Volumetric/VolumetricCloudDepthCommon.sh"
#include "Volumetric/VolumetricCloudFog.sh"
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
    hvec2 pixel = floor(vTexCoord * u_CloudReconstructSize.zw);
    hvec2 uv = (pixel + 0.5) / u_CloudReconstructSize.zw;
    hfloat rawDepth = texture2DLod(u_SceneDepth3, uv, 0.0).r;
    hvec2 jitter = u_CameraJitterOffset;
#if !BGFX_SHADER_LANGUAGE_GLSL
    jitter.y = -jitter.y;
#endif
    hvec4 ray = mul(ScreenUVToClip(uv - jitter, 0.5), u_UnjitteredProjInv);
    hfloat distanceKm = min(CloudViewDepth(rawDepth) * length(ray.xyz) / abs(ray.z) * 0.001, 65504.0);
    hvec2 center = floor(pixel * 0.5);
    hvec2 offset = (pixel - center * 2.0) * 2.0 - 1.0;
    hvec2 coord[4];
    coord[0] = center;
    coord[1] = center + hvec2_init(offset.x, 0.0);
    coord[2] = center + offset;
    coord[3] = center + hvec2_init(0.0, offset.y);
    hvec4 sceneDepths = hvec4_init(CloudLoad(u_CloudDepth2, coord[0]).g,
        CloudLoad(u_CloudDepth2, coord[1]).g, CloudLoad(u_CloudDepth2, coord[2]).g,
        CloudLoad(u_CloudDepth2, coord[3]).g);
    distanceKm = min(distanceKm, max(max(sceneDepths.x, sceneDepths.y), max(sceneDepths.z, sceneDepths.w)));
    hvec4 delta = abs(sceneDepths - distanceKm);
    hvec4 cloud;
    if (max(max(delta.x, delta.y), max(delta.z, delta.w)) > distanceKm * 0.1)
    {
        hvec4 weights = 1.0 / (delta * 1000.0 + 1.0);
        weights /= dot(weights, hvec4_init(1.0, 1.0, 1.0, 1.0));
        hvec2 size = CloudTextureSize(u_CloudColor1);
        cloud = hvec4_init(0.0, 0.0, 0.0, 0.0);
        for (int i = 0; i < 4; ++i)
        {
            hvec2 validCoord = clamp(coord[i], hvec2_init(0.0, 0.0), size - 1.0);
            hvec4 sampleCloud = ApplyCloudForegroundFog(validCoord / size,
                CloudLoad(u_CloudDepth2, coord[i]).r, CloudLoad(u_CloudColor1, coord[i]));
            cloud += sampleCloud * weights[i];
        }
    }
    else
    {
        hvec2 size = CloudTextureSize(u_CloudColor1);
        hvec2 sampleUv = (center + 0.25 + (offset * 0.5 + 0.5) * 0.5) / size;
        cloud = texture2DLod(u_CloudColor1, clamp(sampleUv, 0.5 / size, 1.0 - 0.5 / size), 0.0);
        hfloat cloudDepth = texture2DLod(u_CloudDepth2, clamp(sampleUv, 0.5 / size, 1.0 - 0.5 / size), 0.0).r;
        cloud = ApplyCloudForegroundFog(sampleUv, cloudDepth, cloud);
    }
    hvec3 scene = texture2DLod(u_SceneColor0, uv, 0.0).rgb;
    gl_FragColor = hvec4_init(cloud.rgb + scene * cloud.a, 1.0);
}
#endif
