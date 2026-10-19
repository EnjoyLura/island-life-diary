#ifndef TEMPORAL_SHADOW_SH
#define TEMPORAL_SHADOW_SH

uniform hvec4 u_TemporalShadowBounds[4];
uniform hvec4 u_TemporalShadowBlendStart;
uniform hvec4 u_TemporalShadowBlendEnd; // xyz = band ends, w = valid cascade count

void TemporalShadowSelect(hfloat depth, out int split, out hfloat weight)
{
    int count = int(u_TemporalShadowBlendEnd.w);
    split = max(count - 1, 0);
    weight = 0.0;
    for (int i = 0; i < 3; ++i)
    {
        if (i + 1 < count && depth < u_TemporalShadowBlendEnd[i])
        {
            split = i;
            hfloat start = u_TemporalShadowBlendStart[i];
            hfloat end = u_TemporalShadowBlendEnd[i];
            if (end > start)
                weight = smoothstep(start, end, depth);
            break;
        }
    }
}

bool TemporalShadowPositionValid(hvec4 position, int split)
{
    hvec4 bounds = u_TemporalShadowBounds[split];
    return position.w > 0.0 && all(greaterThanEqual(position.xy, bounds.xy * position.w)) &&
        all(lessThanEqual(position.xy, bounds.zw * position.w)) && position.z >= 0.0 && position.z <= position.w;
}

hfloat TemporalShadowBlendVisibility(hfloat first, hfloat second, bool firstValid, bool secondValid, hfloat weight)
{
    if (!firstValid)
        return secondValid ? second : 1.0;
    if (!secondValid)
        return first;
    return mix(first, second, weight);
}

#endif
