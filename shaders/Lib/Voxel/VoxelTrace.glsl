//VoxelTrace — per-pixel ray-traced block lighting against the voxel volume.
//Requires: VoxelCommon.glsl, Utilities.glsl, cameraPosition uniform.

#ifndef VOXEL_TRACE
#define VOXEL_TRACE

#include "/Lib/Voxel/VoxelCommon.glsl"

// DDA through the occupancy volume. start/end in continuous voxel space.
// Returns 1.0 if the segment is unoccluded, 0.0 if a solid voxel blocks it.
float VoxelShadowTrace(vec3 start, vec3 end){
	vec3 dir = end - start;
	float len = length(dir);
	if (len < 1e-4) return 1.0;
	dir /= len;

	// stop slightly before the light voxel so the source voxel never occludes itself
	float tMax = len - 0.5;
	if (tMax <= 0.0) return 1.0;

	ivec3 voxel = ivec3(floor(start));
	ivec3 stepDir = ivec3(sign(dir));
	vec3 absInv = 1.0 / max(abs(dir), vec3(1e-6));
	vec3 tNext = (sign(dir) * (0.5 - fract(start)) + 0.5) * absInv;

	float t = 0.0;
	for (int i = 0; i < 64; i++){
		// advance to the next voxel boundary
		float tHit = min(min(tNext.x, tNext.y), tNext.z);
		bvec3 axis = equal(tNext, vec3(tHit));
		voxel += ivec3(axis) * stepDir;
		tNext += vec3(axis) * absInv;
		t = tHit;

		if (t >= tMax) return 1.0;
		if (!InsideVoxelVolume(voxel)) return 1.0;

		if (VoxelIsSolid(imageLoad(occupancyVolume, voxel).r)) return 0.0;
	}
	return 1.0;
}


// scenePos: camera-relative world pos of the shaded point. worldNormal: world-space normal.
// noise: per-frame jitter in [0,1)^3 for penumbra (smoothed by TAA).
// Returns accumulated RGB light (unit peak color * attenuation), to be scaled by the caller.
vec3 VoxelBlockLighting(vec3 scenePos, vec3 worldNormal, vec3 noise){
	vec3 voxelPos = VoxelSpacePos(scenePos);

	if (VoxelEdgeFade(voxelPos) >= 1.0) return vec3(0.0);

	// escape the surface voxel
	vec3 surfacePos = voxelPos + worldNormal * 0.05;

	ivec3 cell = clamp(ivec3(voxelPos) >> 3, ivec3(0), voxelCellCount - 1);
	int cellIndex = VoxelCellIndex(cell);
	int count = min(voxelCellLightCount[cellIndex], VOXEL_MAX_LIGHTS_PER_CELL);

	if (count == 0) return vec3(0.0);

	// sphere jitter for soft penumbra
	vec3 jitter = (noise * 2.0 - 1.0) * VOXEL_LIGHT_SIZE * 0.5;

	vec3 lighting = vec3(0.0);
	int traces = 0;

	for (int i = 0; i < count && traces < VOXEL_MAX_TRACES; i++){
		ivec3 lightCoord = UnpackVoxelCoord(voxelCellLightData[cellIndex * VOXEL_MAX_LIGHTS_PER_CELL + i]);

		int occupancy = imageLoad(occupancyVolume, lightCoord).r;
		if (!VoxelIsLight(occupancy)) continue;
		float level = float(VoxelLightLevel(occupancy));
		if (level < 0.5) continue;

		vec3 lightPos = vec3(lightCoord) + 0.5;
		vec3 toLight = lightPos - voxelPos;
		float dist = length(toLight);

		float range = level * VOXEL_RANGE_MULT;
		if (dist > range) continue;

		float ndotl = dot(worldNormal, toLight / max(dist, 1e-4));
		// light inside/level with the surface voxel: avoid black caps on the emitting face
		ndotl = dist < 0.87 ? 1.0 : saturate(ndotl * 0.9 + 0.1);
		if (ndotl <= 0.0) continue;

		float window = saturate(1.0 - dist / range);
		float atten = window * window * 3.0 / (dist * dist + 0.5);

		float weight = atten * ndotl;
		if (weight < 0.002) continue;

		traces++;
		float visibility = VoxelShadowTrace(surfacePos, lightPos + jitter);
		if (visibility <= 0.0) continue;

		vec3 lightCol = VoxelReadLightColor(lightCoord);

		lighting += lightCol * (weight * visibility);
	}

	return lighting;
}

#endif
