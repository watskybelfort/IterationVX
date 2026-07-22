# IterationVX

🌐 **English** · [Español](README.es.md)

**IterationT 3.2.0 + ray-traced voxel block lighting**, in the style of *Rethinking Voxels*, for Minecraft with **Iris**.

IterationVX takes the IterationT shader pack (a Chocapic13 edit by Tahnass) and grafts a completely new block lighting system onto it: the world is voxelized in real time and every pixel traces rays toward nearby light sources.

---

## ✨ Features

- **Colored light per block** — every source emits its own color: yellow glowstone, bluish sea lanterns, turquoise soul fire, violet amethyst, froglights, candles, lava… The color is detected automatically from the texture when it isn't defined by hand.
- **Ray-traced shadows** — torches and lamps cast crisp shadows against the blocks of the world, traced against the voxel volume (128×96×128 around the camera).
- **Ray-traced specular reflections** — lights reflect off polished surfaces with their own color, and the reflection respects shadows.
- **Tint through translucents** — light passing through stained glass gets tinted by its color; underwater, light turns bluish.
- **No range artifacts** — each light's falloff follows exactly the vanilla lighting profile of IterationT (normalized modulation model), so there are no visible rings or cutoffs.
- **Optimized** — pixels with no block light trace nothing (near-zero cost outdoors), per-cell light lists with deterministic ordering, and mathematically invisible shortcuts in scenes with many lights.
- **Distant Horizons compatible** — far LOD terrain renders perfectly with the voxel system active (IterationT's DH support intact, including the optional DH shadows).
- Everything else from IterationT untouched: sky, volumetric clouds, water, TAA, bloom, GI…

## 📸 Screenshots

Comparisons in the same scenes: **IterationT 3.2.0 (before)** vs **IterationVX (after)**.

**1 — Torch in a cave: crisp ray-traced shadows and warm light bouncing off the stone**

| Before | After |
|---|---|
| ![Cave before](docs/screenshots/01-before.jpg) | ![Cave after](docs/screenshots/01-after.jpg) |

**2 — Red light: the emitter's color floods the hallway and the wall truly blocks the light**

| Before | After |
|---|---|
| ![Red light before](docs/screenshots/02-before.jpg) | ![Red light after](docs/screenshots/02-after.jpg) |

**3 — Alternating colored sources: every light casts its own color and its own shadows**

| Before | After |
|---|---|
| ![Colors before](docs/screenshots/03-before.jpg) | ![Colors after](docs/screenshots/03-after.jpg) |

**4 — Cold light through an opening: long, defined shadows across the floor**

| Before | After |
|---|---|
| ![Cold light before](docs/screenshots/04-before.jpg) | ![Cold light after](docs/screenshots/04-after.jpg) |

**5 — Blue light: the color is detected automatically and tints the whole room**

| Before | After |
|---|---|
| ![Blue light before](docs/screenshots/05-before.jpg) | ![Blue light after](docs/screenshots/05-after.jpg) |

### 🌌 The End

IterationT's End sky, untouched in IterationVX:

| | |
|---|---|
| ![End 1](docs/screenshots/end-1.jpg) | ![End 2](docs/screenshots/end-2.jpg) |

### 🗺️ Distant Horizons

Fully compatible: Distant Horizons LOD terrain blends seamlessly with real terrain, with the voxel lighting system running at the same time.

![Distant Horizons view](docs/screenshots/distant-horizons.jpg)

## 📋 Requirements

| | |
|---|---|
| **Shader loader** | [Iris](https://irisshaders.dev/) 1.6.1 or newer — **OptiFine is NOT supported** (the system uses compute shaders, 3D images and SSBOs) |
| **Minecraft** | The same versions IterationT 3.2.0 supports (1.13+, 1.18+ recommended) |
| **GPU** | Anything with OpenGL 4.3 (modern NVIDIA / AMD / Intel) |
| **Distant Horizons** | ✅ Compatible (tested with the voxel system active) |

## 📥 Installation

1. Download the `.zip` from the [latest release](../../releases/latest).
2. Copy it into your Minecraft instance's `shaderpacks` folder (don't unzip it).
3. In game: **Video Settings → Shader Packs → IterationVX** and apply.

## ⚙️ Settings

Menu: **Shader Pack Settings → LIGHTING → VOXEL_LIGHT**

| Option | Description |
|---|---|
| `VOXEL_BLOCKLIGHT` | Master toggle for the voxel system |
| `VOXELLIGHT_BRIGHTNESS` | How easily traced light reaches full brightness |
| `VOXEL_DETAIL` | `1` = per-block occlusion (airtight, recommended). `2–4` = **experimental** sub-block detail (stairs/slabs), may leak light in some scenes |
| `VOXEL_GLASS_TINT` | Tints light passing through stained glass / water / ice |
| `VOXEL_SPECULAR` + `VOXEL_SPECULAR_STRENGTH` | Specular reflections of block lights |
| `VOXEL_LIGHT_SIZE` | Source size (soft penumbra, accumulates with TAA) |
| `VOXEL_MAX_TRACES` | Maximum rays per pixel (performance) |
| `VOXEL_AMBIENT_MULT` | Vanilla light kept as ambient bounce in shadowed areas |
| `VOXEL_SKIP_UNLIT` | Skip tracing on pixels with zero vanilla block light (big speedup, no visual cost) |
| `VOXEL_LIGHT_THINNING` | Reduced sampling in dense emitter fields (lava lakes) |
| `NETHER_LAVA_GLOW` | Tames the glow/bloom of lava in the Nether |
| `VOXEL_DEBUG` | Visualizes the raw traced factor (diagnostics) |

## ⚠️ Status and limitations

- The **Nether** uses IterationT's original lighting (voxelization needs the shadow pass, which Iris doesn't run reliably there). Includes the `NETHER_LAVA_GLOW` control.
- The **End** uses IterationT's original lighting.
- `VOXEL_DETAIL` ≥ 2 (sub-block shadows) is experimental.

### 🐞 Known issues

- None at the moment. 🎉
- ~~**Slabs + lamps**: lighting was generated "in cubes" next to partial blocks~~ — **fixed in v2.1** (analytic half-block occlusion).
- ~~**Many lights**: flickering patches in dense lamp scenes~~ — **fixed in v2.1** (deterministic light lists).
- ~~**Shadows shifting while moving** in dense scenes~~ — **fixed in v2.1** (world-anchored voxel grid).

## 🗒️ Version history

| Version | Changes |
|---|---|
| **v2.1** | Partial blocks (slabs, stairs, carpets, doors…) only block light in the half they actually occupy (analytic octant occlusion — goodbye "cube lighting"); stable scenes with many lights (deterministic light lists + every pixel always traces its dominant light); world-anchored voxel grid (shadows no longer shift as you walk); fewer memory reads per pixel |
| **v2.0** | The shader identifies itself as **IterationVX 2.0** in game (animated loading title and options menu); screenshot gallery and Distant Horizons compatibility documented |
| v1.9 | Airtight occlusion by default (`VOXEL_DETAIL=1`); sub-block detail becomes experimental |
| v1.8 | Single-axis DDA (anti corner-tunneling), damped noise, full-cube lamps occlude |
| v1.7 | Revert of Nether Iris directives; `NETHER_LAVA_GLOW` |
| v1.6 | FPS optimizations (water, many lights, lava) + `VOXEL_DEBUG` |
| v1.5 | Normalized modulation model — removes the range ring |
| v1.4 | Vanilla lightmap envelope |
| v1.3 | Smooth Frostbite-style falloff |
| v1.2 | Leak fix (presence bits) + ray-traced specular reflections |
| v1.1 | Sub-block detail, glass/water tint, Nether support |
| **v1.0** | Base: IterationT 3.2.0 + complete ray-traced voxel lighting system |

## 💖 Donations

If you like IterationVX and want to support its development, you can make a donation — every bit is hugely appreciated and goes straight to PayPal:

[![Donate](docs/screenshots/donation.jpg)](https://botrix.live/k/lxrdbit/tip)

**➡️ [botrix.live/k/lxrdbit/tip](https://botrix.live/k/lxrdbit/tip)**

## 🙏 Credits

- **[IterationT](https://www.curseforge.com/minecraft/shaders/iterationt)** by *Tahnass* — the base shader pack (a Chocapic13 edit).
- **[Rethinking Voxels](https://modrinth.com/shader/rethinking-voxels)** by *gri573* — the inspiration and technical reference for the voxel lighting system.
- IterationVX's voxel system developed with Claude (Anthropic).

Private project for personal use. The original packs keep their respective licenses.
