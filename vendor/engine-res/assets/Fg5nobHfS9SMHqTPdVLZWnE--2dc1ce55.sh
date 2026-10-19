#ifndef REFLECTION_PROBES_SH
#define REFLECTION_PROBES_SH

#include "Cluster/clusters.sh"

// Sorted records and stable array slots are different indices.
BUFFER_RO(b_reflectionProbes, hvec4, 13);
uniform hvec4 u_ReflectionProbeGrid;
#define REFLECTION_PROBE_STRIDE 8
#define MAX_PROBES_PER_CLUSTER 32

struct ReflectionProbe
{
    hvec4 positionRadius;
    hvec4 capturePositionBrightness;
    hvec4 shapeSlotTransition;
    hvec3 boxHalfSize;
    hvec4 worldToBox0;
    hvec4 worldToBox1;
    hvec4 worldToBox2;
};

ReflectionProbe GetReflectionProbe(uint index)
{
    int base = int(index) * REFLECTION_PROBE_STRIDE;
    ReflectionProbe probe;
    probe.positionRadius = b_reflectionProbes[base];
    probe.capturePositionBrightness = b_reflectionProbes[base + 1];
    probe.shapeSlotTransition = b_reflectionProbes[base + 2];
    probe.boxHalfSize = b_reflectionProbes[base + 3].xyz;
    probe.worldToBox0 = b_reflectionProbes[base + 4];
    probe.worldToBox1 = b_reflectionProbes[base + 5];
    probe.worldToBox2 = b_reflectionProbes[base + 6];
    return probe;
}

uvec3 GetReflectionProbeCell(uint cell)
{
    int base = int(u_ReflectionProbeGrid.y) + int(cell) * 4;
    return uvec3(b_clusterLightGrid[base], b_clusterLightGrid[base + 1], b_clusterLightGrid[base + 2]);
}

// uv is local to the viewport and follows the depth texture's orientation.
uint GetReflectionCluster(hvec2 uv, hfloat eyeDepth)
{
    uvec3 grid = getClusterGridSize();
    hvec2 pixel = uv * u_viewRect.zw;
    uvec2 xy = uvec2(clamp(pixel / u_clusterSizes, hvec2_init(0.0, 0.0), hvec2_init(grid.xy) - 1.0));
    hfloat z = u_ReflectionProbeGrid.w > 0.5 ?
        (eyeDepth - u_zNear) / (u_zFar - u_zNear) : log(max(eyeDepth, u_zNear) / u_zNear) / log(u_zFar / u_zNear);
    return getClusterLinearIndex(uvec3(xy, uint(clamp(z * hfloat_init(grid.z), 0.0, hfloat_init(grid.z - 1u)))));
}

#endif
