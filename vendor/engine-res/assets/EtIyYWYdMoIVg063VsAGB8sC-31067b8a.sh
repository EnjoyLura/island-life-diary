/*
 * Copyright 2011-2020 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#ifndef BGFX_COMPUTE_H_HEADER_GUARD
#define BGFX_COMPUTE_H_HEADER_GUARD

#include "bgfx_shader.sh"

#ifndef __cplusplus

#if BGFX_SHADER_DIALECT_GLSL
#	define FRAMEBUFFER_IMAGE2D_RW_0(_name, _format) IMAGE2D_RW(_name, _format, 4)
#	define FRAMEBUFFER_IMAGE2D_RW_1(_name, _format) IMAGE2D_RW(_name, _format, 5)
#	define FRAMEBUFFER_IMAGE2D_RW_2(_name, _format) IMAGE2D_RW(_name, _format, 6)
#	define FRAMEBUFFER_IMAGE2D_RW_3(_name, _format) IMAGE2D_RW(_name, _format, 7)
#else
#	define FRAMEBUFFER_IMAGE2D_RW_0(_name, _format) IMAGE2D_RW(_name, _format, 16)
#	define FRAMEBUFFER_IMAGE2D_RW_1(_name, _format) IMAGE2D_RW(_name, _format, 17)
#	define FRAMEBUFFER_IMAGE2D_RW_2(_name, _format) IMAGE2D_RW(_name, _format, 18)
#	define FRAMEBUFFER_IMAGE2D_RW_3(_name, _format) IMAGE2D_RW(_name, _format, 19)
#endif // BGFX_SHADER_DIALECT_GLSL

#define FRAMEBUFFER_IMAGE2D_RW(_name, _format, _reg) FRAMEBUFFER_IMAGE2D_RW_ ## _reg(_name, _format)

#if BGFX_SHADER_DIALECT_GLSL

	#define SHARED shared

	#define __IMAGE_XX(_name, _format, _reg, _image, _access) \
		layout(_format, binding=_reg) _access uniform highp _image _name

	#define readwrite
	#define IMAGE2D_RO( _name, _format, _reg) __IMAGE_XX(_name, _format, _reg, image2D,  readonly)
	#define UIMAGE2D_RO(_name, _format, _reg) __IMAGE_XX(_name, _format, _reg, uimage2D, readonly)
	#define IMAGE2D_WR( _name, _format, _reg) __IMAGE_XX(_name, _format, _reg, image2D,  writeonly)
	#define UIMAGE2D_WR(_name, _format, _reg) __IMAGE_XX(_name, _format, _reg, uimage2D, writeonly)
	#define IMAGE2D_RW( _name, _format, _reg) __IMAGE_XX(_name, _format, _reg, image2D,  readwrite)
	#define UIMAGE2D_RW(_name, _format, _reg) __IMAGE_XX(_name, _format, _reg, uimage2D, readwrite)

	#define IMAGE2D_ARRAY_RO( _name, _format, _reg) __IMAGE_XX(_name, _format, _reg, image2DArray,  readonly)
	#define UIMAGE2D_ARRAY_RO(_name, _format, _reg) __IMAGE_XX(_name, _format, _reg, uimage2DArray, readonly)
	#define IMAGE2D_ARRAY_WR( _name, _format, _reg) __IMAGE_XX(_name, _format, _reg, image2DArray,  writeonly)
	#define UIMAGE2D_ARRAY_WR(_name, _format, _reg) __IMAGE_XX(_name, _format, _reg, uimage2DArray, writeonly)
	#define IMAGE2D_ARRAY_RW( _name, _format, _reg) __IMAGE_XX(_name, _format, _reg, image2DArray,  readwrite)
	#define UIMAGE2D_ARRAY_RW(_name, _format, _reg) __IMAGE_XX(_name, _format, _reg, uimage2DArray, readwrite)

	#define IMAGE3D_RO( _name, _format, _reg) __IMAGE_XX(_name, _format, _reg, image3D,  readonly)
	#define UIMAGE3D_RO(_name, _format, _reg) __IMAGE_XX(_name, _format, _reg, uimage3D, readonly)
	#define IMAGE3D_WR( _name, _format, _reg) __IMAGE_XX(_name, _format, _reg, image3D,  writeonly)
	#define UIMAGE3D_WR(_name, _format, _reg) __IMAGE_XX(_name, _format, _reg, uimage3D, writeonly)
	#define IMAGE3D_RW( _name, _format, _reg) __IMAGE_XX(_name, _format, _reg, image3D,  readwrite)
	#define UIMAGE3D_RW(_name, _format, _reg) __IMAGE_XX(_name, _format, _reg, uimage3D, readwrite)

	#define __BUFFER_XX(_name, _type, _reg, _access)                \
		layout(std430, binding=_reg) _access buffer _name ## Buffer \
		{                                                           \
			_type _name[];                                          \
		}

	#define BUFFER_RO(_name, _type, _reg) __BUFFER_XX(_name, _type, _reg, readonly)
	#define BUFFER_RW(_name, _type, _reg) __BUFFER_XX(_name, _type, _reg, readwrite)
	#define BUFFER_WR(_name, _type, _reg) __BUFFER_XX(_name, _type, _reg, writeonly)

	// HLSL 用 Buffer<T> / RWBuffer<T> 表示 typed buffer、StructuredBuffer<T> 表示 structured
	// buffer，两者是不同的资源视图；GLSL 侧都落到 std430 SSBO，因此 _TYPED 与非 _TYPED 同构。
	#define BUFFER_RO_TYPED(_name, _type, _reg) BUFFER_RO(_name, _type, _reg)
	#define BUFFER_WR_TYPED(_name, _type, _reg) BUFFER_WR(_name, _type, _reg)

	#define UNIFORM_BUFFER_OBJECT(_name, _type, _reg, _size) \
		layout(std140, binding=_reg) uniform _name ## Buffer        \
		{                                              \
			_type _name[_size];                        \
		}

	#define NUM_THREADS(_x, _y, _z) layout (local_size_x = _x, local_size_y = _y, local_size_z = _z) in;

	#define atomicFetchAndAdd(_mem, _data, _original)                    _original = atomicAdd(_mem, _data)
	#define atomicFetchAndAnd(_mem, _data, _original)                    _original = atomicAnd(_mem, _data)
	#define atomicFetchAndMax(_mem, _data, _original)                    _original = atomicMax(_mem, _data)
	#define atomicFetchAndMin(_mem, _data, _original)                    _original = atomicMin(_mem, _data)
	#define atomicFetchAndOr(_mem, _data, _original)                     _original = atomicOr(_mem, _data)
	#define atomicFetchAndXor(_mem, _data, _original)                    _original = atomicXor(_mem, _data)
	#define atomicFetchAndExchange(_mem, _data, _original)               _original = atomicExchange(_mem, _data)
	#define atomicFetchCompareExchange(_mem, _compare, _data, _original) _original = atomicCompSwap(_mem,_compare, _data)

#else // BGFX_SHADER_DIALECT_GLSL

	#define SHARED groupshared

	#define r32ui    uint
	#define rg32ui   uint2
	#define rgba32ui uint4
	#define r32f     hfloat
	#define r16f     hfloat
	#define rg16f    float2
	#define rgba16f  float4
	#	define r11f_g11_b10f float3
	#if BGFX_SHADER_DIALECT_HLSL
	// #	define r11f_g11_b10f unorm float3
	#	define rgba8 unorm float4
	#	define rg8   unorm float2
	#	define r8    unorm hfloat
	#else
	#	define rgba8       float4
	#	define rg8         float2
	#	define r8          hfloat
	#endif // BGFX_SHADER_DIALECT_HLSL
	#define rgba32f  float4

	// Preserve storage precision through the existing HLSLcc resource-name convention.
	#define __IMAGE_RO_NAME_r32ui(_name) _name ## Texture_highp
	#define __IMAGE_RO_NAME_rg32ui(_name) _name ## Texture_highp
	#define __IMAGE_RO_NAME_rgba32ui(_name) _name ## Texture_highp
	#define __IMAGE_RO_NAME_r32f(_name) _name ## Texture_highp
	#define __IMAGE_RO_NAME_r16f(_name) _name ## Texture_mediump
	#define __IMAGE_RO_NAME_rg16f(_name) _name ## Texture_mediump
	#define __IMAGE_RO_NAME_rgba16f(_name) _name ## Texture_mediump
	#define __IMAGE_RO_NAME_rgba32f(_name) _name ## Texture_highp
	#define __IMAGE_RO_NAME_r11f_g11_b10f(_name) _name ## Texture_lowp
	#define __IMAGE_RO_NAME_rgba8(_name) _name ## Texture_highp
	#define __IMAGE_RO_NAME_rg8(_name) _name ## Texture_highp
	#define __IMAGE_RO_NAME_r8(_name) _name ## Texture_highp

	#if BGFX_SHADER_LANGUAGE_GLSL
		// Keep image bindings in the UAV namespace; HLSLcc infers readonly from usage.
		#define IMAGE2D_RO(_name, _format, _reg) \
			RWTexture2D<_format> __IMAGE_RO_NAME_ ## _format(_name) : REGISTER(u, _reg); \
			static BgfxRWImage2D_ ## _format _name = { __IMAGE_RO_NAME_ ## _format(_name) }
	#elif BGFX_SHADER_LANGUAGE_METAL && !BGFX_SHADER_COMPILER_HLSLCC
		// SPIRV-Cross Metal consumes the precision suffix while retaining readonly texture bindings.
		#define IMAGE2D_RO(_name, _format, _reg) \
			Texture2D<_format> __IMAGE_RO_NAME_ ## _format(_name) : REGISTER(t, _reg); \
			static BgfxROImage2D_ ## _format _name = { __IMAGE_RO_NAME_ ## _format(_name) }
	#else
	#define IMAGE2D_RO( _name, _format, _reg)                         \
		Texture2D<_format> _name ## Texture : REGISTER(t, _reg);      \
		static BgfxROImage2D_ ## _format _name = { _name ## Texture }
	#endif

	#define UIMAGE2D_RO(_name, _format, _reg) IMAGE2D_RO(_name, _format, _reg)

	#if BGFX_SHADER_LANGUAGE_WGSL
		#define IMAGE2D_RW( _name, _format, _reg) \
			RWTexture2D<_format> _name ## WgslReadWrite_ ## _format ## Texture : REGISTER(u, _reg); \
			static BgfxRWImage2D_ ## _format _name = { _name ## WgslReadWrite_ ## _format ## Texture }
	#else
		#define IMAGE2D_RW( _name, _format, _reg)                       \
			RWTexture2D<_format> _name ## Texture : REGISTER(u, _reg);  \
			static BgfxRWImage2D_ ## _format _name = { _name ## Texture }
	#endif

	#define IMAGE2D_RW_HLSLCC(_name, _format, _precision, _reg) \
		RWTexture2D<_format> _name ## Texture ## _ ## _precision : REGISTER(u, _reg);  \
		static BgfxRWImage2D_ ## _format _name = { _name ## Texture ## _ ## _precision }

	// HLSL RWTexture 不携带原始 storage format，也没有 write-only 类型；Tint 适配层消费名称标记。
	#if BGFX_SHADER_LANGUAGE_WGSL
		#define IMAGE2D_WR( _name, _format, _reg) \
			RWTexture2D<_format> _name ## WgslWriteOnly_ ## _format ## Texture : REGISTER(u, _reg); \
			static BgfxRWImage2D_ ## _format _name = { _name ## WgslWriteOnly_ ## _format ## Texture }
	#else
		#define IMAGE2D_WR( _name, _format, _reg) IMAGE2D_RW(_name, _format, _reg)
	#endif
	#define UIMAGE2D_WR IMAGE2D_WR
	#define UIMAGE2D_RW IMAGE2D_RW

	#if BGFX_SHADER_LANGUAGE_GLSL
		// Keep image bindings in the UAV namespace; HLSLcc infers readonly from usage.
		#define IMAGE2D_ARRAY_RO(_name, _format, _reg) \
			RWTexture2DArray<_format> __IMAGE_RO_NAME_ ## _format(_name) : REGISTER(u, _reg); \
			static BgfxRWImage2DArray_ ## _format _name = { __IMAGE_RO_NAME_ ## _format(_name) }
	#elif BGFX_SHADER_LANGUAGE_METAL && !BGFX_SHADER_COMPILER_HLSLCC
		// SPIRV-Cross Metal consumes the precision suffix while retaining readonly texture bindings.
		#define IMAGE2D_ARRAY_RO(_name, _format, _reg) \
			Texture2DArray<_format> __IMAGE_RO_NAME_ ## _format(_name) : REGISTER(t, _reg); \
			static BgfxROImage2DArray_ ## _format _name = { __IMAGE_RO_NAME_ ## _format(_name) }
	#else
	#define IMAGE2D_ARRAY_RO(_name, _format, _reg)                       \
		Texture2DArray<_format> _name ## Texture : REGISTER(t, _reg);    \
		static BgfxROImage2DArray_ ## _format _name = { _name ## Texture }
	#endif

	#define UIMAGE2D_ARRAY_RO(_name, _format, _reg) IMAGE2D_ARRAY_RO(_name, _format, _reg)

	#if BGFX_SHADER_LANGUAGE_WGSL
		#define IMAGE2D_ARRAY_RW(_name, _format, _reg) \
			RWTexture2DArray<_format> _name ## WgslReadWrite_ ## _format ## Texture : REGISTER(u, _reg); \
			static BgfxRWImage2DArray_ ## _format _name = { _name ## WgslReadWrite_ ## _format ## Texture }
	#else
		#define IMAGE2D_ARRAY_RW(_name, _format, _reg)                         \
			RWTexture2DArray<_format> _name ## Texture : REGISTER(u, _reg);    \
			static BgfxRWImage2DArray_ ## _format _name = { _name ## Texture }
	#endif

	#define UIMAGE2D_ARRAY_RW IMAGE2D_ARRAY_RW
	#if BGFX_SHADER_LANGUAGE_WGSL
		#define IMAGE2D_ARRAY_WR( _name, _format, _reg) \
			RWTexture2DArray<_format> _name ## WgslWriteOnly_ ## _format ## Texture : REGISTER(u, _reg); \
			static BgfxRWImage2DArray_ ## _format _name = { _name ## WgslWriteOnly_ ## _format ## Texture }
	#else
		#define IMAGE2D_ARRAY_WR( _name, _format, _reg) IMAGE2D_ARRAY_RW(_name, _format, _reg)
	#endif
	#define UIMAGE2D_ARRAY_WR IMAGE2D_ARRAY_WR

	#if BGFX_SHADER_LANGUAGE_GLSL
		// Keep image bindings in the UAV namespace; HLSLcc infers readonly from usage.
		#define IMAGE3D_RO(_name, _format, _reg) \
			RWTexture3D<_format> __IMAGE_RO_NAME_ ## _format(_name) : REGISTER(u, _reg); \
			static BgfxRWImage3D_ ## _format _name = { __IMAGE_RO_NAME_ ## _format(_name) }
	#elif BGFX_SHADER_LANGUAGE_METAL && !BGFX_SHADER_COMPILER_HLSLCC
		// SPIRV-Cross Metal consumes the precision suffix while retaining readonly texture bindings.
		#define IMAGE3D_RO(_name, _format, _reg) \
			Texture3D<_format> __IMAGE_RO_NAME_ ## _format(_name) : REGISTER(t, _reg); \
			static BgfxROImage3D_ ## _format _name = { __IMAGE_RO_NAME_ ## _format(_name) }
	#else
	#define IMAGE3D_RO( _name, _format, _reg)                       \
		Texture3D<_format> _name ## Texture : REGISTER(t, _reg);    \
		static BgfxROImage3D_ ## _format _name = { _name ## Texture }
	#endif

	#define UIMAGE3D_RO(_name, _format, _reg) IMAGE3D_RO(_name, _format, _reg)

	#if BGFX_SHADER_LANGUAGE_WGSL
		#define IMAGE3D_RW( _name, _format, _reg) \
			RWTexture3D<_format> _name ## WgslReadWrite_ ## _format ## Texture : REGISTER(u, _reg); \
			static BgfxRWImage3D_ ## _format _name = { _name ## WgslReadWrite_ ## _format ## Texture }
	#else
		#define IMAGE3D_RW( _name, _format, _reg)                       \
			RWTexture3D<_format> _name ## Texture : REGISTER(u, _reg);  \
			static BgfxRWImage3D_ ## _format _name = { _name ## Texture }
	#endif

	#define IMAGE3D_RW_HLSLCC(_name, _format, _precision, _reg) \
		RWTexture3D<_format> _name ## Texture ## _ ## _precision : REGISTER(u, _reg);  \
		static BgfxRWImage3D_ ## _format _name = { _name ## Texture ## _ ## _precision }

	#define UIMAGE3D_RW IMAGE3D_RW
	#if BGFX_SHADER_LANGUAGE_WGSL
		#define IMAGE3D_WR( _name, _format, _reg) \
			RWTexture3D<_format> _name ## WgslWriteOnly_ ## _format ## Texture : REGISTER(u, _reg); \
			static BgfxRWImage3D_ ## _format _name = { _name ## WgslWriteOnly_ ## _format ## Texture }
	#else
		#define IMAGE3D_WR( _name, _format, _reg) IMAGE3D_RW(_name, _format, _reg)
	#endif
	#define UIMAGE3D_WR IMAGE3D_WR

	#if BGFX_SHADER_LANGUAGE_WGSL
		// WGSL 没有 HLSL Buffer/RWBuffer 对应的 texel buffer；glslang 会将其生成 SPIR-V DimBuffer，导致 Tint reader ICE。
		// WebGPU 统一映射为 storage buffer，StructuredBuffer<float> 仍保留原有的按元素索引语义。
		#define BUFFER_RO(_name, _struct, _reg) StructuredBuffer<_struct> _name : REGISTER(t, _reg)
		#define BUFFER_RO_TYPED BUFFER_RO
		#define BUFFER_RW(_name, _struct, _reg) RWStructuredBuffer<_struct> _name : REGISTER(u, _reg)
		#define BUFFER_WR BUFFER_RW
		#define BUFFER_WR_TYPED BUFFER_RW
	#elif BGFX_SHADER_DIALECT_HLSL
		#define BUFFER_RO(_name, _struct, _reg) StructuredBuffer<_struct>   _name : REGISTER(t, _reg)
		#define BUFFER_RO_TYPED(_name, _struct, _reg) Buffer<_struct>   _name : REGISTER(t, _reg)
		#define BUFFER_RW(_name, _struct, _reg) RWStructuredBuffer <_struct> _name : REGISTER(u, _reg)
		#define BUFFER_WR(_name, _struct, _reg) BUFFER_RW(_name, _struct, _reg)
		#define BUFFER_WR_TYPED(_name, _struct, _reg) RWBuffer<_struct> _name : REGISTER(u, _reg)
	#else
		#define BUFFER_RO(_name, _struct, _reg) Buffer<_struct>   _name : REGISTER(t, _reg)
		#define BUFFER_RO_TYPED(_name, _struct, _reg) Buffer<_struct>   _name : REGISTER(t, _reg)
		#define BUFFER_RW(_name, _struct, _reg) RWBuffer<_struct> _name : REGISTER(u, _reg)
		#define BUFFER_WR(_name, _struct, _reg) BUFFER_RW(_name, _struct, _reg)
		#define BUFFER_WR_TYPED(_name, _struct, _reg) BUFFER_RW(_name, _struct, _reg)
	#endif
//DX放到global cbuffer中，这个路径配合引擎的forceUniform可以跑通,但还是不走这个路径好一些
#if 0
	#define UNIFORM_BUFFER_OBJECT(_name, _type, _reg, _size) \
		_type _name[_size];  \

#else
	// D3DCompile does not retain the cbuffer slot for register(b[N]); expand a numeric bN token.
	#define UBO_REGISTER_IMPL(_reg) register(b ## _reg)
	#define UBO_REGISTER(_reg) UBO_REGISTER_IMPL(_reg)
	#define UNIFORM_BUFFER_OBJECT(_name, _type, _reg, _size) cbuffer _name##Buffer: UBO_REGISTER(_reg) \
		{_type _name[_size]; } \

#endif

	#define NUM_THREADS(_x, _y, _z) [numthreads(_x, _y, _z)]

	#define __IMAGE_IMPL_S(_format, _storeComponents, _type, _loadComponents) \
		\
		struct BgfxROImage2D_ ## _format                                      \
		{                                                                     \
			Texture2D<_format> m_texture;                                     \
		};                                                                    \
		\
		struct BgfxRWImage2D_ ## _format                                      \
		{                                                                     \
			RWTexture2D<_format> m_texture;                                   \
		};                                                                    \
		\
		struct BgfxROImage2DArray_ ## _format                                 \
		{                                                                     \
			Texture2DArray<_format> m_texture;                                \
		};                                                                    \
		\
		struct BgfxRWImage2DArray_ ## _format                                 \
		{                                                                     \
			RWTexture2DArray<_format> m_texture;                              \
		};                                                                    \
		\
		struct BgfxROImage3D_ ## _format                                      \
		{                                                                     \
			Texture3D<_format> m_texture;                                     \
		};                                                                    \
		\
		struct BgfxRWImage3D_ ## _format                                      \
		{                                                                     \
			RWTexture3D<_format> m_texture;                                   \
		};                                                                    \

	#define __IMAGE_IMPL_F(_format, _storeComponents, _type, _loadComponents)            \
		_type imageLoad(BgfxROImage2D_ ## _format _image, ivec2 _uv)                     \
		{                                                                                \
			return _image.m_texture[_uv]._loadComponents;                                \
		}                                                                                \
		\
		ivec2 imageSize(BgfxROImage2D_ ## _format _image)                                \
		{                                                                                \
			uvec2 result;                                                                \
			_image.m_texture.GetDimensions(result.x, result.y);                          \
			return ivec2(result);                                                        \
		}                                                                                \
		\
		_type imageLoad(BgfxRWImage2D_ ## _format _image, ivec2 _uv)                     \
		{                                                                                \
			return _image.m_texture[_uv]._loadComponents;                                \
		}                                                                                \
		\
		ivec2 imageSize(BgfxRWImage2D_ ## _format _image)                                \
		{                                                                                \
			uvec2 result;                                                                \
			_image.m_texture.GetDimensions(result.x, result.y);                          \
			return ivec2(result);                                                        \
		}                                                                                \
		\
		void imageStore(BgfxRWImage2D_ ## _format _image, ivec2 _uv,  _type _value)      \
		{                                                                                \
			_image.m_texture[_uv] = _value._storeComponents;                             \
		}                                                                                \
		\
		_type imageLoad(BgfxROImage2DArray_ ## _format _image, ivec3 _uvw)               \
		{                                                                                \
			return _image.m_texture[_uvw]._loadComponents;                               \
		}                                                                                \
		\
		ivec3 imageSize(BgfxROImage2DArray_ ## _format _image)                           \
		{                                                                                \
			uvec3 result;                                                                \
			_image.m_texture.GetDimensions(result.x, result.y, result.z);                \
			return ivec3(result);                                                        \
		}                                                                                \
		\
		_type imageLoad(BgfxRWImage2DArray_ ## _format _image, ivec3 _uvw)               \
		{                                                                                \
			return _image.m_texture[_uvw]._loadComponents;                               \
		}                                                                                \
		\
		void imageStore(BgfxRWImage2DArray_ ## _format _image, ivec3 _uvw, _type _value) \
		{                                                                                \
			_image.m_texture[_uvw] = _value._storeComponents;                            \
		}                                                                                \
		\
		ivec3 imageSize(BgfxRWImage2DArray_ ## _format _image)                           \
		{                                                                                \
			uvec3 result;                                                                \
			_image.m_texture.GetDimensions(result.x, result.y, result.z);                \
			return ivec3(result);                                                        \
		}                                                                                \
		\
		_type imageLoad(BgfxROImage3D_ ## _format _image, ivec3 _uvw)                    \
		{                                                                                \
			return _image.m_texture[_uvw]._loadComponents;                               \
		}                                                                                \
		\
		ivec3 imageSize(BgfxROImage3D_ ## _format _image)                                \
		{                                                                                \
			uvec3 result;                                                                \
			_image.m_texture.GetDimensions(result.x, result.y, result.z);                \
			return ivec3(result);                                                        \
		}                                                                                \
		\
		_type imageLoad(BgfxRWImage3D_ ## _format _image, ivec3 _uvw)                    \
		{                                                                                \
			return _image.m_texture[_uvw]._loadComponents;                               \
		}                                                                                \
		\
		ivec3 imageSize(BgfxRWImage3D_ ## _format _image)                                \
		{                                                                                \
			uvec3 result;                                                                \
			_image.m_texture.GetDimensions(result.x, result.y, result.z);                \
			return ivec3(result);                                                        \
		}                                                                                \
		\
		void imageStore(BgfxRWImage3D_ ## _format _image, ivec3 _uvw, _type _value)      \
		{                                                                                \
			_image.m_texture[_uvw] = _value._storeComponents;                            \
		}

	#define __IMAGE_IMPL_A(_format, _storeComponents, _type, _loadComponents) \
		__IMAGE_IMPL_S(_format, _storeComponents, _type, _loadComponents)     \
		__IMAGE_IMPL_F(_format, _storeComponents, _type, _loadComponents)

	#define __IMAGE_IMPL_ATOMIC(_format, _storeComponents, _type, _loadComponents)            \
		\
		void imageAtomicAdd(BgfxRWImage2D_ ## _format _image, ivec2 _uv,  _type _value)  \
		{				                                                                 \
			InterlockedAdd(_image.m_texture[_uv], _value._storeComponents);	             \
		}                                                                                \


	__IMAGE_IMPL_A(rgba8,       xyzw, vec4,  xyzw)
	__IMAGE_IMPL_A(rg8,         xy,   vec4,  xyyy)
	__IMAGE_IMPL_A(r8,          x,    vec4,  xxxx)
	__IMAGE_IMPL_A(rg16f,       xy,   vec4,  xyyy)
	#if BGFX_SHADER_DIALECT_HLSL && !BGFX_SHADER_LANGUAGE_WGSL && !BGFX_SHADER_LANGUAGE_METAL
	__IMAGE_IMPL_S(rgba16f,     xyzw, vec4,  xyzw)
	__IMAGE_IMPL_S(r16f,        x,    vec4,  xxxx)
	#else
	// Metal / WGSL 的 glslang 前端不接受 D3DCompile 的同构 struct 隐式转换，须提供格式专用重载。
	// 只用 S 会缺少 imageSize 等重载；使用 A 会让格式宏提前展开，产生'imageSize': function already has a body等重复 wrapper/函数定义。
	// 直接写 S+F 保留格式名，并提供完整 helper。
	__IMAGE_IMPL_S(rgba16f,     xyzw, vec4,  xyzw)
	__IMAGE_IMPL_F(rgba16f,     xyzw, vec4,  xyzw)
	__IMAGE_IMPL_S(r16f,        x,    vec4,  xxxx)
	__IMAGE_IMPL_F(r16f,        x,    vec4,  xxxx)
	#endif // BGFX_SHADER_DIALECT_HLSL && !BGFX_SHADER_LANGUAGE_WGSL && !BGFX_SHADER_LANGUAGE_METAL
	__IMAGE_IMPL_A(r32f,        x,    vec4,  xxxx)
	__IMAGE_IMPL_A(rgba32f,     xyzw, vec4,  xyzw)
	__IMAGE_IMPL_A(r11f_g11_b10f,    xyzw, vec4, xyzz)
	__IMAGE_IMPL_A(r32ui,       x,    uvec4, xxxx)
	__IMAGE_IMPL_A(rg32ui,      xy,   uvec4, xyyy)
	__IMAGE_IMPL_A(rgba32ui,    xyzw, uvec4, xyzw)

	__IMAGE_IMPL_ATOMIC(r32ui,       x,    uvec4, xxxx)

	#define atomicAdd(_mem, _data)                                       InterlockedAdd(_mem, _data)
	#define atomicAnd(_mem, _data)                                       InterlockedAnd(_mem, _data)
	#define atomicMax(_mem, _data)                                       InterlockedMax(_mem, _data)
	#define atomicMin(_mem, _data)                                       InterlockedMin(_mem, _data)
	#define atomicOr(_mem, _data)                                        InterlockedOr(_mem, _data)
	#define atomicXor(_mem, _data)                                       InterlockedXor(_mem, _data)
	#define atomicFetchAndAdd(_mem, _data, _original)                    InterlockedAdd(_mem, _data, _original)
	#define atomicFetchAndAnd(_mem, _data, _original)                    InterlockedAnd(_mem, _data, _original)
	#define atomicFetchAndMax(_mem, _data, _original)                    InterlockedMax(_mem, _data, _original)
	#define atomicFetchAndMin(_mem, _data, _original)                    InterlockedMin(_mem, _data, _original)
	#define atomicFetchAndOr(_mem, _data, _original)                     InterlockedOr(_mem, _data, _original)
	#define atomicFetchAndXor(_mem, _data, _original)                    InterlockedXor(_mem, _data, _original)
	#define atomicFetchAndExchange(_mem, _data, _original)               InterlockedExchange(_mem, _data, _original)
	#define atomicFetchCompareExchange(_mem, _compare, _data, _original) InterlockedCompareExchange(_mem,_compare, _data, _original)

	// InterlockedCompareStore

	#define barrier()                    GroupMemoryBarrierWithGroupSync()
	#define memoryBarrier()              GroupMemoryBarrierWithGroupSync()
	#define memoryBarrierAtomicCounter() GroupMemoryBarrierWithGroupSync()
	#define memoryBarrierBuffer()        AllMemoryBarrierWithGroupSync()
	#define memoryBarrierImage()         GroupMemoryBarrierWithGroupSync()
	#define memoryBarrierShared()        GroupMemoryBarrierWithGroupSync()
	#define groupMemoryBarrier()         GroupMemoryBarrierWithGroupSync()

#endif // BGFX_SHADER_DIALECT_GLSL

#define dispatchIndirect( \
	  _buffer             \
	, _offset             \
	, _numX               \
	, _numY               \
	, _numZ               \
	)                     \
	_buffer[(_offset)*2+0] = uvec4(_numX, _numY, _numZ, 0u)

#define drawIndirect( \
	  _buffer         \
	, _offset         \
	, _numVertices    \
	, _numInstances   \
	, _startVertex    \
	, _startInstance  \
	)                 \
	_buffer[(_offset)*2+0] = uvec4(_numVertices, _numInstances, _startVertex, _startInstance)

#define drawIndexedIndirect( \
	  _buffer                \
	, _offset                \
	, _numIndices            \
	, _numInstances          \
	, _startIndex            \
	, _startVertex           \
	, _startInstance         \
	)                        \
	_buffer[(_offset)*2+0] = uvec4(_numIndices, _numInstances, _startIndex, _startVertex); \
	_buffer[(_offset)*2+1] = uvec4(_startInstance, 0u, 0u, 0u)

#endif // __cplusplus

#endif // BGFX_COMPUTE_H_HEADER_GUARD
