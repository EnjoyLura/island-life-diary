/*
 * General-purpose texture copy shader.
 * Copies source texture to output render target (1:1, no filtering).
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

// Source texture (register 0)
#ifdef COPY_DEPTH
// Preserve depth precision at the sampler as well as the independently selected output.
SAMPLER2D_PRECISION(u_Depth0, 0, highp);
#define sCopySource u_Depth0
#else
SAMPLER2D(u_Source0, 0);
#define sCopySource u_Source0
#endif

void PS()
{
    gl_FragColor = texture2D(sCopySource, vTexCoord);
}

#endif
