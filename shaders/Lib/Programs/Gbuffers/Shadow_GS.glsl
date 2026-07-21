//Shadow_GS — passthrough for the shadow map + world voxelization for ray-traced block light.
//Voxelization approach adapted from Rethinking Voxels (by gri573).


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in vec2 texCoordV[];
in vec3 colorV[];
in vec3 normalV[];
in vec2 blockLightV[];
in float tiltedV[];
in vec3 scenePosV[];
in vec3 midBlockV[];
flat in int matIdV[];

out vec2 texCoord;
out vec3 color;
out vec3 normal;
out vec2 blockLight;
out float tilted;


uniform sampler2D tex;
uniform ivec2 atlasSize;
uniform int renderStage;
uniform vec3 cameraPosition;

#ifdef VOXEL_BLOCKLIGHT

#define WRITE_TO_VOXELS
#include "/Lib/Voxel/VoxelCommon.glsl"


// Returns true if the block ID is a light emitter. Sets color (or texture detection), light level.
bool VoxelEmitterParams(int id, out vec3 col, out int level, out bool fromTexture){
	col = vec3(1.0);
	level = 0;
	fromTexture = false;

	if (id == 50){ // torch, end rod, lit campfire
		col = vec3(1.0, 0.57, 0.24); level = 14;
	}else if (id == 10){ // lava
		col = vec3(1.0, 0.42, 0.13); level = 15;
	}else if (id == 89){ // glowstone, sea lantern, shroomlight, froglights, lantern...
		fromTexture = true; level = 15;
	}else if (id == 51){ // fire
		col = vec3(1.0, 0.50, 0.18); level = 15;
	}else if (id == 76){ // redstone torch
		col = vec3(1.0, 0.12, 0.05); level = 7;
	}else if (id == 55){ // redstone wire: vertex color encodes power
		col = vec3(1.0, 0.10, 0.05);
		level = colorV[0].r > 0.6 ? 7 : 0;
	}else if (id == 213){ // magma block
		col = vec3(1.0, 0.35, 0.12); level = 3;
	}else if (id == 7100){ // soul fire family
		col = vec3(0.25, 0.80, 1.0); level = 10;
	}else if (id == 7101){ // amethyst
		col = vec3(0.75, 0.50, 1.0); level = 5;
	}else if (id == 7102){ // oxidized copper bulb
		fromTexture = true; level = 4;
	}else if (id == 7103){ // jack o'lantern, crying obsidian, respawn anchor, lit candles
		fromTexture = true; level = 12;
	}

	return level > 0;
}

void DoVoxelization(){
	if (renderStage != MC_RENDER_STAGE_TERRAIN_SOLID &&
	    renderStage != MC_RENDER_STAGE_TERRAIN_CUTOUT &&
	    renderStage != MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED) return;

	int id = matIdV[0];

	// water, ice, stained glass, end portal: never voxelized
	if (id == 8 || id == 79 || id == 95 || id == 119) return;
	// foliage and vines: light passes through
	if (id == 7000 || id == 7010 || id == 7011 || id == 7020 || id == 7021 || id == 7040) return;

	vec3 blockCenter = scenePosV[0] + midBlockV[0];
	ivec3 coords = ivec3(floor(blockCenter + VoxelCameraFract()) + 1000.5) - 1000 + voxelVolumeSize / 2;
	if (!InsideVoxelVolume(coords)) return;

	vec3 col;
	int level;
	bool fromTexture;

	if (VoxelEmitterParams(id, col, level, fromTexture)){
		if (fromTexture){
			vec2 minTexCoord = min(min(texCoordV[0], texCoordV[1]), texCoordV[2]);
			vec2 maxTexCoord = max(max(texCoordV[0], texCoordV[1]), texCoordV[2]);
			int lodLevel = int(log2(max(4.1, 1.01 * min((maxTexCoord.x - minTexCoord.x) * atlasSize.x,
			                                            (maxTexCoord.y - minTexCoord.y) * atlasSize.y)))) - 2;
			col = textureLod(tex, 0.5 * (minTexCoord + maxTexCoord), float(lodLevel)).rgb * colorV[0];

			// boost saturation so the light color reads clearly (RV-style)
			float brightness = max(max(col.r, col.g), col.b);
			col -= brightness;
			float minVal = max(0.0001, max(max(abs(col.r), abs(col.g)), abs(col.b)));
			col *= mix(1.0, min(1.0 + 4.0 * VOXEL_COLOR_SATURATION, brightness / minVal), VOXEL_COLOR_SATURATION);
			col += brightness;
			col = saturate(col);
		}

		imageAtomicOr(occupancyVolume, coords, (1 << 16) | (clamp(level, 0, 31) << 17));

		ivec2 packedCol = ivec2(int(20.0 * col.r) + (int(20.0 * col.g) << 13),
		                        int(20.0 * col.b) + (1 << 23));
		imageAtomicAdd(voxelCols, coords * ivec3(1, 2, 1), packedCol.x);
		imageAtomicAdd(voxelCols, coords * ivec3(1, 2, 1) + ivec3(0, 1, 0), packedCol.y);
	}else{
		if (id == 55) return; // unpowered redstone wire: flat overlay, never occludes

		// skip small/diagonal geometry (flowers, rails, unknown decorations) so it does not block light
		vec3 e0 = scenePosV[1] - scenePosV[0];
		vec3 e1 = scenePosV[2] - scenePosV[1];
		vec3 e2 = scenePosV[0] - scenePosV[2];
		if (max(max(dot(e0, e0), dot(e1, e1)), dot(e2, e2)) < 0.36) return;

		vec3 cnormal = normalize(cross(e0, -e2) + vec3(1e-6, 2e-6, 3e-6));
		if (length(abs(cnormal.xz) - vec2(sqrt(0.5))) < 0.01) return; // X-shaped quads

		imageAtomicOr(occupancyVolume, coords, 1);
	}
}

#endif


void main(){
	#ifdef VOXEL_BLOCKLIGHT
		DoVoxelization();
	#endif

	for (int i = 0; i < 3; i++){
		gl_Position = gl_in[i].gl_Position;
		texCoord = texCoordV[i];
		color = colorV[i];
		normal = normalV[i];
		blockLight = blockLightV[i];
		tilted = tiltedV[i];
		EmitVertex();
	}
	EndPrimitive();
}
