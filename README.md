# How to MUKBANG

A mobile 3D mukbang game prototype made with Godot 4.

## Current milestone: shopping mall food court
- Expanded 120 × 110 m shopping mall shell with central atrium, skylight and upper gallery
- Walkable neon-lit street outside the entrance, with sidewalks, furnished shop interiors visible through display glass, counters, shelves, glowing signs, street lamps, trees and reflective puddles
- Rainy night weather with dense exterior rain, cool night ambience and warm/cyan street lighting
- Imported glTF Binary (GLB) assets for a layered burger combo, cafe chair and self-service order kiosk
- GLB assets contain PBR base-colour, metallic/roughness and normal texture channels
- Separate 128×128 PNG texture maps are available under `assets/textures/`
- Eight food counters, menu boards, food displays and order kiosks
- Interactive self-service food ordering at kiosks: crispy/spicy chicken, wings, nuggets, sushi rolls, burgers, fries, pizza, noodles, drinks and desserts
- Working shopping flow with a cart, item quantities, prices, a 5,000 ₽ starting balance, checkout and order-ready notification; press **E** near a kiosk (or tap **ЗАКАЗАТЬ** on mobile)
- Procedural furniture, floor tile seams, architectural trim and real-time lighting

## PBR texture library (4K source maps, Android-conscious)

Dedicated reusable texture sets live in `assets/textures/pbr/`. Each material has four 4096×4096 SVG source maps (rasterized by Godot during import):
- `food_*`: fine food-surface variation; neutral base colour keeps per-ingredient colours in the game
- `wood_*`: directional wood grain
- `ceramic_*`: glazed ceramic with lower roughness
- `metal_*`: brushed metal with a metallic map

For each family, `basecolor_4k.svg`, `roughness_4k.svg`, `normal_4k.svg`, and `metallic_4k.svg` are used by `StandardMaterial3D` in `scripts/mall.gd`. The material filter requests anisotropic mipmapped sampling. SVG sources keep the Git repository small; Godot rasterizes them and caches imported textures. Mapped materials include burger ingredients, fries, cups, wood table surfaces, ceramic dishes, metal trims and chrome parts. These are procedural vector-authored texture maps, not scans or commercially authored texture packs. The SVG source maps are 4096×4096 and remain compact in Git; Godot rasterizes and compresses them during import. 4K textures increase GPU memory use on mobile devices.

Imported GLB props remain at:
- `assets/models/burger_combo.glb`
- `assets/models/cafe_chair.glb`
- `assets/models/order_kiosk.glb`

## Android PBR import settings

The 16 `.import` sidecars under `assets/textures/pbr/` enable mipmap generation and VRAM compression (`compress/mode=2`). Normal maps use the normal-map compression flag. Project rendering settings enable Android ETC2/ASTC texture import and moderate 4× anisotropic filtering. `scripts/validate_pbr.gd` checks that all 16 textures load at 4096×4096 and that their import settings keep mipmaps and compression enabled.

## First-person controls

## Mobile controls

On Android/iOS, a virtual joystick appears in the lower-left corner: drag it to walk and strafe. The **JUMP** button at the lower-right makes the player jump, and hold **RUN** to sprint. Drag on the right side of the screen outside the action buttons to look around; vertical swipes tilt the camera. Touch controls are generated at runtime and are hidden on desktop, where WASD, Space, Shift and mouse controls remain active.


- **WASD** — walk around the food court
- **Mouse** — look around horizontally and vertically
- **Shift** — sprint
- **Space** — jump
- **Esc** — release the mouse; click the game window to capture it again

The first-person camera includes visible legs and shoes when looking down. A lightweight directional screen-space blur briefly appears during fast mouse turns and fades smoothly. The controller is in `scripts/player_controller.gd`.

## Android build
Open **Actions → Build How to MUKBANG Android**, wait for the workflow to finish, then download the **How-to-MUKBANG-Android** artifact. The workflow imports assets with Godot before exporting the APK.
