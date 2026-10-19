// UE Mode 0 reconstruction with min/max depth, new subpixels and reprojected history.
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
SAMPLER2D(u_CloudColor0, 0);
SAMPLER2D(u_CloudSecondary1, 1);
SAMPLER2D(u_CloudDepth2, 2);
SAMPLER2D(u_CloudHistoryColor3, 3);
SAMPLER2D(u_CloudHistoryDepth4, 4);
SAMPLER2D(u_CloudHalfDepth5, 5);
uniform hvec4 u_CloudTemporalParams;
uniform hvec4 u_CloudReconstructSize;
uniform hmat4 u_CameraClipToPrevClip;
#include "Volumetric/VolumetricCloudDepthCommon.sh"

hvec4 CloudSample(sampler2D source, hvec2 uv)
{
    hvec2 halfTexel = 0.5 / CloudTextureSize(source);
    return texture2DLod(source, clamp(uv, halfTexel, 1.0 - halfTexel), 0.0);
}
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
    hvec2 size = u_CloudReconstructSize.xy;
    hvec2 pixel = floor(vTexCoord * size);
    hvec2 uv = (pixel + 0.5) / size;
    hvec2 center = floor(pixel * 0.5);
    hvec4 newColor = CloudLoad(u_CloudColor0, center);
    hvec4 newDepth = CloudLoad(u_CloudDepth2, center);
    hvec4 color = CloudSample(u_CloudColor0, uv);
    hvec2 depth = CloudSample(u_CloudDepth2, uv).rg;
    if (u_CloudTemporalParams.x > 0.5 && u_ViewHistory.y > 0.5)
    {
        bool useNew = all(equal(pixel - center * 2.0, u_CloudTemporalParams.yz));
        hvec4 currentClip = ScreenUVToClip(uv, CloudDeviceDepth(newDepth.x * 1000.0));
        hvec4 previousClip = mul(currentClip, u_CameraClipToPrevClip);
        hvec2 previousUv = previousClip.xy / previousClip.w * 0.5 + 0.5;
#if !BGFX_SHADER_LANGUAGE_GLSL
        previousUv.y = 1.0 - previousUv.y;
#endif
        bool valid = previousClip.w > 0.0 && all(greaterThan(previousUv, hvec2_init(0.0, 0.0))) &&
            all(lessThan(previousUv, hvec2_init(1.0, 1.0))) && newDepth.x >= 0.0;
        if (useNew)
        {
            color = newColor;
            depth = newDepth.rg;
        }
        else if (valid)
        {
            hfloat halfSceneDepth = CloudViewDepth(CloudLoad(u_CloudHalfDepth5, pixel).r);
            hfloat nearDepth = CloudViewDepth(newDepth.z);
            hfloat farDepth = CloudViewDepth(newDepth.w);
            // UE Mode 0 uses a fixed 1 km threshold in this branch.
            if (abs(nearDepth - farDepth) > 1000.0)
            {
                hfloat factor = saturate((halfSceneDepth - nearDepth) / max(0.00001, farDepth - nearDepth));
                color = lerp(CloudLoad(u_CloudSecondary1, center), newColor, factor);
                // Preserve the source's axial-depth approximation at discontinuities.
                depth = hvec2_init(halfSceneDepth, halfSceneDepth) * 0.001;
            }
            else
            {
                hvec2 historyDepth = CloudSample(u_CloudHistoryDepth4, previousUv).rg;
                if (abs(historyDepth.y - newDepth.y) > 1.0)
                {
                    color = newColor;
                    depth = newDepth.rg;
                }
                else
                {
                    color = CloudSample(u_CloudHistoryColor3, previousUv);
                    depth = historyDepth;
                }
            }
            // Scalar compares stay in full precision; the HLSL lessThan overload takes half vectors in pixel
            // shaders, where 3e38 becomes infinity and Tint aborts. NaN fails every compare, as before.
            hvec4 absColor = abs(color);
            hvec2 absDepth = abs(depth);
            if (!all(bvec4(absColor.r < 3e38, absColor.g < 3e38, absColor.b < 3e38, absColor.a < 3e38)) ||
                !all(bvec2(absDepth.x < 3e38, absDepth.y < 3e38)))
            {
                color = hvec4_init(0.0, 0.0, 0.0, 1.0);
                depth = hvec2_init(1000.0, 1000.0);
            }
        }
    }
    gl_FragData[0] = color;
    gl_FragData[1] = hvec4_init(depth, 0.0, 0.0);
}
#endif
