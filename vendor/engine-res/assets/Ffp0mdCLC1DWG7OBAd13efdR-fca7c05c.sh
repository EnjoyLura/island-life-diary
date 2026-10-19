#ifndef SURFACE_GODOT_RELATIONS_SH
#define SURFACE_GODOT_RELATIONS_SH

ivec2 SurfaceGodotSplat_ivec2(int value)
{
    return ivec2(value, value);
}

ivec3 SurfaceGodotSplat_ivec3(int value)
{
    return ivec3(value, value, value);
}

ivec4 SurfaceGodotSplat_ivec4(int value)
{
    return ivec4(value, value, value, value);
}

uvec2 SurfaceGodotSplat_uvec2(uint value)
{
    return uvec2(value, value);
}

uvec3 SurfaceGodotSplat_uvec3(uint value)
{
    return uvec3(value, value, value);
}

uvec4 SurfaceGodotSplat_uvec4(uint value)
{
    return uvec4(value, value, value, value);
}

bvec2 SurfaceGodotSplat_bvec2(bool value)
{
    return bvec2(value, value);
}

bvec3 SurfaceGodotSplat_bvec3(bool value)
{
    return bvec3(value, value, value);
}

bvec4 SurfaceGodotSplat_bvec4(bool value)
{
    return bvec4(value, value, value, value);
}

// Keep integer operands in their native domain. The stock bgfx float-vector overloads
// lose adjacent int/uint values above 2^24. Reduce booleans through canonical 0/1 values
// because HLSLcc can represent true with either 1 or an all-bit mask.

bvec2 SurfaceGodot_equal(hvec2 a, hvec2 b)
{
    return bvec2(a.x == b.x, a.y == b.y);
}

bvec2 SurfaceGodot_notEqual(hvec2 a, hvec2 b)
{
    return bvec2(a.x != b.x, a.y != b.y);
}

bvec2 SurfaceGodot_lessThan(hvec2 a, hvec2 b)
{
    return bvec2(a.x < b.x, a.y < b.y);
}

bvec2 SurfaceGodot_lessThanEqual(hvec2 a, hvec2 b)
{
    return bvec2(a.x <= b.x, a.y <= b.y);
}

bvec2 SurfaceGodot_greaterThan(hvec2 a, hvec2 b)
{
    return bvec2(a.x > b.x, a.y > b.y);
}

bvec2 SurfaceGodot_greaterThanEqual(hvec2 a, hvec2 b)
{
    return bvec2(a.x >= b.x, a.y >= b.y);
}

bvec2 SurfaceGodot_equal(ivec2 a, ivec2 b)
{
    return bvec2(a.x == b.x, a.y == b.y);
}

bvec2 SurfaceGodot_notEqual(ivec2 a, ivec2 b)
{
    return bvec2(a.x != b.x, a.y != b.y);
}

bvec2 SurfaceGodot_lessThan(ivec2 a, ivec2 b)
{
    return bvec2(a.x < b.x, a.y < b.y);
}

bvec2 SurfaceGodot_lessThanEqual(ivec2 a, ivec2 b)
{
    return bvec2(a.x <= b.x, a.y <= b.y);
}

bvec2 SurfaceGodot_greaterThan(ivec2 a, ivec2 b)
{
    return bvec2(a.x > b.x, a.y > b.y);
}

bvec2 SurfaceGodot_greaterThanEqual(ivec2 a, ivec2 b)
{
    return bvec2(a.x >= b.x, a.y >= b.y);
}

bvec2 SurfaceGodot_equal(uvec2 a, uvec2 b)
{
    return bvec2(a.x == b.x, a.y == b.y);
}

bvec2 SurfaceGodot_notEqual(uvec2 a, uvec2 b)
{
    return bvec2(a.x != b.x, a.y != b.y);
}

bvec2 SurfaceGodot_lessThan(uvec2 a, uvec2 b)
{
    return bvec2(a.x < b.x, a.y < b.y);
}

bvec2 SurfaceGodot_lessThanEqual(uvec2 a, uvec2 b)
{
    return bvec2(a.x <= b.x, a.y <= b.y);
}

bvec2 SurfaceGodot_greaterThan(uvec2 a, uvec2 b)
{
    return bvec2(a.x > b.x, a.y > b.y);
}

bvec2 SurfaceGodot_greaterThanEqual(uvec2 a, uvec2 b)
{
    return bvec2(a.x >= b.x, a.y >= b.y);
}

bvec2 SurfaceGodot_equal(bvec2 a, bvec2 b)
{
    return bvec2((a.x ? 1.0 : 0.0) == (b.x ? 1.0 : 0.0), (a.y ? 1.0 : 0.0) == (b.y ? 1.0 : 0.0));
}

bvec2 SurfaceGodot_notEqual(bvec2 a, bvec2 b)
{
    return bvec2((a.x ? 1.0 : 0.0) != (b.x ? 1.0 : 0.0), (a.y ? 1.0 : 0.0) != (b.y ? 1.0 : 0.0));
}

bool SurfaceGodot_all(bvec2 value)
{
    return (value.x ? 1.0 : 0.0) + (value.y ? 1.0 : 0.0) > 1.5;
}

bool SurfaceGodot_any(bvec2 value)
{
    return (value.x ? 1.0 : 0.0) + (value.y ? 1.0 : 0.0) > 0.5;
}

bvec2 SurfaceGodot_not(bvec2 value)
{
    return bvec2(!value.x, !value.y);
}

bvec3 SurfaceGodot_equal(hvec3 a, hvec3 b)
{
    return bvec3(a.x == b.x, a.y == b.y, a.z == b.z);
}

bvec3 SurfaceGodot_notEqual(hvec3 a, hvec3 b)
{
    return bvec3(a.x != b.x, a.y != b.y, a.z != b.z);
}

bvec3 SurfaceGodot_lessThan(hvec3 a, hvec3 b)
{
    return bvec3(a.x < b.x, a.y < b.y, a.z < b.z);
}

bvec3 SurfaceGodot_lessThanEqual(hvec3 a, hvec3 b)
{
    return bvec3(a.x <= b.x, a.y <= b.y, a.z <= b.z);
}

bvec3 SurfaceGodot_greaterThan(hvec3 a, hvec3 b)
{
    return bvec3(a.x > b.x, a.y > b.y, a.z > b.z);
}

bvec3 SurfaceGodot_greaterThanEqual(hvec3 a, hvec3 b)
{
    return bvec3(a.x >= b.x, a.y >= b.y, a.z >= b.z);
}

bvec3 SurfaceGodot_equal(ivec3 a, ivec3 b)
{
    return bvec3(a.x == b.x, a.y == b.y, a.z == b.z);
}

bvec3 SurfaceGodot_notEqual(ivec3 a, ivec3 b)
{
    return bvec3(a.x != b.x, a.y != b.y, a.z != b.z);
}

bvec3 SurfaceGodot_lessThan(ivec3 a, ivec3 b)
{
    return bvec3(a.x < b.x, a.y < b.y, a.z < b.z);
}

bvec3 SurfaceGodot_lessThanEqual(ivec3 a, ivec3 b)
{
    return bvec3(a.x <= b.x, a.y <= b.y, a.z <= b.z);
}

bvec3 SurfaceGodot_greaterThan(ivec3 a, ivec3 b)
{
    return bvec3(a.x > b.x, a.y > b.y, a.z > b.z);
}

bvec3 SurfaceGodot_greaterThanEqual(ivec3 a, ivec3 b)
{
    return bvec3(a.x >= b.x, a.y >= b.y, a.z >= b.z);
}

bvec3 SurfaceGodot_equal(uvec3 a, uvec3 b)
{
    return bvec3(a.x == b.x, a.y == b.y, a.z == b.z);
}

bvec3 SurfaceGodot_notEqual(uvec3 a, uvec3 b)
{
    return bvec3(a.x != b.x, a.y != b.y, a.z != b.z);
}

bvec3 SurfaceGodot_lessThan(uvec3 a, uvec3 b)
{
    return bvec3(a.x < b.x, a.y < b.y, a.z < b.z);
}

bvec3 SurfaceGodot_lessThanEqual(uvec3 a, uvec3 b)
{
    return bvec3(a.x <= b.x, a.y <= b.y, a.z <= b.z);
}

bvec3 SurfaceGodot_greaterThan(uvec3 a, uvec3 b)
{
    return bvec3(a.x > b.x, a.y > b.y, a.z > b.z);
}

bvec3 SurfaceGodot_greaterThanEqual(uvec3 a, uvec3 b)
{
    return bvec3(a.x >= b.x, a.y >= b.y, a.z >= b.z);
}

bvec3 SurfaceGodot_equal(bvec3 a, bvec3 b)
{
    return bvec3((a.x ? 1.0 : 0.0) == (b.x ? 1.0 : 0.0), (a.y ? 1.0 : 0.0) == (b.y ? 1.0 : 0.0), (a.z ? 1.0 : 0.0) == (b.z ? 1.0 : 0.0));
}

bvec3 SurfaceGodot_notEqual(bvec3 a, bvec3 b)
{
    return bvec3((a.x ? 1.0 : 0.0) != (b.x ? 1.0 : 0.0), (a.y ? 1.0 : 0.0) != (b.y ? 1.0 : 0.0), (a.z ? 1.0 : 0.0) != (b.z ? 1.0 : 0.0));
}

bool SurfaceGodot_all(bvec3 value)
{
    return (value.x ? 1.0 : 0.0) + (value.y ? 1.0 : 0.0) + (value.z ? 1.0 : 0.0) > 2.5;
}

bool SurfaceGodot_any(bvec3 value)
{
    return (value.x ? 1.0 : 0.0) + (value.y ? 1.0 : 0.0) + (value.z ? 1.0 : 0.0) > 0.5;
}

bvec3 SurfaceGodot_not(bvec3 value)
{
    return bvec3(!value.x, !value.y, !value.z);
}

bvec4 SurfaceGodot_equal(hvec4 a, hvec4 b)
{
    return bvec4(a.x == b.x, a.y == b.y, a.z == b.z, a.w == b.w);
}

bvec4 SurfaceGodot_notEqual(hvec4 a, hvec4 b)
{
    return bvec4(a.x != b.x, a.y != b.y, a.z != b.z, a.w != b.w);
}

bvec4 SurfaceGodot_lessThan(hvec4 a, hvec4 b)
{
    return bvec4(a.x < b.x, a.y < b.y, a.z < b.z, a.w < b.w);
}

bvec4 SurfaceGodot_lessThanEqual(hvec4 a, hvec4 b)
{
    return bvec4(a.x <= b.x, a.y <= b.y, a.z <= b.z, a.w <= b.w);
}

bvec4 SurfaceGodot_greaterThan(hvec4 a, hvec4 b)
{
    return bvec4(a.x > b.x, a.y > b.y, a.z > b.z, a.w > b.w);
}

bvec4 SurfaceGodot_greaterThanEqual(hvec4 a, hvec4 b)
{
    return bvec4(a.x >= b.x, a.y >= b.y, a.z >= b.z, a.w >= b.w);
}

bvec4 SurfaceGodot_equal(ivec4 a, ivec4 b)
{
    return bvec4(a.x == b.x, a.y == b.y, a.z == b.z, a.w == b.w);
}

bvec4 SurfaceGodot_notEqual(ivec4 a, ivec4 b)
{
    return bvec4(a.x != b.x, a.y != b.y, a.z != b.z, a.w != b.w);
}

bvec4 SurfaceGodot_lessThan(ivec4 a, ivec4 b)
{
    return bvec4(a.x < b.x, a.y < b.y, a.z < b.z, a.w < b.w);
}

bvec4 SurfaceGodot_lessThanEqual(ivec4 a, ivec4 b)
{
    return bvec4(a.x <= b.x, a.y <= b.y, a.z <= b.z, a.w <= b.w);
}

bvec4 SurfaceGodot_greaterThan(ivec4 a, ivec4 b)
{
    return bvec4(a.x > b.x, a.y > b.y, a.z > b.z, a.w > b.w);
}

bvec4 SurfaceGodot_greaterThanEqual(ivec4 a, ivec4 b)
{
    return bvec4(a.x >= b.x, a.y >= b.y, a.z >= b.z, a.w >= b.w);
}

bvec4 SurfaceGodot_equal(uvec4 a, uvec4 b)
{
    return bvec4(a.x == b.x, a.y == b.y, a.z == b.z, a.w == b.w);
}

bvec4 SurfaceGodot_notEqual(uvec4 a, uvec4 b)
{
    return bvec4(a.x != b.x, a.y != b.y, a.z != b.z, a.w != b.w);
}

bvec4 SurfaceGodot_lessThan(uvec4 a, uvec4 b)
{
    return bvec4(a.x < b.x, a.y < b.y, a.z < b.z, a.w < b.w);
}

bvec4 SurfaceGodot_lessThanEqual(uvec4 a, uvec4 b)
{
    return bvec4(a.x <= b.x, a.y <= b.y, a.z <= b.z, a.w <= b.w);
}

bvec4 SurfaceGodot_greaterThan(uvec4 a, uvec4 b)
{
    return bvec4(a.x > b.x, a.y > b.y, a.z > b.z, a.w > b.w);
}

bvec4 SurfaceGodot_greaterThanEqual(uvec4 a, uvec4 b)
{
    return bvec4(a.x >= b.x, a.y >= b.y, a.z >= b.z, a.w >= b.w);
}

bvec4 SurfaceGodot_equal(bvec4 a, bvec4 b)
{
    return bvec4((a.x ? 1.0 : 0.0) == (b.x ? 1.0 : 0.0), (a.y ? 1.0 : 0.0) == (b.y ? 1.0 : 0.0), (a.z ? 1.0 : 0.0) == (b.z ? 1.0 : 0.0), (a.w ? 1.0 : 0.0) == (b.w ? 1.0 : 0.0));
}

bvec4 SurfaceGodot_notEqual(bvec4 a, bvec4 b)
{
    return bvec4((a.x ? 1.0 : 0.0) != (b.x ? 1.0 : 0.0), (a.y ? 1.0 : 0.0) != (b.y ? 1.0 : 0.0), (a.z ? 1.0 : 0.0) != (b.z ? 1.0 : 0.0), (a.w ? 1.0 : 0.0) != (b.w ? 1.0 : 0.0));
}

bool SurfaceGodot_all(bvec4 value)
{
    return (value.x ? 1.0 : 0.0) + (value.y ? 1.0 : 0.0) + (value.z ? 1.0 : 0.0) + (value.w ? 1.0 : 0.0) > 3.5;
}

bool SurfaceGodot_any(bvec4 value)
{
    return (value.x ? 1.0 : 0.0) + (value.y ? 1.0 : 0.0) + (value.z ? 1.0 : 0.0) + (value.w ? 1.0 : 0.0) > 0.5;
}

bvec4 SurfaceGodot_not(bvec4 value)
{
    return bvec4(!value.x, !value.y, !value.z, !value.w);
}

#endif
