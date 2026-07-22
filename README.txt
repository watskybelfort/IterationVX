IterationVX 2.1 — IterationT 3.2.0 + luz de bloques voxel ray-traced
====================================================================

Base: IterationT 3.2.0 (edicion de Chocapic13, por Tahnass)
Sistema voxel: concepto portado de Rethinking Voxels (por gri573)

QUE HACE
- Las antorchas y demas bloques luminosos emiten luz COLOREADA por bloque
  (glowstone amarillo, sea lantern azulada, fuego de alma turquesa, etc.;
  el color se detecta automaticamente de la textura si no esta definido).
- La luz proyecta sombras trazadas por rayos contra los bloques del mundo
  (raytracing por voxeles, volumen 128x96x128 alrededor de la camara).
- Reflejos especulares ray-traced de las luces (VOXEL_SPECULAR).
- La luz se TINTA al atravesar cristales tintados, agua y hielo
  (VOXEL_GLASS_TINT).
- El apagado de cada luz sigue el perfil vanilla de IterationT (modelo de
  modulacion normalizada): sin anillos ni cortes visibles de alcance.
- Fuera del volumen voxel se funde suavemente con la iluminacion vanilla.
- Compatible con Distant Horizons.

REQUISITOS
- IRIS obligatorio (1.6.1 o superior). NO funciona con OptiFine
  (usa compute shaders, imagenes 3D y SSBOs).
- El NETHER y el END mantienen la iluminacion original de IterationT.

OPCIONES (Shader Pack Settings > LIGHTING > VOXEL_LIGHT)
- VOXEL_BLOCKLIGHT: activar/desactivar todo el sistema.
- VOXELLIGHT_BRIGHTNESS: facilidad con la que se alcanza el brillo pleno.
- VOXEL_DETAIL: 1 = oclusion por bloque (hermetica, RECOMENDADA).
  2-4 = detalle sub-bloque EXPERIMENTAL (puede fugar luz).
- VOXEL_GLASS_TINT: tinte a traves de cristales/agua/hielo.
- VOXEL_SPECULAR + VOXEL_SPECULAR_STRENGTH: reflejos de las luces.
- VOXEL_LIGHT_SIZE: tamano de la fuente (penumbra suave, se acumula con TAA).
- VOXEL_MAX_TRACES: rayos maximos por pixel (rendimiento).
- VOXEL_AMBIENT_MULT: luz vanilla conservada como rebote ambiental.
- VOXEL_RANGE_MULT: alcance de las luces.
- VOXEL_COLOR_SATURATION: saturacion del color detectado de la textura.
- VOXEL_SKIP_UNLIT: no trazar pixeles sin luz vanilla (gran ahorro).
- VOXEL_LIGHT_THINNING: muestreo reducido en lagos de lava.
- NETHER_LAVA_GLOW: atenua el bloom de la lava del Nether.
- VOXEL_DEBUG: pinta el factor trazado crudo (diagnostico).

NOVEDADES 2.1
- ARREGLADO el error de "iluminacion por cubos" con slabs y lamparas:
  los bloques parciales (slabs, escaleras, alfombras, puertas, nieve)
  ya solo bloquean la luz en la mitad que ocupan de verdad (oclusion
  analitica de medio bloque, derivada de la geometria real del bloque).
  Los cubos completos se comportan exactamente igual que antes.
- ARREGLADO el parpadeo/inestabilidad en escenas con muchas luces:
  las listas de luces ahora son deterministas (se conservan siempre
  las 64 mas cercanas) y cada pixel traza siempre su luz dominante.
- ARREGLADAS las sombras que cambiaban al moverse: la reticula voxel
  ahora esta anclada al mundo (no al jugador), asi que la iluminacion
  se queda perfectamente quieta mientras caminas.
- Bonus de rendimiento: menos lecturas de memoria por pixel.

Si el shader no compila, en Iris pulsa la tecla de log o revisa
logs/latest.log y comparte los errores para poder corregirlos.
