#version 430

//Sorts each cell's light list by distance to the cell center (insertion sort, one thread per cell).
//This makes the list order deterministic between frames (atomicAdd order is not) and ensures the
//per-pixel trace cap keeps the nearest lights, so scenes with many lights do not flicker.

#define DIMENSION_MAIN

#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"

uniform vec3 cameraPosition;

#define WRITE_TO_LIGHT_LIST
#include "/Lib/Voxel/VoxelCommon.glsl"

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(48, 1, 1);

void main(){
	int cellIndex = int(gl_GlobalInvocationID.x);
	if (cellIndex >= voxelCellTotal) return;

	int n = min(voxelCellLightCount[cellIndex], VOXEL_MAX_LIGHTS_PER_CELL);
	voxelCellLightCount[cellIndex] = n;
	if (n < 2) return;

	ivec3 cell = ivec3(cellIndex % voxelCellCount.x,
	                   (cellIndex / voxelCellCount.x) % voxelCellCount.y,
	                   cellIndex / (voxelCellCount.x * voxelCellCount.y));
	vec3 cellCenter = vec3(cell * 8) + 4.0;

	int entries[64];
	float keys[64];

	for (int i = 0; i < n; i++){
		int e = voxelCellLightData[cellIndex * VOXEL_MAX_LIGHTS_PER_CELL + i];
		vec3 d = vec3(UnpackVoxelCoord(e)) + 0.5 - cellCenter;
		// primary key: distance; tiny coord-based bias breaks ties deterministically
		float key = dot(d, d) + float(e & 1023) * 1e-6;

		int j = i - 1;
		while (j >= 0 && keys[j] > key){
			keys[j + 1] = keys[j];
			entries[j + 1] = entries[j];
			j--;
		}
		keys[j + 1] = key;
		entries[j + 1] = e;
	}

	for (int i = 0; i < n; i++){
		voxelCellLightData[cellIndex * VOXEL_MAX_LIGHTS_PER_CELL + i] = entries[i];
	}
}
