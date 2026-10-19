#include "varying_quad.def.sc"
#include "urho3d_compatibility.sh"
#ifdef COMPILEVS
$input a_position
$output vTexCoord, vScreenPos
#endif
#ifdef COMPILEPS
$input vTexCoord, vScreenPos
#endif
#define HIZ_FARTHEST_ONLY
#include "ScreenSpace/HiZ/HiZInitCommon.sh"

void VS()
{
    HiZInitVS();
}

void PS()
{
    hvec2 depth = HiZInitPS();
    gl_FragColor = hvec4_init(depth.y, 0.0, 0.0, 1.0);
}
