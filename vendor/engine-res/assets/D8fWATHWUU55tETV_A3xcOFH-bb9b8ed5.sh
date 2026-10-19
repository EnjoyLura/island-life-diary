#ifndef __LAMBERT_SH__
#define __LAMBERT_SH__

#include "lighting.sh"
#if defined (CLUSTER) && defined(COMPILEPS)
#include "Cluster/clusterlights.sh"
#include "Cluster/clusters.sh"
#endif
#if defined(COMPILEPS) && (defined(CLUSTER) || defined(DEFERRED))
#include "PBR/GI.sh"
#endif
#if COMPILEPS
vec3 LambertBRDF(vec3 diffColor, vec4 specColor, hvec3 worldPos, vec3 normal, hvec3 shadow, float occlusion
#ifdef DEFERRED_CLUSTER
    , hfloat sceneDepth
#endif
)
{
    vec3 ret = vec3_splat(0.0);
    hvec3 lightColor;
    vec3 lightDir;
    vec3 finalColor;

    #if !defined(LIGHTVOLUME_BASE_ONLY) && ((defined(DIRLIGHT) && !defined(CLUSTER_BASE)) || !defined(CLUSTER))
        // Per-pixel forward lighting
        hvec3 diff = GetDiffuse(normal, worldPos, lightDir) * shadow * M_INV_PI; // 使用物理灯所以/PI
    
        #if defined(DEFERRED)
            // Deferred light volumes reconstruct position instead of using forward projection varyings.
            lightColor = GI_GetLightColor(worldPos);
        #elif defined(SPOTLIGHT)
            lightColor = vSpotPos.w > 0.0 ? texture2DProj(sLightSpotMap, vSpotPos).rgb * cLightColor.rgb : hvec3_init(0.0, 0.0, 0.0);
        #elif defined(CUBEMASK)
            lightColor = textureCube(sLightCubeMap, vCubeMaskVec).rgb * cLightColor.rgb;
        #else
            lightColor = cLightColor.rgb;
        #endif
        #ifdef SPECULAR
            hfloat spec = GetSpecular(normal, cCameraPosPS - worldPos, lightDir, specColor.a);
            finalColor = diff * lightColor * (diffColor + spec * specColor.rgb);
        #else
            finalColor = diff * lightColor * diffColor;
        #endif 
        ret += finalColor;
    #endif
    
#if defined(LIGHTMAP)

#if defined(SCE_GRASS)
    vec4 lightMapColor = GetLambertGrassLightMapColor(vLightMapUV.xy, normal, worldPos);
    ret += diffColor * lightMapColor.rgb;
#else// SCE_GRASS

#if RENDER_QUALITY >= RENDER_QUALITY_HIGH && defined(LIGHTMAP_DIRECTIONALITY)
    vec3 lightMapDir;
    vec4 lightMapColor = GetLightMapColor(vLightMapUV.xy, normal, lightMapDir);
#if  defined(SPECULAR)
    ret += lightMapColor.rgb * (diffColor + M_PI * GetSpecular(normal, cCameraPosPS - worldPos, lightMapDir, specColor.a) * specColor.rgb);
#else//SPECULAR
    ret += lightMapColor.rgb * diffColor;
#endif
#else// RENDER_QUALITY >= RENDER_QUALITY_HIGH && defined(LIGHTMAP_DIRECTIONALITY)
    vec4 lightMapColor = GetLightMapColor(vLightMapUV.xy, normal);
    ret += diffColor * lightMapColor.rgb;
#endif// RENDER_QUALITY >= RENDER_QUALITY_HIGH && defined(LIGHTMAP_DIRECTIONALITY)

#endif// SPEED_GRASS

#endif// LIGHTMAP

    #if defined(CLUSTER)
        // Cluster render for pointlight
        #ifdef DEFERRED_CLUSTER
            uint cluster = getDeferredClusterIndex(gl_FragCoord.xy, sceneDepth);
        #else
            // 这里从gl_FragCoord减去viewport的起点，得到viewport坐标
            hvec4 realCoord = getRealCoord(gl_FragCoord);
            uint cluster = getClusterIndex(realCoord);
        #endif
        #ifdef CLUSTER_LOCAL_SHADOWS
            hvec3 localShadowNormal = GetClusterShadowNormal(worldPos, normal);
        #endif
        LightGrid grid = getLightGrid(cluster);
        finalColor = vec3(0.0,0.0,0.0);
        for(uint i = 0u; i < grid.pointLights; i++)
        {
            uint lightIndex = GetGridLightIndex(grid.offset, i);
#ifdef CLUSTER_SPOTLIGHT
            SpotLight light = GetSpotLight(lightIndex);
#else
            PointLight light = GetPointLight(lightIndex);
#endif
            // 统一了衰减计算同PBR一致
            lightColor = light.intensity;
            float attenuation = GI_PointLight_GetAttenAndLightDir(worldPos, light.position, light.range, lightDir);

#ifdef CLUSTER_SPOTLIGHT
            attenuation *= GetLightDirectionFalloff(lightDir, light.direction, light.cosOuterCone, light.invCosConeDiff);
#endif
            #ifdef CLUSTER_LOCAL_SHADOWS
                if (attenuation > 0.0)
                    attenuation *= SampleClusterLocalShadow(light.shadowIndex, worldPos, localShadowNormal);
            #endif
            #ifdef SPECULAR
                hfloat spec = GetSpecular(normal, cCameraPosPS - worldPos, lightDir, specColor.a);
                finalColor += attenuation * lightColor * (diffColor * M_INV_PI + spec * specColor.rgb);
            #else
                finalColor += attenuation * lightColor * diffColor * M_INV_PI;
            #endif
        }
        ret += finalColor;
    #endif
    
    #ifdef AMBIENT
        // AO
        #if defined(AO) && !defined(CLOSE_AO)
            #if defined(DEFERRED)
                hvec2 aoUV = vScreenPos.xy;
                #ifndef DIRLIGHT
                    aoUV /= max(vScreenPos.w, 0.0001);
                #endif
                occlusion *= texture2D(sAOMap, aoUV).r;
            #else
                #if defined(SSAO)
                    // shaderc 将 gl_FragCoord.w 统一为 1/clip.w，用它消除 vAOUV 透视插值携带的 clip.w。
                    occlusion = occlusion * texture2D(sAOMap, vAOUV * gl_FragCoord.w * 0.5 + 0.5).r;
                #else
                    occlusion = occlusion * texture2D(sAOMap, vAOUV).r;
                #endif
            #endif
        #endif

        #if defined(ENVCUBE) && UNITY_SHOULD_SAMPLE_SH
            vec3 cubeN = normal;
            cubeN.xy = vec2(dot(cubeN.xy, vec2(u_SinCosEnvCubeAngle.y, -u_SinCosEnvCubeAngle.x)), dot(cubeN.xy, u_SinCosEnvCubeAngle.xy));
            cubeN = vec3(cubeN.x, cubeN.z, cubeN.y);
            ret += ShadeSHPerPixel(cubeN, cAmbientColor.rgb, cEnvDiffTextureIntensity) * diffColor * occlusion;
        #else
            ret += cAmbientColor.rgb * diffColor * occlusion;
        #endif
    #endif    
    return ret;
}
#endif

#endif
