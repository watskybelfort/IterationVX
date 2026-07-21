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
//   bit  0     : solid occluder
//   bit  16    : light source present
//   bits 17-21 : light level (0..31)

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

layout(std430, binding = 0) VOXEL_SSBO_QUALIFIER buffer voxelLightLists {
	int voxelCellLightCount[3072];
	int voxelCellLightData[3072 * 64];
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

int VoxelLightLevel(int occupancyData){
	return (occupancyData >> 17) & 31;
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
