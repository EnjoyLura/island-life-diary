#include "varying_quad.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
$input a_position
$output vTexCoord, vScreenPos
#endif
#ifdef COMPILEPS
$input vTexCoord, vScreenPos
#endif
#include "ScreenSpace/HiZ/HiZInitCommon.sh"

void VS()
{
    HiZInitVS();
}

void PS()
{
    hvec2 depth = HiZInitPS();
    gl_FragData[0] = hvec4_init(depth.x, 0.0, 0.0, 1.0);
    gl_FragData[1] = hvec4_init(depth.y, 0.0, 0.0, 1.0);
}
