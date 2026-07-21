IterationVX — IterationT 3.2.0 + luz de bloques voxel ray-traced
=================================================================

Base: IterationT 3.2.0 (edicion de Chocapic13, por Tahnass)
Sistema voxel: concepto portado de Rethinking Voxels (por gri573)

QUE HACE
- Las antorchas y demas bloques luminosos emiten luz COLOREADA por bloque
  (glowstone amarillo, sea lantern azulada, fuego de alma turquesa, etc.)
- La luz proyecta sombras trazadas por rayos contra los bloques del mundo
  (raytracing por voxeles, como Rethinking Voxels).
- v1.1: detalle SUB-BLOQUE cerca de la camara (escaleras, losas, vallas y
  hojas proyectan sombras finas; la luz pasa por los huecos).
- v1.1: la luz se TINTA al atravesar cristales tintados, agua y hielo
  (VOXEL_GLASS_TINT).
- v1.1: NETHER soportado (lava, glowstone, shroomlights, fuego de alma...).
- Fuera del volumen voxel (128x96x128 alrededor de la camara) se funde
  suavemente con la iluminacion vanilla de IterationT.

REQUISITOS
- IRIS obligatorio (1.6.1 o superior). NO funciona con OptiFine
  (usa compute shaders, imagenes 3D y SSBOs).
- El End mantiene la iluminacion original de IterationT.

v1.2
- ARREGLADO: fugas de luz a traves de bloques (el detalle sub-bloque de v1.1
  asumia datos finos que a veces no existian; ahora cada bloque registra que
  niveles finos tiene realmente y si no tiene ninguno se trata como macizo).
  Esto tambien recupera FPS: los rayos que se fugaban eran ademas rayos lentos.
- NUEVO: reflejos especulares ray-traced de las luces de bloque
  (VOXEL_SPECULAR + VOXEL_SPECULAR_STRENGTH): las antorchas, la lava, etc.
  se reflejan en superficies pulidas con su color y su sombra correcta.
- La optimizacion de saltar pixeles sin luz vanilla ahora es un toggle
  (VOXEL_SKIP_UNLIT, activada por defecto; no causa las fugas — puedes
  desactivarla para comparar, solo cuesta FPS).

NOTAS v1.1
- VOXEL_DETAIL (1-4): niveles de detalle sub-bloque. 3 por defecto
  (1/4 de bloque cerca de la camara). 4 = 1/8, mas costoso.
- Optimizacion: los pixeles sin luz de bloque vanilla no trazan rayos
  (coste casi cero en exteriores de dia).
- En el Nether el shadow pass ahora renderiza ~67 bloques alrededor de la
  camara para voxelizar (antes estaba desactivado); es el coste del efecto.

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
