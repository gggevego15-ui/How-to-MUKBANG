# How to MUKBANG

A mobile 3D mukbang game prototype made with Godot 4.

## Current milestone: shopping mall food court
- Large shopping mall shell with central atrium, skylight and upper gallery
- Imported glTF Binary (GLB) assets for a layered burger combo, cafe chair and self-service order kiosk
- GLB assets contain PBR base-colour, metallic/roughness and normal texture channels
- Separate 128×128 PNG texture maps are available under `assets/textures/`
- Eight food counters, menu boards, food displays and order kiosks
- Procedural furniture, floor tile seams, architectural trim and real-time lighting

## PBR texture library (2K, Android-conscious)

Dedicated reusable texture sets live in `assets/textures/pbr/`. Each material has four 2048×2048 SVG source maps (rasterized by Godot during import):
- `food_*`: fine food-surface variation; neutral base colour keeps per-ingredient colours in the game
- `wood_*`: directional wood grain
- `ceramic_*`: glazed ceramic with lower roughness
- `metal_*`: brushed metal with a metallic map

For each family, `basecolor_2k.svg`, `roughness_2k.svg`, `normal_2k.svg`, and `metallic_2k.svg` are used by `StandardMaterial3D` in `scripts/mall.gd`. The material filter requests anisotropic mipmapped sampling. SVG sources keep the Git repository small; Godot rasterizes them and caches imported textures. Mapped materials include burger ingredients, fries, cups, wood table surfaces, ceramic dishes, metal trims and chrome parts. These are procedural vector-authored texture maps, not scans or commercially authored texture packs. The maps are tiled and intentionally subtle to keep the Android texture budget manageable.

Imported GLB props remain at:
- `assets/models/burger_combo.glb`
- `assets/models/cafe_chair.glb`
- `assets/models/order_kiosk.glb`

## Android build
Open **Actions → Build How to MUKBANG Android**, wait for the workflow to finish, then download the **How-to-MUKBANG-Android** artifact. The workflow imports assets with Godot before exporting the APK.
