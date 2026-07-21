IterationVX — IterationT 3.2.0 + luz de bloques voxel ray-traced
=================================================================

Base: IterationT 3.2.0 (edicion de Chocapic13, por Tahnass)
Sistema voxel: concepto portado de Rethinking Voxels (por gri573)

QUE HACE
- Las antorchas y demas bloques luminosos emiten luz COLOREADA por bloque
  (glowstone amarillo, sea lantern azulada, fuego de alma turquesa, etc.)
- La luz proyecta sombras trazadas por rayos contra los bloques del mundo
  (raytracing por voxeles, como Rethinking Voxels).
- Fuera del volumen voxel (128x96x128 alrededor de la camara) se funde
  suavemente con la iluminacion vanilla de IterationT.

REQUISITOS
- IRIS obligatorio (1.6.1 o superior). NO funciona con OptiFine
  (usa compute shaders, imagenes 3D y SSBOs).
- Solo el mundo normal (overworld) usa la luz voxel; Nether y End
  mantienen la iluminacion original de IterationT.

OPCIONES (Video Settings > Shader Packs > Shader Pack Settings > LIGHTING > VOXEL_LIGHT)
- VOXEL_BLOCKLIGHT: activar/desactivar todo el sistema.
- VOXELLIGHT_BRIGHTNESS: intensidad de la luz voxel.
- VOXEL_LIGHT_SIZE: tamano de la fuente (penumbra suave, se acumula con TAA).
- VOXEL_MAX_TRACES: rayos maximos por pixel (rendimiento).
- VOXEL_AMBIENT_MULT: cuanto de la luz vanilla se mantiene como "rebote" ambiental.
- VOXEL_RANGE_MULT: alcance de las luces.
- VOXEL_COLOR_SATURATION: saturacion del color detectado de la textura.

Si el shader no compila, en Iris pulsa la tecla de log o revisa
logs/latest.log y comparte los errores para poder corregirlos.
