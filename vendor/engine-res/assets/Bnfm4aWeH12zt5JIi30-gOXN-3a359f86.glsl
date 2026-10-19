/*
 * Motion Vector Generation Shader
 * Generates per-pixel motion vectors via depth reprojection.
 *
 * Reprojects directly between clip spaces using a CPU-composed relative-camera
 * transform. No absolute world-position reconstruction is needed.
 *
 * Motion Vector = UnjitteredCurrentUV - UnjitteredPreviousUV, stored at the raster pixel.
 *
 * Output: RG16F texture
 *   R = horizontal motion (positive = moved right)
 *   G = vertical motion (positive = moved down)
 */

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

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS

// Depth buffer (register 0)
SAMPLER2D(u_Depth0, 0);

#include "ScreenSpace/MotionVector/CameraReprojection.sh"

void PS()
{
    hvec2 uv = vTexCoord;
    hfloat depth = texture2D(u_Depth0, uv).r;

    // Skip sky/background (depth at far plane)
#ifdef REVERSED_Z
    if (depth < 0.00001)
#else
    if (depth > 0.99999)
#endif
    {
        gl_FragColor = hvec4_init(0.0, 0.0, 0.0, 1.0);
        return;
    }

    hvec2 motionVector = ComputeCameraMotionVectorFromRaster(uv, depth);

    // Clamp to reasonable range
    motionVector = clamp(motionVector, hvec2_init(-0.5, -0.5), hvec2_init(0.5, 0.5));

    gl_FragColor = hvec4_init(motionVector.x, motionVector.y, 0.0, 1.0);
}

#endif
