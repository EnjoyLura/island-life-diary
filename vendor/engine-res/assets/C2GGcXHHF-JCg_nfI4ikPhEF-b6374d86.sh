#ifndef SURFACE_LIGHTING_POSITION_SH
#define SURFACE_LIGHTING_POSITION_SH

#if defined(MATERIAL_LIGHT_POSITION) && defined(CLUSTER_VS)
    #error LIGHT_VERTEX requires per-pixel cluster lighting; vertex cluster approximation cannot consume fragment outputs.
#endif

#if COMPILEPS && defined(MATERIAL_LIGHT_POSITION) && defined(SHADOW)
uniform hvec4 u_DepthMode; // Existing View-owned normalized shadow-depth convention.
// Rebuild receiver coordinates after the fragment override. Geometry and caster passes retain
// their own positions. Match the engine's existing cascade selection, normal bias and fade.
float SurfaceGetLightingShadow(hvec3 worldPosition, vec3 geometricNormal)
{
    hvec4 receiver = hvec4_init(worldPosition, 1.0);
    #ifdef DIRLIGHT
        hvec4 receiverClip = mul(mul(receiver, cView), cProj);
        hfloat depth = dot(receiverClip.zw, u_DepthMode.zw);
        int cascade = 0;
        #ifdef DESKTOP_SHADOW_CASCADE
            if (depth >= cShadowSplits.x) cascade = 1;
            if (depth >= cShadowSplits.y) cascade = 2;
            if (depth >= cShadowSplits.z) cascade = 3;
        #elif defined(MOBILE_SHADOW_CASCADE)
            if (depth >= cShadowSplits.x) cascade = 1;
        #endif
        #ifdef NORMALOFFSET
            float cosAngle = clamp(1.0 - dot(geometricNormal, cLightDirPS), 0.0, 1.0);
            receiver.xyz += cosAngle * cNormalOffsetScalePS[cascade] * geometricNormal;
        #endif
        return GetDirShadowFade(GetShadow(mul(receiver, cLightMatricesPS[cascade])), depth);
    #else
        #ifdef NORMALOFFSET
            float cosAngle = clamp(1.0 - dot(geometricNormal, normalize(cLightPosPS.xyz - worldPosition)), 0.0, 1.0);
            receiver.xyz += cosAngle * cNormalOffsetScalePS.x * geometricNormal;
        #endif
        #ifdef SPOTLIGHT
            return GetShadow(mul(receiver, cLightMatricesPS[1]));
        #else
            return GetPointShadow(receiver.xyz - cLightPosPS.xyz);
        #endif
    #endif
}
#endif

#endif
