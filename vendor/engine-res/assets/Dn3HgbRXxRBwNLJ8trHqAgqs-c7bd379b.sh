#ifndef SURFACE_GODOT_DERIVATIVES_SH
#define SURFACE_GODOT_DERIVATIVES_SH
// Function parameters ensure expressions with side effects are evaluated once.
#ifdef COMPILEPS
hfloat SurfaceGodot_fwidthFine(hfloat value)
{
    return abs(dFdxFine(value)) + abs(dFdyFine(value));
}
hfloat SurfaceGodot_fwidthCoarse(hfloat value)
{
    return abs(dFdxCoarse(value)) + abs(dFdyCoarse(value));
}
hvec2 SurfaceGodot_fwidthFine(hvec2 value)
{
    return abs(dFdxFine(value)) + abs(dFdyFine(value));
}
hvec2 SurfaceGodot_fwidthCoarse(hvec2 value)
{
    return abs(dFdxCoarse(value)) + abs(dFdyCoarse(value));
}
hvec3 SurfaceGodot_fwidthFine(hvec3 value)
{
    return abs(dFdxFine(value)) + abs(dFdyFine(value));
}
hvec3 SurfaceGodot_fwidthCoarse(hvec3 value)
{
    return abs(dFdxCoarse(value)) + abs(dFdyCoarse(value));
}
hvec4 SurfaceGodot_fwidthFine(hvec4 value)
{
    return abs(dFdxFine(value)) + abs(dFdyFine(value));
}
hvec4 SurfaceGodot_fwidthCoarse(hvec4 value)
{
    return abs(dFdxCoarse(value)) + abs(dFdyCoarse(value));
}
#endif
#endif
