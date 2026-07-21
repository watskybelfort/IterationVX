#version 430


#define DIMENSION_NETHER


#include "/Lib/UniformDeclare.glsl"
#include "/Lib/Utilities.glsl"


/*
const int 	colortex0Format         = RGBA8;
const vec4 	colortex0ClearColor 	= vec4(0.0, 0.0, 0.0, 1.0);
const int 	colortex1Format         = RGBA16;
const int 	colortex2Format         = RGBA16;
const int 	colortex3Format 		= RGBA16;
const int 	colortex4Format 		= RGBA16;
const int 	colortex5Format 		= RGBA16;
const int 	colortex6Format 		= RGBA16;
const int 	colortex7Format 		= RGBA32F;
const int 	colortex8Format 		= RGB16;

const bool	colortex2Clear          = false;
const bool	colortex7Clear          = false;


const float shadowDistanceRenderMul 	= 0.35;

const bool 	shadowHardwareFiltering1 	= false;
const bool 	shadowtex0Mipmap 			= false;
const bool 	shadowtex1Mipmap 			= false;
const bool 	shadowcolor0Mipmap 			= false;
const bool 	shadowcolor1Mipmap 			= false;


const int 	noiseTextureResolution 	= 64;

const float wetnessHalflife 		= 200.0; 	//[10.0 20.0 30.0 50.0 75.0 100.0 150.0 200.0 300.0 500.0]
const float drynessHalflife 		= 50.0; 	//[10.0 20.0 30.0 50.0 75.0 100.0 150.0 200.0 300.0 500.0]
const float eyeBrightnessHalflife 	= 10.0;

const float sunPathRotation 		= -30.0; 	// [-90.0 -89.0 -88.0 -87.0 -86.0 -85.0 -84.0 -83.0 -82.0 -81.0 -80.0 -79.0 -78.0 -77.0 -76.0 -75.0 -74.0 -73.0 -72.0 -71.0 -70.0 -69.0 -68.0 -67.0 -66.0 -65.0 -64.0 -63.0 -62.0 -61.0 -60.0 -59.0 -58.0 -57.0 -56.0 -55.0 -54.0 -53.0 -52.0 -51.0 -50.0 -49.0 -48.0 -47.0 -46.0 -45.0 -44.0 -43.0 -42.0 -41.0 -40.0 -39.0 -38.0 -37.0 -36.0 -35.0 -34.0 -33.0 -32.0 -31.0 -30.0 -29.0 -28.0 -27.0 -26.0 -25.0 -24.0 -23.0 -22.0 -21.0 -20.0 -19.0 -18.0 -17.0 -16.0 -15.0 -14.0 -13.0 -12.0 -11.0 -10.0 -9.0 -8.0 -7.0 -6.0 -5.0 -4.0 -3.0 -2.0 -1.0 0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0 33.0 34.0 35.0 36.0 37.0 38.0 39.0 40.0 41.0 42.0 43.0 44.0 45.0 46.0 47.0 48.0 49.0 50.0 51.0 52.0 53.0 54.0 55.0 56.0 57.0 58.0 59.0 60.0 61.0 62.0 63.0 64.0 65.0 66.0 67.0 68.0 69.0 70.0 71.0 72.0 73.0 74.0 75.0 76.0 77.0 78.0 79.0 80.0 81.0 82.0 83.0 84.0 85.0 86.0 87.0 88.0 89.0 90.0]

const float ambientOcclusionLevel 	= 0.0;
const int 	superSamplingLevel 		= 0;
*/


uniform sampler2D shadowtex0;


/* DRAWBUFFERS:17 */
layout(location = 0) out vec4 compositeOutput1;
layout(location = 1) out vec4 compositeOutput7;


ivec2 texelCoord = ivec2(gl_FragCoord.xy);
vec2 texCoord = gl_FragCoord.xy * pixelSize;

in vec3 colorTorchlight;


#include "/Lib/GbufferData.glsl"
#include "/Lib/Uniform/GbufferTransforms.glsl"

#include "/Lib/BasicFounctions/TemporalNoise.glsl"
#include "/Lib/BasicFounctions/Blocklight.glsl"
#include "/Lib/BasicFounctions/NetherColor.glsl"

#ifdef VOXEL_BLOCKLIGHT
	#include "/Lib/Voxel/VoxelTrace.glsl"
#endif

#include "/Lib/IndividualFounctions/GTAO.glsl"


////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////// Main //////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void main(){

	GbufferData gbuffer 			= GetGbufferData();
	MaterialMask materialMask 		= CalculateMasks(gbuffer.materialIDW);
	MaterialMask materialMaskSoild 	= CalculateMasks(gbuffer.materialIDL);

	FixParticleMask(materialMaskSoild, materialMask, gbuffer.depthL, gbuffer.depthW);


	vec3 viewPos 					= ViewPos_From_ScreenPos(texCoord, gbuffer.depthL);

	#ifdef DISTANT_HORIZONS
		if (gbuffer.depthL == 1.0){
			gbuffer.depthL 			= texelFetch(dhDepthTex1, texelCoord, 0).x;
			viewPos 				= ViewPos_From_ScreenPos_DH(texCoord, gbuffer.depthL);
		}
	#endif

	vec3 viewDir 					= normalize(viewPos);
	vec3 worldNormal 				= mat3(gbufferModelViewInverse) * gbuffer.normalL;


	vec3 finalComposite = vec3(0.0);

	#ifdef VOXEL_BLOCKLIGHT
		// Iris skips the entire shadow pass in dimensions where no program samples a
		// shadow texture — and our voxelization lives in the shadow pass. This read is
		// visually nil but keeps shadowtex0 active so the Nether gets voxelized.
		finalComposite += vec3(texelFetch(shadowtex0, ivec2(0), 0).r) * 1e-8;
	#endif

	if (materialMaskSoild.sky < 0.5){
		finalComposite += NetherLighting() * (worldNormal.y * 0.25 + 1.0);


		float gi = 1.0;
		#ifdef GTAO
			if (materialMaskSoild.hand + materialMask.particle < 0.5)
				gi = GroundTruthBasedAmbientOcclusion(viewPos, -viewDir, gbuffer.normalL);
		#endif

		#ifdef GTAO
			#ifdef GTAO_MULTIBOUNCE
				vec3 ao = GTAOMultiBounce(gi, gbuffer.albedo);
			#else
				vec3 ao = vec3(gi);
			#endif
		#else
			vec3 ao = vec3(1.0);
		#endif

		finalComposite *= ao;

		if(heldBlockLightValue + heldBlockLightValue2 > 0.0)
			finalComposite += HeldLighting(viewPos, viewDir, gbuffer.normalL, gbuffer.material.roughness, ao, materialMask.hand > 0.5);

		#ifdef VOXEL_BLOCKLIGHT
			vec3 vanillaBlockLight = BlockLighting(gbuffer.lightmapL.r, ao, materialMaskSoild);

			vec3 worldPos = mat3(gbufferModelViewInverse) * viewPos;
			float vxFade = VoxelEdgeFade(VoxelSpacePos(worldPos));
			vec3 blockLightTerm = vanillaBlockLight;
			vec3 voxelSpecularHighlight = vec3(0.0);

			#ifdef VOXEL_SKIP_UNLIT
				bool vxDoTrace = vxFade < 1.0 && gbuffer.lightmapL.r > 0.0;
			#else
				bool vxDoTrace = vxFade < 1.0;
			#endif

			if (vxDoTrace){
				#ifdef TAA
					vec2 bn = BlueNoiseTemproal();
				#else
					vec2 bn = BlueNoise();
				#endif
				vec3 vxNoise = vec3(bn, fract((bn.x + bn.y) * 1.6180339887));

				vec3 voxelSpecularRaw = vec3(0.0);
				vec3 voxelLight = VoxelBlockLighting(worldPos, worldNormal, vxNoise, normalize(worldPos),
				                                     gbuffer.material.roughness, gbuffer.material.f0, voxelSpecularRaw);

				float torchLum = dot(colorTorchlight, vec3(0.2126, 0.7152, 0.0722));
				float voxelScale = torchLum * (VOXELLIGHT_BRIGHTNESS * TORCHLIGHT_BRIGHTNESS * 0.15);

				vec3 voxelTerm = voxelLight * voxelScale;
				voxelTerm *= mix(ao, vec3(1.0), 0.4);
				voxelTerm += vanillaBlockLight * VOXEL_AMBIENT_MULT;

				blockLightTerm = mix(voxelTerm, vanillaBlockLight, vxFade);

				#ifdef VOXEL_SPECULAR
					voxelSpecularHighlight = voxelSpecularRaw * (voxelScale * VOXEL_SPECULAR_STRENGTH * (1.0 - vxFade));
				#endif
			}

			finalComposite += blockLightTerm;
		#else
			finalComposite += BlockLighting(gbuffer.lightmapL.r, ao, materialMaskSoild);
		#endif

		finalComposite *= mix(vec3(1.0), NetherFogColor().rgb, gbuffer.material.metalness * 0.7);
		finalComposite *= (1.0 - gbuffer.material.metalness * 0.75);
		
		finalComposite += TextureLighting(gbuffer.albedo, gbuffer.lightmapL.r, gbuffer.material.emissiveness, materialMaskSoild);

		finalComposite *= gbuffer.albedo;

		#if defined VOXEL_BLOCKLIGHT && defined VOXEL_SPECULAR
			finalComposite += voxelSpecularHighlight * mix(vec3(1.0), gbuffer.albedo, vec3(gbuffer.material.metalness));
		#endif

	}else{
		finalComposite = vec3(0.0);
	}

	finalComposite /= MAIN_OUTPUT_FACTOR;
	finalComposite = LinearToCurve(finalComposite);

	compositeOutput1 = vec4(finalComposite, 0.0);
}
