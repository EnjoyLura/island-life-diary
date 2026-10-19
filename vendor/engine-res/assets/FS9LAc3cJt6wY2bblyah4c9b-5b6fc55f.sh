#ifndef LUMEN_SCREEN_TRACE_SH
#define LUMEN_SCREEN_TRACE_SH

// UE 5.5 LumenScreenTracing.ush, InternalTraceScreen: stackless closest-HZB
// traversal. Work in view space, with explicit standard/reversed device-Z.
hfloat LumenBoundaryTime(hfloat boundary, hfloat origin, hfloat direction)
{
    return abs(direction) > 1.0e-10 ? (boundary - origin) / direction : 1.0e20;
}

hfloat LumenNextTileTime(hvec3 origin, hvec3 direction, hvec2 position, hvec2 tileSize)
{
    hvec2 corner = floor(position / tileSize);
    corner.x += direction.x < 0.0 ? -0.005 : 1.005;
    corner.y += direction.y < 0.0 ? -0.005 : 1.005;
    hvec2 boundary = corner * tileSize;
    return min(LumenBoundaryTime(boundary.x, origin.x, direction.x),
               LumenBoundaryTime(boundary.y, origin.y, direction.y));
}

bool ScreenSpaceRayCastLumen(hvec3 surfaceOrigin, hvec3 normal, hvec3 rayDir,
    out hvec2 hitUV, out hfloat hitDepth, out hfloat hitDistance, out hfloat hitConfidence)
{
    hitUV = hvec2_init(0.0, 0.0);
    hitDepth = 0.0;
    hitDistance = 0.0;
    hitConfidence = 0.0;

    // LumenReflectionTracing.usf: project a half-pixel corner onto the normal.
    hvec3 surfaceUVZ = ProjectViewToUVZ(surfaceOrigin);
    hvec3 corner = ReconstructViewPos(surfaceUVZ.xy + 0.5 * cGBufferInvSize, surfaceUVZ.z);
    hfloat normalBias = 2.0 * abs(dot(corner - surfaceOrigin, normal));
    hvec3 origin = surfaceOrigin + normal * normalBias;
    if (origin.z <= cNearClipPS || u_MaxDistance <= 0.0)
        return false;

    hfloat rayDistance = u_MaxDistance;
    if (rayDir.z < -1.0e-6)
        rayDistance = min(rayDistance, (origin.z - cNearClipPS * 1.001) / -rayDir.z);
    if (rayDistance <= 0.0)
        return false;

    hvec3 start = ProjectViewToUVZ(origin);
    if (any(lessThan(start.xy, hvec2_init(0.0, 0.0))) || any(greaterThanEqual(start.xy, hvec2_init(1.0, 1.0))))
        return false;
    hvec3 direction = ProjectViewToUVZ(origin + rayDir * rayDistance) - start;
    hfloat endTime = ClipRayToScreen(start.xy, direction.xy);
    if (direction.z > 1.0e-10)
        endTime = min(endTime, (1.0 - start.z) / direction.z);
    else if (direction.z < -1.0e-10)
        endTime = min(endTime, -start.z / direction.z);
    direction *= saturate(endTime);

    // HZB UVs cover only viewport / (2 * mip0 size), including odd-sized views.
    start.xy *= u_HZBUvFactor.xy;
    direction.xy *= u_HZBUvFactor.xy;
    hfloat time = LumenNextTileTime(start, direction, start.xy, u_SsrHZBParams.xy * 0.5);
    hfloat mip = -1.0;
    hvec3 position = start;
    int maxIterations = int(clamp(u_LumenTraceParams.x, 1.0, 128.0));

    LOOP
    for (int iteration = 0; iteration < 128; ++iteration)
    {
        if (iteration >= maxIterations || time >= 1.0 || mip < -1.0)
            break;
        position = start + direction * time;
        hfloat tileZ;
        if (mip < 0.0)
            tileZ = texture2DLod(u_Depth0, position.xy / u_HZBUvFactor.xy, 0.0).r;
        else
            tileZ = texture2DLod(u_ClosestHiZ9, position.xy, mip).r;
        hvec2 tileSize = min(exp2(mip) * u_SsrHZBParams.xy, hvec2_init(1.0, 1.0));
        hfloat xyTime = LumenNextTileTime(start, direction, position.xy, tileSize);
#ifdef REVERSED_Z
        bool above = position.z > tileZ;
        bool towardSurface = direction.z < -1.0e-10;
#else
        bool above = position.z < tileZ;
        bool towardSurface = direction.z > 1.0e-10;
#endif
        hfloat zTime = towardSurface ? LumenBoundaryTime(tileZ, start.z, direction.z) : 1.0e20;
        bool skipped = above && xyTime < zTime;
        if (above)
            time = max(time, min(xyTime, zTime));
        mip = skipped ? min(mip + 1.0, u_SsrHZBParams.z) : mip - 1.0;
    }

    // Exhaustion and off-screen rays are misses, never a coarse-mip hit.
    if (mip >= -1.0 || time >= 1.0)
        return false;
    position = start + direction * time;
    hvec2 uv = position.xy / u_HZBUvFactor.xy;
    if (any(lessThan(uv, hvec2_init(0.0, 0.0))) || any(greaterThanEqual(uv, hvec2_init(1.0, 1.0))))
        return false;
    hfloat surfaceZ = texture2DLod(u_Depth0, uv, 0.0).r;
    if (IsSSRFarPlaneDepth(surfaceZ))
        return false;
    hvec3 surface = ReconstructViewPos(uv, surfaceZ);
    hvec3 rayHit = ReconstructViewPos(uv, position.z);
    hfloat thickness = max(u_LumenTraceParams.y, 0.0) * max(surface.z, 0.00001);
    if (rayHit.z - surface.z > thickness)
        return false;
    hitUV = uv;
    hitDepth = position.z;
    hitDistance = length(rayHit - surfaceOrigin);
    hitConfidence = 1.0;
    return true;
}

#endif
