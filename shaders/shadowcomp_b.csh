#version 430

//Builds each cell's FINAL light list: gathers candidates from all neighboring cells'
//own-lists (deterministic content, written by shadowcomp_a) and keeps the 64 nearest
//to the cell center, sorted. When more than 64 lights reach a cell, the FARTHEST are
//dropped deterministically — the old scheme let candidates race for slots via
//atomicAdd, so the surviving subset changed every frame (flicker with many lights).

#define DIMENSION_MAIN

#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"

uniform vec3 cameraPosition;

#define WRITE_TO_LIGHT_LIST
#include "/Lib/Voxel/VoxelCommon.glsl"

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(48, 1, 1);

// farthest cells a max-level emitter (15) can reach, plus the cell half-diagonal
const int NEIGHBOR_R = int(ceil((15.0 * VOXEL_RANGE_MULT + 6.929) / 8.0));

void main(){
	int cellIndex = int(gl_GlobalInvocationID.x);
	if (cellIndex >= voxelCellTotal) return;

	ivec3 cell = ivec3(cellIndex % voxelCellCount.x,
	                   (cellIndex / voxelCellCount.x) % voxelCellCount.y,
	                   cellIndex / (voxelCellCount.x * voxelCellCount.y));
	vec3 cellCenter = vec3(cell * 8) + 4.0;

	int entries[VOXEL_MAX_LIGHTS_PER_CELL];
	float keys[VOXEL_MAX_LIGHTS_PER_CELL];
	int m = 0;

	ivec3 nMin = max(cell - NEIGHBOR_R, ivec3(0));
	ivec3 nMax = min(cell + NEIGHBOR_R, voxelCellCount - 1);

	for (int z = nMin.z; z <= nMax.z; z++){
	for (int y = nMin.y; y <= nMax.y; y++){
	for (int x = nMin.x; x <= nMax.x; x++){
		int src = VoxelCellIndex(ivec3(x, y, z));
		int n = min(voxelCellOwnCount[src], VOXEL_MAX_LIGHTS_PER_CELL);

		for (int i = 0; i < n; i++){
			int e = voxelCellOwnData[src * VOXEL_MAX_LIGHTS_PER_CELL + i];
			vec3 d = vec3(UnpackVoxelCoord(e)) + 0.5 - cellCenter;
			float dsq = dot(d, d);

			// reject lights that cannot reach any point of this cell
			float reach = float(LightEntryLevel(e)) * VOXEL_RANGE_MULT + 6.929;
			if (dsq > reach * reach) continue;

			// primary key: distance; tiny coord-based bias breaks ties deterministically
			float key = dsq + float(e & 1023) * 1e-6;
			if (m == VOXEL_MAX_LIGHTS_PER_CELL && key >= keys[m - 1]) continue;

			// bounded insertion sort: when full, the farthest entry falls off the end
			int j = min(m, VOXEL_MAX_LIGHTS_PER_CELL - 1) - 1;
			while (j >= 0 && keys[j] > key){
				keys[j + 1] = keys[j];
				entries[j + 1] = entries[j];
				j--;
			}
			keys[j + 1] = key;
			entries[j + 1] = e;
			if (m < VOXEL_MAX_LIGHTS_PER_CELL) m++;
		}
	}}}

	voxelCellLightCount[cellIndex] = m;
	for (int i = 0; i < m; i++){
		voxelCellLightData[cellIndex * VOXEL_MAX_LIGHTS_PER_CELL + i] = entries[i];
	}
}
