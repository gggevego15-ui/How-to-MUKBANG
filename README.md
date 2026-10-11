# How to MUKBANG

A mobile 3D mukbang game prototype made with Godot 4.

## Current milestone: shopping mall food court
- Large shopping mall shell with central atrium, skylight and upper gallery
- Imported glTF Binary (GLB) assets for a layered burger combo, cafe chair and self-service order kiosk
- GLB assets contain PBR base-colour, metallic/roughness and normal texture channels
- Separate 128×128 PNG texture maps are available under `assets/textures/`
- Eight food counters, menu boards, food displays and order kiosks
- Procedural furniture, floor tile seams, architectural trim and real-time lighting

## PBR texture library (512×512)

Dedicated reusable texture sets live in `assets/textures/pbr/`. Each material has four PNG maps:
- `food_*`: fine food-surface variation; neutral base colour keeps per-ingredient colours in the game
- `wood_*`: directional wood grain
- `ceramic_*`: glazed ceramic with lower roughness
- `metal_*`: brushed metal with a metallic map

For each family, `basecolor_512.png`, `roughness_512.png`, `normal_512.png`, and `metallic_512.png` are used by the Godot `StandardMaterial3D` resources in `scripts/mall.gd`. Mapped materials include burger ingredients, fries, cups, wood table surfaces, ceramic dishes, metal trims and chrome parts. These are procedural 512×512 game textures, not scans or commercially authored texture packs.

Imported GLB props remain at:
- `assets/models/burger_combo.glb`
- `assets/models/cafe_chair.glb`
- `assets/models/order_kiosk.glb`

## Android build
Open **Actions → Build How to MUKBANG Android**, wait for the workflow to finish, then download the **How-to-MUKBANG-Android** artifact. The workflow imports assets with Godot before exporting the APK.
