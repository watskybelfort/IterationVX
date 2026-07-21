#version 430

//Builds per-cell light lists: every emitter voxel registers itself in all 8x8x8 cells
//that its light range can reach, so the per-pixel pass only iterates nearby lights.

#define DIMENSION_MAIN

#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"

uniform vec3 cameraPosition;

#define WRITE_TO_LIGHT_LIST
#include "/Lib/Voxel/VoxelCommon.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
const ivec3 workGroups = ivec3(16, 12, 16);

void main(){
	ivec3 coords = ivec3(gl_GlobalInvocationID);

	int occupancy = imageLoad(occupancyVolume, coords).r;
	if (!VoxelIsLight(occupancy)) return;

	int lightLevel = VoxelLightLevel(occupancy);

	#ifdef VOXEL_LIGHT_THINNING
		// dense max-level emitter fields (lava lakes, fire seas): register every other
		// voxel in x/z; the normalized lighting model keeps brightness identical.
		// Parity is computed in WORLD space so the pattern stays stable while moving.
		if (lightLevel >= 15){
			ivec3 camFloor = ivec3(floor(cameraPosition));
			ivec3 parity = (coords + camFloor) & ivec3(1);
			ivec3 evenCoords = coords - ivec3(parity.x, 0, parity.z);
			if (evenCoords != coords){
				int neighbor = imageLoad(occupancyVolume, evenCoords).r;
				if (VoxelIsLight(neighbor) && VoxelLightLevel(neighbor) >= 15) return;
			}
		}
	#endif

	float range = float(lightLevel) * VOXEL_RANGE_MULT;
	if (range < 0.5) return;

	ivec3 cellMin = clamp(ivec3(floor(vec3(coords) + 0.5 - range)) >> 3, ivec3(0), voxelCellCount - 1);
	ivec3 cellMax = clamp(ivec3(floor(vec3(coords) + 0.5 + range)) >> 3, ivec3(0), voxelCellCount - 1);

	int packedCoord = PackVoxelCoord(coords);

	for (int z = cellMin.z; z <= cellMax.z; z++){
		for (int y = cellMin.y; y <= cellMax.y; y++){
			for (int x = cellMin.x; x <= cellMax.x; x++){
				int cellIndex = VoxelCellIndex(ivec3(x, y, z));
				int slot = atomicAdd(voxelCellLightCount[cellIndex], 1);
				if (slot < VOXEL_MAX_LIGHTS_PER_CELL){
					voxelCellLightData[cellIndex * VOXEL_MAX_LIGHTS_PER_CELL + slot] = packedCoord;
				}
			}
		}
	}
}
