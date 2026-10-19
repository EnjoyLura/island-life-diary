#ifndef __SURFACE_GODOT_MATRICES_SH__
#define __SURFACE_GODOT_MATRICES_SH__

#include "SurfaceShaderCompatibility.sh"
#include "SurfaceGodotRelations.sh"

// Older generated shaders lack the usage flag; unused uniforms are stripped by shader compilation.
#if COMPILEPS && (defined(SURFACE_USES_FRONT_FACING) || SURFACE_SHADER_ABI_VERSION < 7)
uniform float u_CameraReverseCulling;
// UrhoX cull_back keeps the native back face. Match its camera-dependent culling reversal,
// including GL render-target projection flips, without hiding mirrored mesh winding.
#define SURFACE_FRONT_FACING (gl_FrontFacing == (u_CameraReverseCulling > 0.5))
#endif

// UrhoX transforms vectors on the left. Godot exposes matrices for column-vector multiplication,
// so built-in matrices must be transposed before generated Godot-style code consumes them.
hmat4 SurfaceGodotMatrix(hmat4 engineMatrix)
{
    return transpose(engineMatrix);
}

hmat4 SurfaceGodotModelMatrix(hmat4 modelMatrix)
{
    return SurfaceGodotMatrix(modelMatrix);
}

// Matrix constructors selected by the AST. Indexed vectors are rows in HLSL and columns in GLSL;
// rebuilding them in the same order preserves orientation on either path. Arguments are evaluated once.
// Old GLSL runtimes lack the 2x2 matrix type alias, even for unused helpers.
#if SURFACE_SHADER_ABI_VERSION >= 2
hmat2 SurfaceGodotMat2FromMat3(hmat3 value)
{
    return hmat2_init(value[0].xy, value[1].xy);
}

hmat2 SurfaceGodotMat2FromMat4(hmat4 value)
{
    return hmat2_init(value[0].xy, value[1].xy);
}

hmat3 SurfaceGodotMat3FromMat2(hmat2 value)
{
    return hmat3_init(hvec3_init(value[0], 0.0), hvec3_init(value[1], 0.0), hvec3_init(0.0, 0.0, 1.0));
}
#endif

hmat3 SurfaceGodotMat3FromMat4(hmat4 value)
{
    return hmat3_init(value[0].xyz, value[1].xyz, value[2].xyz);
}

#if SURFACE_SHADER_ABI_VERSION >= 2
hmat4 SurfaceGodotMat4FromMat2(hmat2 value)
{
    return hmat4_init(hvec4_init(value[0], 0.0, 0.0), hvec4_init(value[1], 0.0, 0.0),
        hvec4_init(0.0, 0.0, 1.0, 0.0), hvec4_init(0.0, 0.0, 0.0, 1.0));
}
#endif

hmat4 SurfaceGodotMat4FromMat3(hmat3 value)
{
    return hmat4_init(hvec4_init(value[0], 0.0), hvec4_init(value[1], 0.0), hvec4_init(value[2], 0.0),
        hvec4_init(0.0, 0.0, 0.0, 1.0));
}

// GLSL scalar construction fills only the diagonal, unlike an HLSL scalar-to-matrix cast.
#if SURFACE_SHADER_ABI_VERSION >= 2
hmat2 SurfaceGodotMat2Diagonal(hfloat value)
{
    return hmat2_init(value, 0.0, 0.0, value);
}
#endif

hmat3 SurfaceGodotMat3Diagonal(hfloat value)
{
    return hmat3_init(value, 0.0, 0.0, 0.0, value, 0.0, 0.0, 0.0, value);
}

hmat4 SurfaceGodotMat4Diagonal(hfloat value)
{
    return hmat4_init(value, 0.0, 0.0, 0.0, 0.0, value, 0.0, 0.0,
        0.0, 0.0, value, 0.0, 0.0, 0.0, 0.0, value);
}

// Cofactor construction avoids backend-specific inverse(mat3) support. A singular transform
// has no inverse; use identity instead of propagating NaNs into downstream normalization.
hmat3 SurfaceGodotNormalMatrix(hmat4 modelMatrix)
{
    hvec3 x = mul(hvec4_init(1.0, 0.0, 0.0, 0.0), modelMatrix).xyz;
    hvec3 y = mul(hvec4_init(0.0, 1.0, 0.0, 0.0), modelMatrix).xyz;
    hvec3 z = mul(hvec4_init(0.0, 0.0, 1.0, 0.0), modelMatrix).xyz;
    hvec3 axisScale = hvec3_init(length(x), length(y), length(z));
    if (min(axisScale.x, min(axisScale.y, axisScale.z)) == 0.0)
        return hmat3_init(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0);
    x /= axisScale.x;
    y /= axisScale.y;
    z /= axisScale.z;
    hvec3 cx = cross(y, z);
    hvec3 cy = cross(z, x);
    hvec3 cz = cross(x, y);
    hfloat determinant = dot(x, cx);
    if (abs(determinant) < 1e-8)
        return hmat3_init(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0);
    // Test linear dependence independently of scale, then restore the inverse axis lengths.
    cx /= determinant * axisScale.x;
    cy /= determinant * axisScale.y;
    cz /= determinant * axisScale.z;
#if BGFX_SHADER_DIALECT_HLSL
    return transpose(hmat3_init(cx, cy, cz));
#else
    return hmat3_init(cx, cy, cz);
#endif
}

hmat3 SurfaceGodotModelNormalMatrix(hmat4 modelMatrix)
{
#if COMPILEPS && defined(SURFACE_USES_FRAGMENT_MODEL_NORMAL)
    #if BGFX_SHADER_DIALECT_HLSL
        return transpose(hmat3_init(vSurfaceNormalMatrixX, vSurfaceNormalMatrixY, vSurfaceNormalMatrixZ));
    #else
        return hmat3_init(vSurfaceNormalMatrixX, vSurfaceNormalMatrixY, vSurfaceNormalMatrixZ);
    #endif
#else
    return SurfaceGodotNormalMatrix(modelMatrix);
#endif
}

#if COMPILEVS
#if BGFX_SHADER_DIALECT_HLSL
static hfloat surfaceEvaluationTime;
#else
hfloat surfaceEvaluationTime;
#endif
#define SURFACE_TIME surfaceEvaluationTime
#if defined(SURFACE_USES_BONE_INPUTS) && defined(SKINNED_CS)
#error SurfaceShader bone inputs require original vertex skinning streams; compute-skinned geometry is not supported yet.
#endif
#if defined(SKINNED) || defined(SKIN_MATRIX_TEXTURE)
#define SURFACE_BONE_INDICES uvec4(iBlendIndices)
#define SURFACE_BONE_WEIGHTS iBlendWeights
#else
#define SURFACE_BONE_INDICES uvec4(0u, 0u, 0u, 0u)
#define SURFACE_BONE_WEIGHTS vec4_splat(0.0)
#endif
#if defined(SURFACE_USES_INSTANCE_ID) && defined(INSTANCED)
#define SURFACE_INSTANCE_ID int(gl_InstanceID)
#else
#define SURFACE_INSTANCE_ID 0
#endif
hvec4 SurfaceSelectClipPosition(hvec4 projectedPosition, hvec4 materialPosition)
{
#ifdef SURFACE_WRITES_POSITION
    return materialPosition;
#else
    return projectedPosition;
#endif
}
hvec4 SurfaceApplyZClipScale(hvec4 position, hfloat scale)
{
#if defined(SURFACE_USES_Z_CLIP_SCALE) && !defined(SURFACE_SHADOW_ONLY) && !defined(SURFACE_SHADOW_CASTER)
#ifdef REVERSED_Z
    position.z = mix(position.w, position.z, scale);
#elif BGFX_SHADER_LANGUAGE_GLSL
    position.z = mix(-position.w, position.z, scale);
#else
    position.z *= scale;
#endif
#endif
    return position;
}
vec2 SurfaceGetUV2()
{
#if defined(SURFACE_USES_UV2) && !defined(BILLBOARD) && !defined(DIRBILLBOARD) && !defined(TRAILFACECAM) && !defined(TRAILBONE) && !defined(VOXELPACKED)
    return iTexCoord1.xy;
#else
    return vec2(0.0, 0.0);
#endif
}
#ifdef SURFACE_USES_GODOT_PROJECTION
// Vertex input is a homogeneous clip vector in the same convention as PROJECTION_MATRIX.
// Unlike the screen-depth fragment helper this must preserve w and orthographic projections.
hvec4 SurfaceGodotInvProjectionMul(hvec4 clipPosition)
{
    return mul(clipPosition, cInvProj);
}
#endif
#endif

vec3 SurfaceNormalizeOrZero(vec3 value)
{
    return value * inversesqrt(max(dot(value, value), 1e-20));
}

#if COMPILEPS && defined(SURFACE_USES_NORMAL_MAP)
vec3 SurfaceApplyNormalMap(vec3 encodedNormal, float strength, vec3 normal, vec3 tangent, vec3 binormal)
{
    if (strength == 0.0)
        return normalize(normal);
    // Preserve UrhoX RGB decoding and the native TBN at the default strength.
    mat3 tbn = TR(mat3(tangent, binormal, normal));
    vec3 mapped = normalize(mul(tbn, encodedNormal * 2.0 - 1.0));
    if (strength == 1.0)
        return mapped;
    return normalize(mix(normalize(normal), mapped, strength));
}
#endif

#if COMPILEPS
#define SURFACE_TIME cElapsedTime
#endif

#if COMPILEVS && defined(VELOCITY_PASS)
hvec4 SurfaceHistoryInvProjectionMul(hmat4 inverseProjection, hvec4 clipPosition)
{
    return mul(clipPosition, inverseProjection);
}
#endif

// Preserve Godot scalar vector equality without float conversion of integer operands.
bool SurfaceGodotEqual(hvec2 a, hvec2 b)
{
#if BGFX_SHADER_DIALECT_HLSL
    return all(a == b);
#else
    return a == b;
#endif
}
bool SurfaceGodotEqual(ivec2 a, ivec2 b)
{
    float difference = (a.x == b.x ? 0.0 : 1.0) + (a.y == b.y ? 0.0 : 1.0);
    return difference < 0.5;
}
bool SurfaceGodotEqual(uvec2 a, uvec2 b)
{
    float difference = (a.x == b.x ? 0.0 : 1.0) + (a.y == b.y ? 0.0 : 1.0);
    return difference < 0.5;
}
// Use exact 0/1 floats for boolean equality: HLSLcc may mix 1 and all-bit boolean masks.
bool SurfaceGodotEqual(bvec2 a, bvec2 b)
{
    float difference = abs((a.x ? 1.0 : 0.0) - (b.x ? 1.0 : 0.0)) + abs((a.y ? 1.0 : 0.0) - (b.y ? 1.0 : 0.0));
    return difference < 0.5;
}
hvec2 SurfaceGodotColumn(hmat2 matrixValue, int column)
{
    return mul(matrixValue, hvec2_init(column == 0 ? 1.0 : 0.0, column == 1 ? 1.0 : 0.0));
}
bool SurfaceGodotEqual(hvec3 a, hvec3 b)
{
#if BGFX_SHADER_DIALECT_HLSL
    return all(a == b);
#else
    return a == b;
#endif
}
bool SurfaceGodotEqual(ivec3 a, ivec3 b)
{
    float difference = (a.x == b.x ? 0.0 : 1.0) + (a.y == b.y ? 0.0 : 1.0) + (a.z == b.z ? 0.0 : 1.0);
    return difference < 0.5;
}
bool SurfaceGodotEqual(uvec3 a, uvec3 b)
{
    float difference = (a.x == b.x ? 0.0 : 1.0) + (a.y == b.y ? 0.0 : 1.0) + (a.z == b.z ? 0.0 : 1.0);
    return difference < 0.5;
}
bool SurfaceGodotEqual(bvec3 a, bvec3 b)
{
    float difference = abs((a.x ? 1.0 : 0.0) - (b.x ? 1.0 : 0.0)) + abs((a.y ? 1.0 : 0.0) - (b.y ? 1.0 : 0.0)) + abs((a.z ? 1.0 : 0.0) - (b.z ? 1.0 : 0.0));
    return difference < 0.5;
}
hvec3 SurfaceGodotColumn(hmat3 matrixValue, int column)
{
    return mul(matrixValue, hvec3_init(column == 0 ? 1.0 : 0.0, column == 1 ? 1.0 : 0.0, column == 2 ? 1.0 : 0.0));
}
bool SurfaceGodotEqual(hvec4 a, hvec4 b)
{
#if BGFX_SHADER_DIALECT_HLSL
    return all(a == b);
#else
    return a == b;
#endif
}
bool SurfaceGodotEqual(ivec4 a, ivec4 b)
{
    float difference = (a.x == b.x ? 0.0 : 1.0) + (a.y == b.y ? 0.0 : 1.0) + (a.z == b.z ? 0.0 : 1.0) + (a.w == b.w ? 0.0 : 1.0);
    return difference < 0.5;
}
bool SurfaceGodotEqual(uvec4 a, uvec4 b)
{
    float difference = (a.x == b.x ? 0.0 : 1.0) + (a.y == b.y ? 0.0 : 1.0) + (a.z == b.z ? 0.0 : 1.0) + (a.w == b.w ? 0.0 : 1.0);
    return difference < 0.5;
}
bool SurfaceGodotEqual(bvec4 a, bvec4 b)
{
    float difference = abs((a.x ? 1.0 : 0.0) - (b.x ? 1.0 : 0.0)) + abs((a.y ? 1.0 : 0.0) - (b.y ? 1.0 : 0.0)) + abs((a.z ? 1.0 : 0.0) - (b.z ? 1.0 : 0.0)) + abs((a.w ? 1.0 : 0.0) - (b.w ? 1.0 : 0.0));
    return difference < 0.5;
}
hvec4 SurfaceGodotColumn(hmat4 matrixValue, int column)
{
    return mul(matrixValue, hvec4_init(column == 0 ? 1.0 : 0.0, column == 1 ? 1.0 : 0.0, column == 2 ? 1.0 : 0.0, column == 3 ? 1.0 : 0.0));
}

// Matrix compound assignment cannot use a raw *= across shader languages. inout keeps complex
// lvalues single-evaluation while the return value preserves assignment-expression semantics.
#if SURFACE_SHADER_ABI_VERSION >= 2
hvec2 SurfaceGodotMulAssign(inout hvec2 lhs, hmat2 rhs) { lhs = mul(lhs, rhs); return lhs; }
#endif
hvec3 SurfaceGodotMulAssign(inout hvec3 lhs, hmat3 rhs) { lhs = mul(lhs, rhs); return lhs; }
hvec4 SurfaceGodotMulAssign(inout hvec4 lhs, hmat4 rhs) { lhs = mul(lhs, rhs); return lhs; }
#if SURFACE_SHADER_ABI_VERSION >= 2
hmat2 SurfaceGodotMulAssign(inout hmat2 lhs, hmat2 rhs) { lhs = mul(lhs, rhs); return lhs; }
#endif
hmat3 SurfaceGodotMulAssign(inout hmat3 lhs, hmat3 rhs) { lhs = mul(lhs, rhs); return lhs; }
hmat4 SurfaceGodotMulAssign(inout hmat4 lhs, hmat4 rhs) { lhs = mul(lhs, rhs); return lhs; }


// Author matrices are column-constructed on every backend. HLSL-dialect
// constructors consume rows, while GLSL-dialect constructors consume columns.
#if BGFX_SHADER_DIALECT_HLSL
#define SURFACE_GODOT_MATRIX_INPUT(_m) transpose(_m)
#define SURFACE_GODOT_MATRIX_ELEMENT(_m, _c, _r) (_m)[_r][_c]
#else
#define SURFACE_GODOT_MATRIX_INPUT(_m) (_m)
#define SURFACE_GODOT_MATRIX_ELEMENT(_m, _c, _r) (_m)[_c][_r]
#endif
hmat2 SurfaceGodotMat2(hfloat value) { return hmat2_init(value, 0.0, 0.0, value); }
hmat2 SurfaceGodotMat2(hmat2 value) { return value; }
hmat2 SurfaceGodotMat2(hmat3 value) { return SURFACE_GODOT_MATRIX_INPUT(hmat2_init(SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 1), SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 1))); }
hmat2 SurfaceGodotMat2(hmat4 value) { return SURFACE_GODOT_MATRIX_INPUT(hmat2_init(SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 1), SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 1))); }
hfloat SurfaceGodotWriteColumn(inout hmat2 matrixValue, int column, int rows, hfloat value, int operation)
{
    hfloat oldValue = SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows);
    hfloat result = value;
    if (operation == 1 || operation == 5) result = oldValue + value;
    if (operation == 2 || operation == 6) result = oldValue - value;
    if (operation == 3) result = oldValue * value;
    if (operation == 4) result = oldValue / value;
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows) = result;
    return operation >= 5 ? oldValue : result;
}
hvec2 SurfaceGodotWriteColumn(inout hmat2 matrixValue, int column, ivec2 rows, hvec2 value, int operation)
{
    hvec2 oldValue = hvec2_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]));
    hvec2 result = value;
    if (operation == 1 || operation == 5) result = oldValue + value;
    if (operation == 2 || operation == 6) result = oldValue - value;
    if (operation == 3) result = oldValue * value;
    if (operation == 4) result = oldValue / value;
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]) = result[0];
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]) = result[1];
    return operation >= 5 ? oldValue : result;
}
hmat3 SurfaceGodotMat3(hfloat value) { return hmat3_init(value, 0.0, 0.0, 0.0, value, 0.0, 0.0, 0.0, value); }
hmat3 SurfaceGodotMat3(hmat2 value) { return SURFACE_GODOT_MATRIX_INPUT(hmat3_init(SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 1), 0.0, SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 1), 0.0, 0.0, 0.0, 1.0)); }
hmat3 SurfaceGodotMat3(hmat3 value) { return value; }
hmat3 SurfaceGodotMat3(hmat4 value) { return SURFACE_GODOT_MATRIX_INPUT(hmat3_init(SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 1), SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 2), SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 1), SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 2), SURFACE_GODOT_MATRIX_ELEMENT(value, 2, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 2, 1), SURFACE_GODOT_MATRIX_ELEMENT(value, 2, 2))); }
hfloat SurfaceGodotWriteColumn(inout hmat3 matrixValue, int column, int rows, hfloat value, int operation)
{
    hfloat oldValue = SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows);
    hfloat result = value;
    if (operation == 1 || operation == 5) result = oldValue + value;
    if (operation == 2 || operation == 6) result = oldValue - value;
    if (operation == 3) result = oldValue * value;
    if (operation == 4) result = oldValue / value;
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows) = result;
    return operation >= 5 ? oldValue : result;
}
hvec2 SurfaceGodotWriteColumn(inout hmat3 matrixValue, int column, ivec2 rows, hvec2 value, int operation)
{
    hvec2 oldValue = hvec2_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]));
    hvec2 result = value;
    if (operation == 1 || operation == 5) result = oldValue + value;
    if (operation == 2 || operation == 6) result = oldValue - value;
    if (operation == 3) result = oldValue * value;
    if (operation == 4) result = oldValue / value;
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]) = result[0];
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]) = result[1];
    return operation >= 5 ? oldValue : result;
}
hvec3 SurfaceGodotWriteColumn(inout hmat3 matrixValue, int column, ivec3 rows, hvec3 value, int operation)
{
    hvec3 oldValue = hvec3_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[2]));
    hvec3 result = value;
    if (operation == 1 || operation == 5) result = oldValue + value;
    if (operation == 2 || operation == 6) result = oldValue - value;
    if (operation == 3) result = oldValue * value;
    if (operation == 4) result = oldValue / value;
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]) = result[0];
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]) = result[1];
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[2]) = result[2];
    return operation >= 5 ? oldValue : result;
}
hmat4 SurfaceGodotMat4(hfloat value) { return hmat4_init(value, 0.0, 0.0, 0.0, 0.0, value, 0.0, 0.0, 0.0, 0.0, value, 0.0, 0.0, 0.0, 0.0, value); }
hmat4 SurfaceGodotMat4(hmat2 value) { return SURFACE_GODOT_MATRIX_INPUT(hmat4_init(SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 1), 0.0, 0.0, SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 1), 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0)); }
hmat4 SurfaceGodotMat4(hmat3 value) { return SURFACE_GODOT_MATRIX_INPUT(hmat4_init(SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 1), SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 2), 0.0, SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 1), SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 2), 0.0, SURFACE_GODOT_MATRIX_ELEMENT(value, 2, 0), SURFACE_GODOT_MATRIX_ELEMENT(value, 2, 1), SURFACE_GODOT_MATRIX_ELEMENT(value, 2, 2), 0.0, 0.0, 0.0, 0.0, 1.0)); }
hmat4 SurfaceGodotMat4(hmat4 value) { return value; }
hfloat SurfaceGodotWriteColumn(inout hmat4 matrixValue, int column, int rows, hfloat value, int operation)
{
    hfloat oldValue = SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows);
    hfloat result = value;
    if (operation == 1 || operation == 5) result = oldValue + value;
    if (operation == 2 || operation == 6) result = oldValue - value;
    if (operation == 3) result = oldValue * value;
    if (operation == 4) result = oldValue / value;
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows) = result;
    return operation >= 5 ? oldValue : result;
}
hvec2 SurfaceGodotWriteColumn(inout hmat4 matrixValue, int column, ivec2 rows, hvec2 value, int operation)
{
    hvec2 oldValue = hvec2_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]));
    hvec2 result = value;
    if (operation == 1 || operation == 5) result = oldValue + value;
    if (operation == 2 || operation == 6) result = oldValue - value;
    if (operation == 3) result = oldValue * value;
    if (operation == 4) result = oldValue / value;
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]) = result[0];
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]) = result[1];
    return operation >= 5 ? oldValue : result;
}
hvec3 SurfaceGodotWriteColumn(inout hmat4 matrixValue, int column, ivec3 rows, hvec3 value, int operation)
{
    hvec3 oldValue = hvec3_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[2]));
    hvec3 result = value;
    if (operation == 1 || operation == 5) result = oldValue + value;
    if (operation == 2 || operation == 6) result = oldValue - value;
    if (operation == 3) result = oldValue * value;
    if (operation == 4) result = oldValue / value;
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]) = result[0];
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]) = result[1];
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[2]) = result[2];
    return operation >= 5 ? oldValue : result;
}
hvec4 SurfaceGodotWriteColumn(inout hmat4 matrixValue, int column, ivec4 rows, hvec4 value, int operation)
{
    hvec4 oldValue = hvec4_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[2]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[3]));
    hvec4 result = value;
    if (operation == 1 || operation == 5) result = oldValue + value;
    if (operation == 2 || operation == 6) result = oldValue - value;
    if (operation == 3) result = oldValue * value;
    if (operation == 4) result = oldValue / value;
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]) = result[0];
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]) = result[1];
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[2]) = result[2];
    SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[3]) = result[3];
    return operation >= 5 ? oldValue : result;
}


// Matrix builtins unavailable or differently defined in the HLSL language.
hmat2 SurfaceGodotInverse(hmat2 value)
{
#if BGFX_SHADER_DIALECT_HLSL
    hfloat inverseDeterminant = 1.0 / determinant(value);
    return SURFACE_GODOT_MATRIX_INPUT(hmat2_init(
        SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 1),
        -SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 1),
        -SURFACE_GODOT_MATRIX_ELEMENT(value, 1, 0),
        SURFACE_GODOT_MATRIX_ELEMENT(value, 0, 0))) * inverseDeterminant;
#else
    return inverse(value);
#endif
}
hmat2 SurfaceGodotMatrixCompMult(hmat2 a, hmat2 b)
{
#if BGFX_SHADER_DIALECT_HLSL
    return a * b;
#else
    return matrixCompMult(a, b);
#endif
}
hmat2 SurfaceGodotOuterProduct(hvec2 columnValue, hvec2 rowValue)
{
    return SURFACE_GODOT_MATRIX_INPUT(hmat2_init(columnValue * rowValue[0], columnValue * rowValue[1]));
}
hvec2 SurfaceGodotWriteColumn(inout hmat2 matrixValue, int column, ivec2 rows, hmat2 value, int operation)
{
    hvec2 oldValue = hvec2_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]));
    return SurfaceGodotWriteColumn(matrixValue, column, rows, mul(oldValue, value), 0);
}
hfloat SurfaceGodotMinor(hmat3 value, int excludedRow, int excludedColumn)
{
    ivec2 rows = ivec2(excludedRow > 0 ? 0 : 1, excludedRow > 1 ? 1 : 2);
    ivec2 columns = ivec2(excludedColumn > 0 ? 0 : 1, excludedColumn > 1 ? 1 : 2);
    return determinant(hmat2_init(
        SURFACE_GODOT_MATRIX_ELEMENT(value, columns[0], rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(value, columns[0], rows[1]),
        SURFACE_GODOT_MATRIX_ELEMENT(value, columns[1], rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(value, columns[1], rows[1])));
}
hmat3 SurfaceGodotInverse(hmat3 value)
{
#if BGFX_SHADER_DIALECT_HLSL
    hfloat inverseDeterminant = 1.0 / determinant(value);
    return SURFACE_GODOT_MATRIX_INPUT(hmat3_init(
        hvec3_init(SurfaceGodotMinor(value, 0, 0), -SurfaceGodotMinor(value, 0, 1), SurfaceGodotMinor(value, 0, 2)),
        hvec3_init(-SurfaceGodotMinor(value, 1, 0), SurfaceGodotMinor(value, 1, 1), -SurfaceGodotMinor(value, 1, 2)),
        hvec3_init(SurfaceGodotMinor(value, 2, 0), -SurfaceGodotMinor(value, 2, 1), SurfaceGodotMinor(value, 2, 2)))) * inverseDeterminant;
#else
    return inverse(value);
#endif
}
hmat3 SurfaceGodotMatrixCompMult(hmat3 a, hmat3 b)
{
#if BGFX_SHADER_DIALECT_HLSL
    return a * b;
#else
    return matrixCompMult(a, b);
#endif
}
hmat3 SurfaceGodotOuterProduct(hvec3 columnValue, hvec3 rowValue)
{
    return SURFACE_GODOT_MATRIX_INPUT(hmat3_init(columnValue * rowValue[0], columnValue * rowValue[1], columnValue * rowValue[2]));
}
hvec2 SurfaceGodotWriteColumn(inout hmat3 matrixValue, int column, ivec2 rows, hmat2 value, int operation)
{
    hvec2 oldValue = hvec2_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]));
    return SurfaceGodotWriteColumn(matrixValue, column, rows, mul(oldValue, value), 0);
}
hvec3 SurfaceGodotWriteColumn(inout hmat3 matrixValue, int column, ivec3 rows, hmat3 value, int operation)
{
    hvec3 oldValue = hvec3_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[2]));
    return SurfaceGodotWriteColumn(matrixValue, column, rows, mul(oldValue, value), 0);
}
hfloat SurfaceGodotMinor(hmat4 value, int excludedRow, int excludedColumn)
{
    ivec3 rows = ivec3(excludedRow > 0 ? 0 : 1, excludedRow > 1 ? 1 : 2, excludedRow > 2 ? 2 : 3);
    ivec3 columns = ivec3(excludedColumn > 0 ? 0 : 1, excludedColumn > 1 ? 1 : 2, excludedColumn > 2 ? 2 : 3);
    return determinant(hmat3_init(
        SURFACE_GODOT_MATRIX_ELEMENT(value, columns[0], rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(value, columns[0], rows[1]), SURFACE_GODOT_MATRIX_ELEMENT(value, columns[0], rows[2]),
        SURFACE_GODOT_MATRIX_ELEMENT(value, columns[1], rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(value, columns[1], rows[1]), SURFACE_GODOT_MATRIX_ELEMENT(value, columns[1], rows[2]),
        SURFACE_GODOT_MATRIX_ELEMENT(value, columns[2], rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(value, columns[2], rows[1]), SURFACE_GODOT_MATRIX_ELEMENT(value, columns[2], rows[2])));
}
hmat4 SurfaceGodotInverse(hmat4 value)
{
#if BGFX_SHADER_DIALECT_HLSL
    hfloat inverseDeterminant = 1.0 / determinant(value);
    return SURFACE_GODOT_MATRIX_INPUT(hmat4_init(
        hvec4_init(SurfaceGodotMinor(value, 0, 0), -SurfaceGodotMinor(value, 0, 1), SurfaceGodotMinor(value, 0, 2), -SurfaceGodotMinor(value, 0, 3)),
        hvec4_init(-SurfaceGodotMinor(value, 1, 0), SurfaceGodotMinor(value, 1, 1), -SurfaceGodotMinor(value, 1, 2), SurfaceGodotMinor(value, 1, 3)),
        hvec4_init(SurfaceGodotMinor(value, 2, 0), -SurfaceGodotMinor(value, 2, 1), SurfaceGodotMinor(value, 2, 2), -SurfaceGodotMinor(value, 2, 3)),
        hvec4_init(-SurfaceGodotMinor(value, 3, 0), SurfaceGodotMinor(value, 3, 1), -SurfaceGodotMinor(value, 3, 2), SurfaceGodotMinor(value, 3, 3)))) * inverseDeterminant;
#else
    return inverse(value);
#endif
}
hmat4 SurfaceGodotMatrixCompMult(hmat4 a, hmat4 b)
{
#if BGFX_SHADER_DIALECT_HLSL
    return a * b;
#else
    return matrixCompMult(a, b);
#endif
}
hmat4 SurfaceGodotOuterProduct(hvec4 columnValue, hvec4 rowValue)
{
    return SURFACE_GODOT_MATRIX_INPUT(hmat4_init(columnValue * rowValue[0], columnValue * rowValue[1], columnValue * rowValue[2], columnValue * rowValue[3]));
}
hvec2 SurfaceGodotWriteColumn(inout hmat4 matrixValue, int column, ivec2 rows, hmat2 value, int operation)
{
    hvec2 oldValue = hvec2_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]));
    return SurfaceGodotWriteColumn(matrixValue, column, rows, mul(oldValue, value), 0);
}
hvec3 SurfaceGodotWriteColumn(inout hmat4 matrixValue, int column, ivec3 rows, hmat3 value, int operation)
{
    hvec3 oldValue = hvec3_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[2]));
    return SurfaceGodotWriteColumn(matrixValue, column, rows, mul(oldValue, value), 0);
}
hvec4 SurfaceGodotWriteColumn(inout hmat4 matrixValue, int column, ivec4 rows, hmat4 value, int operation)
{
    hvec4 oldValue = hvec4_init(SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[0]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[1]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[2]), SURFACE_GODOT_MATRIX_ELEMENT(matrixValue, column, rows[3]));
    return SurfaceGodotWriteColumn(matrixValue, column, rows, mul(oldValue, value), 0);
}

#endif
