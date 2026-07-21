//VoxelSettings — Ray-traced voxel block light (ported concept from Rethinking Voxels)

#ifndef VOXEL_SETTINGS
#define VOXEL_SETTINGS

#define VOXEL_BLOCKLIGHT // Ray-traced colored block light. Voxelizes the world in the shadow pass and traces rays to nearby light sources. Requires Iris.

#define VOXELLIGHT_BRIGHTNESS 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0 4.0]
#define VOXEL_LIGHT_SIZE 0.4 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8]
#define VOXEL_MAX_TRACES 16 // [4 8 12 16 24 32 48]
#define VOXEL_AMBIENT_MULT 0.20 // [0.0 0.05 0.10 0.15 0.20 0.25 0.30 0.40 0.50 0.75 1.0]
#define VOXEL_RANGE_MULT 1.0 // [0.75 1.0 1.25 1.5]
#define VOXEL_COLOR_SATURATION 0.5 // [0.0 0.25 0.5 0.75 1.0]
#define VOXEL_DETAIL 3 // [1 2 3 4]
#define VOXEL_GLASS_TINT // Light rays passing through stained glass and water get tinted by their color.
#define VOXEL_SPECULAR // Ray-traced specular highlights from block lights (shiny reflections of torches etc.)
#define VOXEL_SPECULAR_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define VOXEL_SKIP_UNLIT // Skip ray tracing on pixels with zero vanilla block light (big speedup, no visual cost)
#define VOXEL_LIGHT_THINNING // In dense emitter fields (lava lakes) register every other emitter; the normalized lighting model keeps brightness identical, shadows get marginally coarser
#define VOXEL_DEBUG 0 // [0 1] Debug: paint the raw traced factor (color x shadows) instead of lighting. For diagnosing, best viewed in caves/Nether.
#define NETHER_LAVA_GLOW 0.4 // [0.15 0.2 0.3 0.4 0.5 0.6 0.8 1.0] Emissive brightness of lava surfaces in the Nether (tames the huge bloom glow over lava lakes)

#endif
