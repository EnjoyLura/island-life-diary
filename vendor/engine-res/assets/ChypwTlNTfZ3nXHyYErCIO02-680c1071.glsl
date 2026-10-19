// Preserve raw storage bits in a private integer texture for asynchronous readback.
#ifdef COMPILECS
#include "varying_cluster.def.sc"
#include "Common/bgfx_compute.sh"

#ifdef SCALAR_BUFFER
BUFFER_RO(u_ReadbackSource, uint, 0);
#else
BUFFER_RO(u_ReadbackSource, uvec4, 0);
#endif
UIMAGE2D_WR(u_ReadbackSnapshot, rgba32ui, 1);
uniform vec4 u_ComputeDispatchSize;

NUM_THREADS(8, 8, 1)
void main()
{
    uvec2 pixel = gl_GlobalInvocationID.xy;
    uvec2 dimensions = uvec2(u_ComputeDispatchSize.xy);
    uint index = pixel.x + dimensions.x * pixel.y;
    if (all(lessThan(pixel, dimensions)) && index < uint(u_ComputeDispatchSize.z))
    {
#ifdef SCALAR_BUFFER
        imageStore(u_ReadbackSnapshot, ivec2(pixel), uvec4(u_ReadbackSource[index], 0u, 0u, 0u));
#else
        imageStore(u_ReadbackSnapshot, ivec2(pixel), u_ReadbackSource[index]);
#endif
    }
}
#endif
