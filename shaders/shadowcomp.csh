#version 430

//Clears the per-cell voxel light lists (runs after the shadow/voxelization pass each frame).

#define DIMENSION_MAIN

#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"

uniform vec3 cameraPosition;

#define WRITE_TO_LIGHT_LIST
#include "/Lib/Voxel/VoxelCommon.glsl"

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(12, 1, 1);

void main(){
	int idx = int(gl_GlobalInvocationID.x);
	if (idx < voxelCellTotal){
		voxelCellLightCount[idx] = 0;
	}
}
