//Shadow_FS


#include "/Lib/Settings.glsl"
#include "/Lib/Utilities.glsl"


const int shadowMapResolution = 2048; // [1024 2048 4096 8192 16384 32768]
const float shadowDistance = 192.0; // [64.0 96.0 128.0 192.0 256.0 384.0 512.0 768.0 1024.0 1536.0 2048.0]


uniform float far;

uniform sampler2D tex;


in vec2 texCoord;
in vec3 color;
in vec3 normal;
in vec2 blockLight;
in float tilted;

#if defined SHADOW_VOXEL && defined VOXEL_BLOCKLIGHT
	flat in int passType;
	in vec3 vxPosF;
	flat in vec3 voxelFaceNormal;

	uniform vec3 cameraPosition;

	#define WRITE_TO_VOXELS
	#include "/Lib/Voxel/VoxelCommon.glsl"
#endif

#ifdef PROGRAM_DH_SHADOW
	uniform vec3 cameraPosition;
	uniform mat4 shadowProjectionInverse;
	uniform mat4 shadowProjection;
	uniform mat4 shadowModelViewInverse;
	uniform float pixelSize;

	#ifdef DIMENSION_END
		#include "/Lib/Uniform/ShadowModelViewEnd.glsl"
	#endif

	uniform int dhRenderDistance;

	in vec3 viewPos;
#endif


void main(){
	#if defined SHADOW_VOXEL && defined VOXEL_BLOCKLIGHT
		// voxel raster fragment: write fine (sub-block) occupancy levels and stop
		if (passType > 0){
			vec4 voxelTex = textureLod(tex, texCoord, 0.0);
			if (voxelTex.a > 0.5){
				int presence = 0;
				for (int k = 1; k <= passType; k++){
					vec3 pos2 = vxPosF * float(1 << k) + 0.5 * vec3(voxelVolumeSize);
					// bias fragments sitting exactly on voxel faces into the block interior
					if (floor((pos2 - 0.003 * voxelFaceNormal) / float(1 << k)) ==
					    floor((pos2 - 0.1561271 * voxelFaceNormal) / float(1 << k))){
						pos2 -= 0.1561271 * voxelFaceNormal;
					}
					if (any(lessThan(pos2, vec3(0.0))) || any(greaterThanEqual(pos2, vec3(voxelVolumeSize) - 0.01))) break;
					imageAtomicOr(occupancyVolume, ivec3(pos2), 1 << k);
					presence |= 1 << (3 + k);
				}
				// record on the block-level voxel which fine levels really exist,
				// so the tracer never assumes fine data that was not written
				if (presence != 0){
					vec3 pos0 = vxPosF + 0.5 * vec3(voxelVolumeSize);
					if (floor(pos0 - 0.003 * voxelFaceNormal) == floor(pos0 - 0.1561271 * voxelFaceNormal)){
						pos0 -= 0.1561271 * voxelFaceNormal;
					}
					if (!(any(lessThan(pos0, vec3(0.0))) || any(greaterThanEqual(pos0, vec3(voxelVolumeSize) - 0.01)))){
						imageAtomicOr(occupancyVolume, ivec3(pos0), presence);
					}
				}
			}
			discard;
		}
	#endif

	#ifdef PROGRAM_DH_SHADOW
		#ifdef DH_SHADOW_CULLING
			vec3 viewPosOrigin = viewPos;
			viewPosOrigin.z += 100.0;
			#ifdef DIMENSION_END		
				vec3 worldPosInterval = mat3(shadowModelViewInverseEnd) * viewPosOrigin;
			#else
				vec3 worldPosInterval = mat3(shadowModelViewInverse) * viewPosOrigin;
			#endif

			vec2 worldDist = vec2(length(worldPosInterval.xz), worldPosInterval.y);

			float clipDist = min(shadowDistance, far) * 0.7;
			#ifdef DH_SHADOW_FIX
				if (worldDist.x < clipDist && worldDist.y > -clipDist || normal.z <= 0.0) discard;
			#else
				if (worldDist.x < clipDist && worldDist.y > -clipDist) discard;
			#endif
		#else
			#ifdef DH_SHADOW_FIX
				if (normal.z <= 0.0) discard;
			#endif
		#endif

		#ifdef DH_SHADOW_FIX
			vec2 currNdcPos = gl_FragCoord.xy / float(shadowMapResolution) * 2.0 - 1.0;
			currNdcPos *= (1.0 - SHADOW_MAP_BIAS) / (0.95 - length(currNdcPos) * SHADOW_MAP_BIAS);
			vec2 currViewPos = currNdcPos * vec2(shadowProjectionInverse[0][0], shadowProjectionInverse[0][0]);

			float z = viewPos.z;

			z += dot(viewPos.xy - currViewPos, normal.xy) / normal.z; 
				
			gl_FragDepth = 0.5 - z * shadowProjection[0][0] * 0.25;
		#endif
	#elif 0
	#endif

	vec4 tex = textureLod(tex, texCoord, 0.0);
	tex.rgb *= color;

	#ifdef WHITE_DEBUG_WORLD
		tex.rgb = vec3(1.0);
	#endif

	if (!gl_FrontFacing && tilted == 0.0) tex.rgb = vec3(0.0);

	vec3 shadowNormal = normal.xyz;

	gl_FragData[0] = tex;
	gl_FragData[1] = vec4(shadowNormal.xyz * 0.5 + 0.5, blockLight.y);
}
