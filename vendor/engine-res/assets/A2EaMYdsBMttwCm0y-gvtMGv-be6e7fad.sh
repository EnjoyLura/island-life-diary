#ifndef SSR_TRACE_CONFIG_SH
#define SSR_TRACE_CONFIG_SH

// Independent of platform: keep the inexpensive fixed-step trace as the default.
#ifndef SSR_LUMEN_TRACE
#define SSR_LUMEN_TRACE 0
#endif
#ifndef HZB_TRACE_INCLUDE_FULL_RES_DEPTH
#define HZB_TRACE_INCLUDE_FULL_RES_DEPTH 1
#endif
#if SSR_LUMEN_TRACE && !HZB_TRACE_INCLUDE_FULL_RES_DEPTH
#error Lumen_trace_requires_full_resolution_depth
#endif

#endif
