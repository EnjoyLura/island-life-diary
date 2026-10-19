#ifndef VOXEL_STATIC_AO_SH
#define VOXEL_STATIC_AO_SH

// Reuse the published occupancy version. No ray traversal or separate AO resource.
// Out-of-volume cells are empty; independent volumes do not share ambient occlusion.
float VoxelAOOccupied(ivec3 cell, ivec3 dimensions, ivec3 atlasBase, int directoryBase)
{
    if (any(lessThan(cell, ivec3(0, 0, 0))) || any(greaterThanEqual(cell, dimensions)))
        return 0.0;
#ifdef VOXEL_SPARSE4
    ivec3 macro = ivec3(cell.x >> 2, cell.y >> 2, cell.z >> 2);
    ivec3 macroDimensions = ivec3((dimensions.x + 3) >> 2, (dimensions.y + 3) >> 2, (dimensions.z + 3) >> 2);
    int slot, mask;
    FetchSparse4Directory(macro, macroDimensions, directoryBase, slot, mask);
    if (slot == 0)
        return 0.0;
    ivec3 local = cell - macro * 4;
    int bit = (local.x >> 1) | ((local.y >> 1) << 1) | ((local.z >> 1) << 2);
    if ((mask & (1 << bit)) == 0)
        return 0.0;
    --slot;
    ivec3 origin = ivec3(slot & 63, (slot >> 6) & 63, slot >> 12) * 4;
    return texelFetch(sVolumeMap, origin + local, 0).g > 0.0 ? 1.0 : 0.0;
#else
    return texelFetch(sVolumeMap, atlasBase + cell, 0).g > 0.0 ? 1.0 : 0.0;
#endif
}

float VoxelAOCorner(float sideA, float sideB, float corner)
{
    float level = sideA * sideB > 0.5 ? 0.0 : 3.0 - sideA - sideB - corner;
    return 0.25 + 0.25 * level;
}

// Four edge and four diagonal queries serve all four corners of the hit face.
float VoxelStaticAO(hvec3 hit, hvec3 normal, int axis, hvec3 dimensions, ivec3 atlasBase, int directoryBase)
{
    ivec3 size = ivec3(dimensions);
    ivec3 cell = ivec3(clamp(floor(hit - normal * 0.002), hvec3_init(0.0, 0.0, 0.0), dimensions - 1.0));
    ivec3 u = axis == 0 ? ivec3(0, 1, 0) : ivec3(1, 0, 0);
    ivec3 v = axis == 2 ? ivec3(0, 1, 0) : ivec3(0, 0, 1);
    hvec2 uv = axis == 0 ? hit.yz : (axis == 1 ? hit.xz : hit.xy);
    uv = fract(uv);
    ivec3 plane = cell + ivec3(normal);
    float left = VoxelAOOccupied(plane - u, size, atlasBase, directoryBase);
    float right = VoxelAOOccupied(plane + u, size, atlasBase, directoryBase);
    float bottom = VoxelAOOccupied(plane - v, size, atlasBase, directoryBase);
    float top = VoxelAOOccupied(plane + v, size, atlasBase, directoryBase);
    float lb = VoxelAOCorner(left, bottom, VoxelAOOccupied(plane - u - v, size, atlasBase, directoryBase));
    float rb = VoxelAOCorner(right, bottom, VoxelAOOccupied(plane + u - v, size, atlasBase, directoryBase));
    float lt = VoxelAOCorner(left, top, VoxelAOOccupied(plane - u + v, size, atlasBase, directoryBase));
    float rt = VoxelAOCorner(right, top, VoxelAOOccupied(plane + u + v, size, atlasBase, directoryBase));
    return mix(mix(lb, rb, uv.x), mix(lt, rt, uv.x), uv.y);
}
#endif
