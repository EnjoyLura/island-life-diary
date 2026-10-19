#ifndef URHOX_ATTACHMENT_FETCH_SH
#define URHOX_ATTACHMENT_FETCH_SH

// Both the logical subpass input and its physical color slot are compile-time constants.
// The declaration macro defines a reader function; do not append a semicolon.
// Use shader variations for different attachment layouts; there is no sampler fallback.
#if BGFX_SHADER_LANGUAGE_METAL
#if BGFX_SHADER_COMPILER_HLSLCC
// DXBC uses an unbound load placeholder to avoid colliding with ordinary texture slots.
// HLSLcc resolves its reserved name to a compile-time Metal color input.
#define URHOX_DECLARE_INPUT_ATTACHMENT(index, slot) \
    Texture2D<float4> UrhoXInputAttachment##index##_Color##slot##Texture; \
    hvec4 UrhoXReadInputAttachment##index() { return UrhoXInputAttachment##index##_Color##slot##Texture.Load(int3(0, 0, 0)); }
#else
#define URHOX_DECLARE_INPUT_ATTACHMENT(index, slot) \
    SAMPLER2D_PRECISION(UrhoXInputAttachment##index##_Color##slot, slot, highp); \
    hvec4 UrhoXReadInputAttachment##index() { return texture2DLod(UrhoXInputAttachment##index##_Color##slot, vec2_splat(0.0), 0.0); }
#endif
#elif BGFX_SHADER_LANGUAGE_GLSL && BGFX_SHADER_DIALECT_GLSL >= 300
// Shaderc lowers this intermediate declaration to native framebuffer fetch before serialization.
#define URHOX_DECLARE_INPUT_ATTACHMENT(index, slot) \
    uniform highp vec4 UrhoXInputAttachment##index##_Color##slot; \
    hvec4 UrhoXReadInputAttachment##index() { return UrhoXInputAttachment##index##_Color##slot; }
#else
#error Input attachments require a supported shader backend
#endif
#define DECLARE_INPUT_ATTACHMENT(index, slot) URHOX_DECLARE_INPUT_ATTACHMENT(index, slot)
#define READ_INPUT_ATTACHMENT(index) UrhoXReadInputAttachment##index()

#endif
