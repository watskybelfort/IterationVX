//VoxelCommon — shared constants, layouts and helpers for the voxel block light system.
//Voxelization concept adapted from Rethinking Voxels (by gri573).

#ifndef VOXEL_COMMON
#define VOXEL_COMMON

#include "/Lib/Voxel/VoxelSettings.glsl"

const ivec3 voxelVolumeSize = ivec3(128, 96, 128);

// Light-list cells (clustered lights). Cell = 8x8x8 voxels.
const ivec3 voxelCellCount = voxelVolumeSize / 8;                  // 16 x 12 x 16
const int   voxelCellTotal = voxelCellCount.x * voxelCellCount.y * voxelCellCount.z; // 3072
const int   VOXEL_MAX_LIGHTS_PER_CELL = 64;

// occupancyVolume bit layout (r32i per voxel):
//   bits 0-3   : solid occluder at detail level k (level k voxels are 1/2^k blocks,
//                covering the central voxelVolumeSize/2^k region around the camera;
//                bit 0 is conservative: set whenever any finer level is set)
//   bits 4-6   : fine data presence: level 1/2/3 was actually rasterized for this block.
//                If a solid block has no presence bits, it must be treated as fully
//                solid (never assume fine data that was not written -> no light leaks).
//   bit  8     : translucent tint voxel (stained glass / water), color in voxelCols
//   bit  9     : water (weaker tint than glass)
//   bit  16    : light source present
//   bits 17-21 : light level (0..31)
//   bits 22-29 : octant occupancy mask (2x2x2 half-block corners actually covered
//                by geometry; bit = x + y*2 + z*4, 0 = lower half per axis).
//                Written by the shadow GS from vertex data (deterministic).
//                0 = no mask data -> treat as fully solid. 255 = full cube.

#ifndef WRITE_TO_VOXELS
	layout(r32i) uniform readonly iimage3D occupancyVolume;
	layout(r32i) uniform readonly iimage3D voxelCols;
#else
	layout(r32i) uniform restrict iimage3D occupancyVolume;
	layout(r32i) uniform restrict iimage3D voxelCols;
#endif

#ifndef WRITE_TO_LIGHT_LIST
	#define VOXEL_SSBO_QUALIFIER readonly
#else
	#define VOXEL_SSBO_QUALIFIER
#endif

// Final per-cell lists (read by the trace) + per-cell OWN lists (stage 1: each
// light registers only in its own cell; stage 2 gathers from neighbor cells and
// keeps the 64 nearest — deterministic, unlike slot races on overflow).
layout(std430, binding = 0) VOXEL_SSBO_QUALIFIER buffer voxelLightLists {
	int voxelCellLightCount[3072];
	int voxelCellLightData[3072 * 64];
	int voxelCellOwnCount[3072];
	int voxelCellOwnData[3072 * 64];
};


vec3 VoxelCameraFract(){
	return fract(cameraPosition);
}

// scenePos: player/camera-relative world position. Returns continuous voxel-space position.
vec3 VoxelSpacePos(vec3 scenePos){
	return scenePos + VoxelCameraFract() + vec3(voxelVolumeSize / 2);
}

ivec3 VoxelCoord(vec3 scenePos){
	return ivec3(floor(scenePos + VoxelCameraFract()) + 1000.5) - 1000 + voxelVolumeSize / 2;
}

bool InsideVoxelVolume(ivec3 c){
	return all(greaterThanEqual(c, ivec3(0))) && all(lessThan(c, voxelVolumeSize));
}

// 0 in the interior -> 1 at the border of the voxel volume; used to fade back to vanilla light.
float VoxelEdgeFade(vec3 voxelPos){
	vec3 rel = abs(voxelPos / vec3(voxelVolumeSize) * 2.0 - 1.0);
	float edge = max(max(rel.x, rel.y), rel.z);
	return saturate(edge * 6.667 - 5.667); // fades over the outer 15%
}

int VoxelCellIndex(ivec3 cell){
	return (cell.z * voxelCellCount.y + cell.y) * voxelCellCount.x + cell.x;
}

int PackVoxelCoord(ivec3 c){
	return c.x | (c.y << 8) | (c.z << 16);
}

ivec3 UnpackVoxelCoord(int p){
	return ivec3(p & 255, (p >> 8) & 255, (p >> 16) & 255);
}

// Light-list entries carry the voxel coord (bits 0-23) and the light level
// (bits 24-28), so the per-pixel pass needs no occupancy reads per light.
int PackLightEntry(ivec3 c, int level){
	return PackVoxelCoord(c) | (level << 24);
}

int LightEntryLevel(int e){
	return (e >> 24) & 31;
}

int VoxelLightLevel(int occupancyData){
	return (occupancyData >> 17) & 31;
}

// Finest detail level with data at camera-relative position p (voxel units).
// margin < 1.0 shrinks the region: use ~0.9 when READING so the level chosen is
// always one the voxelizer (margin 1.0) actually wrote near region boundaries.
int VoxelDetailLevel(vec3 pCamRel, float margin){
	vec3 rel = abs(pCamRel) * (2.0 / vec3(voxelVolumeSize));
	float m = max(max(rel.x, rel.y), rel.z);
	int k = 0;
	for (int i = 1; i < VOXEL_DETAIL; i++){
		if (m * float(1 << i) < margin) k = i;
	}
	return k;
}

// voxelPos = camera-relative + voxelVolumeSize/2 (continuous). Coord in the level-k grid.
ivec3 VoxelCoordAtLevel(vec3 voxelPos, int k){
	vec3 p = voxelPos - vec3(voxelVolumeSize / 2);
	return ivec3(floor(p * float(1 << k) + 1000.0) - 1000) + voxelVolumeSize / 2;
}

bool VoxelIsLight(int occupancyData){
	return (occupancyData & (1 << 16)) != 0;
}

bool VoxelIsSolid(int occupancyData){
	return (occupancyData & 1) != 0;
}

// voxelCols layout: two r32i entries per voxel at (x, 2y, z) and (x, 2y+1, z)
//   entry0: R (bits 0-12) | G (bits 13-25)
//   entry1: B (bits 0-12) | sample count (bits 23-31)
vec3 VoxelReadLightColor(ivec3 coords){
	int raw0 = imageLoad(voxelCols, coords * ivec3(1, 2, 1)).r;
	int raw1 = imageLoad(voxelCols, coords * ivec3(1, 2, 1) + ivec3(0, 1, 0)).r;
	float n = float(raw1 >> 23);
	vec3 col = vec3(raw0 & 8191, (raw0 >> 13) & 8191, raw1 & 8191) / max(20.0 * n, 1.0);
	// normalize hue to unit peak; intensity comes from the light level
	col /= max(max(col.r, col.g), max(col.b, 0.0001));
	return col;
}

#endif
