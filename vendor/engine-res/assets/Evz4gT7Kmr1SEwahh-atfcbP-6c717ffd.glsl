#define WRITE_CLUSTERS
#include "varying_cluster.def.sc"
#include "Cluster/ReflectionProbes.sh"

#ifdef RESET_COUNTER
NUM_THREADS(1, 1, 1)
void main()
{
    // Light culling owns counter zero. Count omitted probe candidates independently.
    b_globalIndex[1] = 0u;
}
#else
NUM_THREADS(CLUSTERS_X_THREADS, CLUSTERS_Y_THREADS, CLUSTERS_Z_THREADS)
void main()
{
    uvec3 coord = gl_GlobalInvocationID.xyz;
    uvec3 dimensions = getClusterGridSize();
    if (any(greaterThanEqual(coord, dimensions)))
        return;
    uint cell = getClusterLinearIndex(coord);
    hvec3 lower = b_clusters[int(cell) * 2].xyz;
    hvec3 upper = b_clusters[int(cell) * 2 + 1].xyz;
    uint offset = uint(u_ReflectionProbeGrid.z) + cell * uint(MAX_PROBES_PER_CLUSTER);
    uint count = 0u;
    uint total = 0u;
    // A lane owns one cell and scans the CPU-sorted records in order. No atomics reorder this list.
    for (uint index = 0u; index < uint(u_ReflectionProbeGrid.x); ++index)
    {
        hvec4 sphere = b_reflectionProbes[int(index) * REFLECTION_PROBE_STRIDE];
        hvec3 center = mul(hvec4_init(sphere.xyz, 1.0), u_view).xyz;
        hvec3 distance = center - clamp(center, lower, upper);
        if (dot(distance, distance) > sphere.w * sphere.w)
            continue;
        ++total;
        if (count < uint(MAX_PROBES_PER_CLUSTER))
        {
            b_clusterLightIndices[offset + count] = index;
            ++count;
        }
    }
    int header = int(u_ReflectionProbeGrid.y) + int(cell) * 4;
    b_clusterLightGrid[header] = offset;
    b_clusterLightGrid[header + 1] = count;
    b_clusterLightGrid[header + 2] = total;
    b_clusterLightGrid[header + 3] = 0u;
    if (total > count)
        atomicAdd(b_globalIndex[1], total - count);
}
#endif
