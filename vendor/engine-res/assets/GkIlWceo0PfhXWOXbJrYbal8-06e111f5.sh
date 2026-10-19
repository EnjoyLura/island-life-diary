// Instantiate the shared BRDF with explicit coat parameters. Ordinary PBR keeps
// its original overload, including its exact zero-coat behavior and light loops.
#define CLEAR_COAT
#define CLEAR_COAT_BOTTOM_NORMAL
#include "PBR/ClearCoat.sh"
#if NONPUNCTUAL_LIGHTING
#include "PBR/CapsuleLight.sh"
#endif
#if NONPUNCTUAL_LIGHTING || defined(RECTLIGHT)
#include "PBR/RectLight.sh"
#endif
#include "PBR/DisneyBRDF.glsl"
#include "PBR/MetallicWorkflow.glsl"
#undef CLEAR_COAT_BOTTOM_NORMAL
#undef CLEAR_COAT
#include "PBR/ClearCoat.sh"
