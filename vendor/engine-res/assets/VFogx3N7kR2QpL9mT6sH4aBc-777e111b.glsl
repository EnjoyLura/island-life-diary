#include "varying_quad.def.sc"
#include "urho3d_compatibility.sh"

#ifdef COMPILEVS
    $input a_position
    $output vTexCoord, vScreenPos
#endif
#ifdef COMPILEPS
    $input vTexCoord, vScreenPos
#endif

#include "Common/common.sh"
#include "uniforms.sh"
#include "samplers.sh"
#include "transform.sh"
#include "screen_pos.sh"
#include "ScreenSpace/ScreenSpaceCommon.sh"

void VS()
{
    hmat4 modelMatrix = iModelMatrix;
    hvec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vTexCoord = GetQuadTexCoord(gl_Position);
    vScreenPos = GetScreenPosPreDiv(gl_Position);
}

#ifdef COMPILEPS

SAMPLER2D(u_DepthBuffer0, 0);

#include "Volumetric/VolumetricFogIntegration.sh"

#if defined(VOLUMETRIC_FOG_FROXEL_DEBUG) || defined(VOLUMETRIC_FOG_FROXEL_COMPOSITE)
SAMPLER3D(u_FroxelVBufferA5, 5);
uniform hvec4 u_FroxelGridParams;               // B, O, S, grid size Z
uniform hvec4 u_FroxelCamForward;               // xyz = camera world forward (normalized)
#endif

void PS()
{
    hvec2 uv = vTexCoord;
    hfloat rawDepth = texture2D(u_DepthBuffer0, uv).r;
#if defined(VOLUMETRIC_FOG_FROXEL_DEBUG) || defined(VOLUMETRIC_FOG_FROXEL_COMPOSITE)
    // froxel 合成对天空/无几何像素同样生效（UE 语义）：clamp 到远平面距离取全量积分，不早退
#ifdef REVERSED_Z
    rawDepth = max(rawDepth, 0.00001);
#else
    rawDepth = min(rawDepth, 0.99999);
#endif
#else
    if (IsSceneFarDepth(rawDepth, 0.00001))
    {
        gl_FragColor = hvec4_init(0.0, 0.0, 0.0, 0.0);
        return;
    }
#endif

    hvec4 sceneWorld = ReconstructWorldPosition(uv, rawDepth);
    hvec3 cameraPos = cCameraPosPS;
    hvec3 ray = sceneWorld.xyz - cameraPos;
    hfloat sceneDistance = length(ray);
    if (sceneDistance <= 0.0001)
    {
        gl_FragColor = hvec4_init(0.0, 0.0, 0.0, 0.0);
        return;
    }

    hvec3 rayDir = ray / sceneDistance;

#if defined(VOLUMETRIC_FOG_FROXEL_DEBUG) || defined(VOLUMETRIC_FOG_FROXEL_COMPOSITE)
    // froxel 切片按 view-Z 分布（UE ComputeNormalizedZSliceFromDepth 同口径）
    hfloat sceneViewZ = dot(ray, u_FroxelCamForward.xyz);
#endif

#ifdef VOLUMETRIC_FOG_FROXEL_DEBUG
    // 调试：可视化 froxel VBufferA 在场景表面处的介质（view-Z slice 映射与 FroxelMediaCS 一致）。
    // log2 参数钳正：startDistance 较大时 GridZParams 的 O 为负，比雾起点更近的几何
    // 会使参数非正 → NaN（口径同 C++ VolumetricFogGrid::DepthToSlice）
    hfloat debugSlice = log2(max(sceneViewZ * u_FroxelGridParams.x + u_FroxelGridParams.y, 1e-8)) * u_FroxelGridParams.z;
    hfloat debugW = clamp(debugSlice / u_FroxelGridParams.w, 0.0, 1.0);
    hvec4 debugMedia = texture3DLod(u_FroxelVBufferA5, vec3(uv, debugW), 0.0);
    gl_FragColor = hvec4_init(debugMedia.r, debugMedia.g, debugMedia.b, 1.0);
    return;
#endif

#ifdef VOLUMETRIC_FOG_FROXEL_COMPOSITE
    // froxel 合成（UE 语义，premultiplied alpha 混合）：
    //   rgb = 积分 in-scatter，a = min(1 - transmittance, maxOpacity)
    //   dst = src.rgb + dst.rgb * (1 - src.a)，场景被介质透射率真实遮挡。
    // 累积场采样：integrated[k] = 到 slice k 远边界的积分，对场景所在连续坐标 s
    // 取 w=(s-0.5)/gridZ 使 bilinear 在 [integral(0..s_floor), integral(0..s_floor+1)] 间按段内比例插值
    // log2 参数钳正：startDistance 较大时 O 为负，雾起点前的几何会得到非正参数 → NaN，
    // GLSL min/max 对 NaN 行为未定义 → froxelW 未定义 → 近处几何上出现随机雾。
    // 钳后这些像素采样 slice 0（含起点前极薄一段积分，切片厚度下可忽略）
    hfloat froxelSlice = log2(max(sceneViewZ * u_FroxelGridParams.x + u_FroxelGridParams.y, 1e-8)) * u_FroxelGridParams.z;
    hfloat froxelW = clamp((froxelSlice - 0.5) / u_FroxelGridParams.w, 0.0, 1.0);
    hvec4 froxelIntegrated = texture3DLod(u_FroxelVBufferA5, vec3(uv, froxelW), 0.0);
    hfloat froxelOpacity = clamp(1.0 - froxelIntegrated.w, 0.0, u_VolumetricFogParams2.y);
    gl_FragColor = hvec4_init(froxelIntegrated.x, froxelIntegrated.y, froxelIntegrated.z, froxelOpacity);
    return;
#endif

    hvec3 scattering = EvaluateLegacyVolumetricFog(uv, cameraPos, sceneWorld.xyz);
    gl_FragColor = hvec4_init(scattering.x, scattering.y, scattering.z, 1.0);
}

#endif
