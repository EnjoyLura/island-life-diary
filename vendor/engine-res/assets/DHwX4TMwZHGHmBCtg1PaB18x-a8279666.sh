// Fixed-step UE SSR trace. Kept separate from the optional hierarchical trace.
#ifndef SSR_FIXED_STEP_TRACE_SH
#define SSR_FIXED_STEP_TRACE_SH

// Mip 0 is the full-resolution depth buffer; mip k >= 1 is HZB mip k-1.
// A farthest-depth reduction moves silhouettes within each 2x2 block. Sharp
// reflections need the original surface, or their contours bend as the ray moves.
hfloat SampleSSRTraceDepth(hvec2 uv, hfloat legacyMip)
{
#if HZB_TRACE_INCLUDE_FULL_RES_DEPTH
    BRANCH
    if (legacyMip < 1.0)
        return texture2DLod(u_Depth0, uv, 0.0).r;
#endif
    return texture2DLod(u_FarthestHiZ3, uv * u_HZBUvFactor.xy, max(legacyMip - 1.0, 0.0)).r;
}

bool ScreenSpaceRayCastUE(hvec3 viewOrigin, hvec3 rayDir, hfloat roughness, int traceMaxSteps, hfloat stepOffset,
                          out hvec2 hitUV, out hfloat hitDepth, out hfloat hitDistance, out hfloat hitConfidence)
{
    // GL translation flattens early returns; keep miss outputs defined through the ray loop.
    hitUV = hvec2_init(0.0, 0.0);
    hitDepth = 0.0;
    hitDistance = 0.0;
    hitConfidence = 0.0;

    hfloat sceneDepth = max(viewOrigin.z, cNearClipPS);
    hfloat rayDistance = sceneDepth;

    BRANCH
    if (rayDir.z < -0.0001)
        rayDistance = min(rayDistance, -0.95 * sceneDepth / rayDir.z);

    BRANCH
    if (rayDistance <= 0.0)
        return false;

    hvec3 rayEnd = viewOrigin + rayDir * rayDistance;
    hvec3 rayStartUVZ = ProjectViewToUVZ(viewOrigin);
    hvec3 rayEndUVZ = ProjectViewToUVZ(rayEnd);
    hvec3 rayStepUVZ = rayEndUVZ - rayStartUVZ;

    hfloat screenClip = ClipRayToScreen(rayStartUVZ.xy, rayStepUVZ.xy);
    rayStepUVZ *= screenClip;

    hvec2 screenSize = hvec2_init(1.0, 1.0) / cGBufferInvSize;
    hfloat pixelDist = max(abs(rayStepUVZ.x) * screenSize.x, abs(rayStepUVZ.y) * screenSize.y);
    BRANCH
    if (pixelDist < 1.0)
        return false;

    int numSteps = min(min(int(ceil(pixelDist)), traceMaxSteps), MAX_TRACE_STEPS);
    // Samples are taken in batches of 4; round numSteps up to a multiple of 4 so the
    // last batch never extrapolates past the ray end (t > 1). UE's NumSteps presets
    // are always multiples of 4, but ceil(pixelDist) is not.
    numSteps = ((numSteps + 3) / 4) * 4;
    hfloat step = 1.0 / hfloat_init(numSteps);

    hfloat rayDepthZ = ProjectViewToUVZ(viewOrigin + hvec3_init(0.0, 0.0, rayDistance)).z;
    hfloat rayCompareTolerance = max(abs(rayStepUVZ.z), abs(rayStartUVZ.z - rayDepthZ) * 4.0);
    hfloat compareTolerance = rayCompareTolerance * step;

    rayStepUVZ *= step;
    hvec3 rayUVZ = rayStartUVZ + rayStepUVZ * stepOffset;

    bool foundHit = false;
    hvec4 multipleSampleDepthDiff = hvec4_init(0.0, 0.0, 0.0, 0.0);
    bvec4 multipleSampleHit = bvec4(false, false, false, false);
    hfloat lastDiff = 0.0;
    hfloat level = roughness < 0.1 ? 0.0 : 1.0;
    int hitBatchIndex = 0;

    LOOP
    for (int i = 0; i < MAX_TRACE_STEPS; i += 4)
    {
        BRANCH
        if (i >= numSteps)
            break;

        hvec3 sample0 = rayUVZ + rayStepUVZ * hfloat_init(i + 1);
        hvec3 sample1 = rayUVZ + rayStepUVZ * hfloat_init(i + 2);
        hvec3 sample2 = rayUVZ + rayStepUVZ * hfloat_init(i + 3);
        hvec3 sample3 = rayUVZ + rayStepUVZ * hfloat_init(i + 4);

        BRANCH
        if (any(lessThan(sample0.xy, hvec2_init(0.0, 0.0))) || any(greaterThan(sample0.xy, hvec2_init(1.0, 1.0))))
            break;

        hfloat mip01 = level;
        level += (8.0 / hfloat_init(numSteps)) * roughness;
        hfloat mip23 = level;
        level += (8.0 / hfloat_init(numSteps)) * roughness;

        hfloat d0 = sample0.z - SampleSSRTraceDepth(sample0.xy, clamp(mip01, 0.0, MAX_HIZ_MIP));
        hfloat d1 = sample1.z - SampleSSRTraceDepth(sample1.xy, clamp(mip01, 0.0, MAX_HIZ_MIP));
        hfloat d2 = sample2.z - SampleSSRTraceDepth(sample2.xy, clamp(mip23, 0.0, MAX_HIZ_MIP));
        hfloat d3 = sample3.z - SampleSSRTraceDepth(sample3.xy, clamp(mip23, 0.0, MAX_HIZ_MIP));
        multipleSampleDepthDiff = hvec4_init(d0, d1, d2, d3);

#ifdef REVERSED_Z
        multipleSampleHit = lessThan(abs(multipleSampleDepthDiff + hvec4_init(compareTolerance, compareTolerance, compareTolerance, compareTolerance)), hvec4_init(compareTolerance, compareTolerance, compareTolerance, compareTolerance));
#else
        multipleSampleHit = lessThan(abs(multipleSampleDepthDiff - hvec4_init(compareTolerance, compareTolerance, compareTolerance, compareTolerance)), hvec4_init(compareTolerance, compareTolerance, compareTolerance, compareTolerance));
#endif

        foundHit = multipleSampleHit.x || multipleSampleHit.y || multipleSampleHit.z || multipleSampleHit.w;
        BRANCH
        if (foundHit)
        {
            hitBatchIndex = i;
            break;
        }

        lastDiff = multipleSampleDepthDiff.w;
    }

    BRANCH
    if (!foundHit)
        return false;

    hfloat depthDiff0 = multipleSampleDepthDiff.z;
    hfloat depthDiff1 = multipleSampleDepthDiff.w;
    hfloat time0 = 3.0;

    if (multipleSampleHit.z)
    {
        depthDiff0 = multipleSampleDepthDiff.y;
        depthDiff1 = multipleSampleDepthDiff.z;
        time0 = 2.0;
    }
    if (multipleSampleHit.y)
    {
        depthDiff0 = multipleSampleDepthDiff.x;
        depthDiff1 = multipleSampleDepthDiff.y;
        time0 = 1.0;
    }
    if (multipleSampleHit.x)
    {
        depthDiff0 = lastDiff;
        depthDiff1 = multipleSampleDepthDiff.x;
        time0 = 0.0;
    }

    time0 += hfloat_init(hitBatchIndex);
    hfloat timeLerp = saturate(depthDiff0 / (depthDiff0 - depthDiff1));
    hfloat intersectTime = time0 + timeLerp;
    hvec3 hitUVZ = rayUVZ + rayStepUVZ * intersectTime;

    BRANCH
    if (any(lessThan(hitUVZ.xy, hvec2_init(0.0, 0.0))) || any(greaterThan(hitUVZ.xy, hvec2_init(1.0, 1.0))))
        return false;

    // Hit thickness validation (UrhoX addition, not present in UE):
    // The x4 slope term of CompareTolerance roughly equals the full ray's device-Z span
    // at 8 steps, so once a ray crosses from in front of a floating object to behind it,
    // every sample counts as a hit — stretching spheres/cylinders into long streaks in
    // floor reflections. Re-validate the hit against the actual full-res surface depth
    // (the pow2half HZB mip0 is only half resolution, so sample the full-res depth at
    // unit0 instead for better precision) and smoothly reject hits farther than
    // u_Thickness in view space.
    hfloat surfaceZ = texture2DLod(u_Depth0, hitUVZ.xy, 0.0).r;
    BRANCH
    if (IsSSRFarPlaneDepth(surfaceZ))
        return false;

    hvec3 surfaceViewPos = ReconstructViewPos(hitUVZ.xy, surfaceZ);
    hvec3 hitViewPos = ReconstructViewPos(hitUVZ.xy, hitUVZ.z);
    hfloat surfaceDist = length(hitViewPos - surfaceViewPos);
    hitConfidence = 1.0 - smoothstep(0.0, u_Thickness, surfaceDist);
    hitConfidence *= hitConfidence;

    BRANCH
    if (hitConfidence <= 0.0)
        return false;

    hitUV = hitUVZ.xy;
    hitDepth = hitUVZ.z;
    hitDistance = length(hitViewPos - viewOrigin);
    return true;
}

#endif
