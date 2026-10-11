# How to MUKBANG

A mobile 3D mukbang game prototype made with Godot 4.

## Current milestone: shopping mall food court
- Large shopping mall shell with central atrium, skylight and upper gallery
- Imported glTF Binary (GLB) assets for a layered burger combo, cafe chair and self-service order kiosk
- GLB assets contain PBR base-colour, metallic/roughness and normal texture channels
- Separate 128×128 PNG texture maps are available under `assets/textures/`
- Eight food counters, menu boards, food displays and order kiosks
- Procedural furniture, floor tile seams, architectural trim and real-time lighting

## Asset files
- `assets/models/burger_combo.glb`
- `assets/models/cafe_chair.glb`
- `assets/models/order_kiosk.glb`
- `assets/textures/porcelain_basecolor.png`
- `assets/textures/porcelain_roughness.png`
- `assets/textures/porcelain_normal.png`

The GLB files are importable Godot 4 scene resources with embedded PBR maps. They are original procedural game assets made for this prototype, not scanned commercial assets. They establish the import pipeline; a future art pass can replace them with higher-resolution authored or licensed assets.

## Android build
Open **Actions → Build How to MUKBANG Android**, wait for the workflow to finish, then download the **How-to-MUKBANG-Android** artifact. The workflow imports assets with Godot before exporting the APK.
