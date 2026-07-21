//VoxelTrace — per-pixel ray-traced block lighting against the voxel volume.
//Requires: VoxelCommon.glsl, Utilities.glsl, cameraPosition uniform.

#ifndef VOXEL_TRACE
#define VOXEL_TRACE

#include "/Lib/Voxel/VoxelCommon.glsl"

// Fine sub-block DDA inside one block-level voxel, in the level-k grid.
// Returns true if a level-k solid voxel is hit between tIn and tOut along start+t*dir.
bool VoxelFineTrace(vec3 start, vec3 dir, float tIn, float tOut, ivec3 blockVoxel, int k){
	float scale = float(1 << k);
	vec3 half_ = vec3(voxelVolumeSize / 2);

	// position in the level-k scaled grid
	vec3 p = ((start + (tIn + 1e-4) * dir) - half_) * scale + half_;
	vec3 fdir = dir; // direction is unchanged by uniform scaling

	ivec3 voxel = ivec3(floor(p));
	ivec3 stepDir = ivec3(sign(fdir));
	vec3 absInv = 1.0 / max(abs(fdir), vec3(1e-6));
	vec3 tNext = (sign(fdir) * (0.5 - fract(p)) + 0.5) * absInv;

	float tSpan = (tOut - tIn) * scale; // remaining distance in fine units
	int maxSteps = 3 * (1 << k) + 2;
	int solidBit = 1 << k;

	float t = 0.0;
	for (int i = 0; i < maxSteps; i++){
		if ((imageLoad(occupancyVolume, voxel).r & solidBit) != 0) return true;

		float tHit = min(min(tNext.x, tNext.y), tNext.z);
		bvec3 axis = equal(tNext, vec3(tHit));
		voxel += ivec3(axis) * stepDir;
		tNext += vec3(axis) * absInv;
		t = tHit;

		if (t >= tSpan) break;
	}
	return false;
}

// DDA through the occupancy volume. start/end in continuous voxel space.
// Returns the RGB transmittance of the segment: 1.0 = clear, 0.0 = blocked,
// tinted when passing through stained glass or water (VOXEL_GLASS_TINT).
vec3 VoxelShadowTrace(vec3 start, vec3 end){
	vec3 dir = end - start;
	float len = length(dir);
	if (len < 1e-4) return vec3(1.0);
	dir /= len;

	// stop slightly before the light voxel so the source voxel never occludes itself
	float tMax = len - 0.5;
	if (tMax <= 0.0) return vec3(1.0);

	ivec3 voxel = ivec3(floor(start));
	ivec3 stepDir = ivec3(sign(dir));
	vec3 absInv = 1.0 / max(abs(dir), vec3(1e-6));
	vec3 tNext = (sign(dir) * (0.5 - fract(start)) + 0.5) * absInv;

	vec3 transmittance = vec3(1.0);

	float t = 0.0;
	for (int i = 0; i < 64; i++){
		// advance to the next voxel boundary and evaluate the voxel we enter
		float tHit = min(min(tNext.x, tNext.y), tNext.z);
		bvec3 axis = equal(tNext, vec3(tHit));
		voxel += ivec3(axis) * stepDir;
		tNext += vec3(axis) * absInv;
		t = tHit;
		if (t >= tMax) return transmittance;
		if (!InsideVoxelVolume(voxel)) return transmittance;

		int occupancy = imageLoad(occupancyVolume, voxel).r;

		if ((occupancy & 1) != 0){
			#if VOXEL_DETAIL > 1
				// refine only with fine levels that were REALLY written for this block
				// (presence bits 4-6); a solid block without fine data stays fully solid
				int k = (occupancy & (1 << 6)) != 0 ? 3 :
				        ((occupancy & (1 << 5)) != 0 ? 2 :
				        ((occupancy & (1 << 4)) != 0 ? 1 : 0));
				if (k == 0) return vec3(0.0);

				float tExit = min(min(min(tNext.x, tNext.y), tNext.z), tMax);
				if (VoxelFineTrace(start, dir, t, tExit, voxel, k)) return vec3(0.0);
				// ray slips through the gaps of a partial block: keep going
			#else
				return vec3(0.0);
			#endif
		}
		#ifdef VOXEL_GLASS_TINT
			else if ((occupancy & (1 << 8)) != 0){
				vec3 tintCol = VoxelReadLightColor(voxel);
				float strength = (occupancy & (1 << 9)) != 0 ? 0.22 : 0.65;
				transmittance *= mix(vec3(1.0), tintCol, strength);
			}
		#endif
	}
	return transmittance;
}


// scenePos: camera-relative world pos of the shaded point. worldNormal: world-space normal.
// noise: per-frame jitter in [0,1)^3 for penumbra (smoothed by TAA).
// worldViewDir: normalized direction camera->surface (world space), for specular.
// Returns accumulated RGB diffuse light; specular highlight accumulates into voxelSpecular.
vec3 VoxelBlockLighting(vec3 scenePos, vec3 worldNormal, vec3 noise, vec3 worldViewDir, float roughness, float f0, inout vec3 voxelSpecular){
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
		vec3 visibility = VoxelShadowTrace(surfacePos, lightPos + jitter);
		if (max(max(visibility.r, visibility.g), visibility.b) <= 0.0) continue;

		vec3 lightCol = VoxelReadLightColor(lightCoord);

		lighting += lightCol * visibility * weight;

		#ifdef VOXEL_SPECULAR
			float ggx = SpecularGGX(worldNormal, -worldViewDir, toLight / max(dist, 1e-4),
			                        clamp(roughness, 0.0015, 0.9), f0);
			ggx *= saturate(4.0 - roughness * 3.5);
			voxelSpecular += lightCol * visibility * (ggx * atten);
		#endif
	}

	return lighting;
}

#endif
