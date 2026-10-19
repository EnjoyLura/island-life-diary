// Instantiate shared lighting without adding BACKLIGHT work to ordinary PBR.
// Distinct names avoid overload collisions with other vec3 material parameters.
#define USES_BACKLIGHT
#define GetLightingColor GetBacklightLightingColor
#define Disney_BRDF BacklightDisneyBRDF
#define Disney_BRDF_Split BacklightDisneyBRDFSplit
#define MetallicPBR BacklightMetallicPBR
#define MetallicPBR_Split BacklightMetallicPBRSplit
#define GetCapsuleLighting GetBacklightCapsuleLighting
#define GetSphereLighting GetBacklightSphereLighting
#define GetRectLightBRDF GetBacklightRectLightBRDF
#define GetRectLighting GetBacklightRectLighting
#if NONPUNCTUAL_LIGHTING
#include "PBR/CapsuleLight.sh"
#endif
#if NONPUNCTUAL_LIGHTING || defined(RECTLIGHT)
#include "PBR/RectLight.sh"
#endif
#include "PBR/DisneyBRDF.glsl"
#include "PBR/MetallicWorkflow.glsl"
#undef GetRectLighting
#undef GetRectLightBRDF
#undef GetSphereLighting
#undef GetCapsuleLighting
#undef MetallicPBR_Split
#undef MetallicPBR
#undef Disney_BRDF_Split
#undef Disney_BRDF
#undef GetLightingColor
#undef USES_BACKLIGHT
