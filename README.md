# How to MUKBANG

**First public prerelease target: `0.2.0-beta.2`** — Android APK, food-specific eating sounds, walk-in street shops, and the expanded rainy-night mall.

A mobile 3D mukbang game prototype made with Godot 4.

## Current milestone: shopping mall food court
- Expanded 120 × 110 m shopping mall shell with central atrium, skylight and upper gallery
- Walkable neon-lit street outside the entrance, with sidewalks, real walk-in shop entrances, collision-free doorways, glass storefronts, stocked shelves, counters, glowing signs, street lamps, trees and reflective puddles
- Rainy night weather with dense exterior rain, cool night ambience and warm/cyan street lighting
- **Faster mobile startup:** runtime PBR maps use compact 512×512 PNGs while 4K SVG sources remain in the project; procedural noise generation is smaller, rain is capped at 500 particles, and expensive SSAO/SSR and omni-light shadows are disabled.
- Imported glTF Binary (GLB) assets for a layered burger combo, cafe chair and self-service order kiosk
- GLB assets contain PBR base-colour, metallic/roughness and normal texture channels
- Separate 128×128 PNG texture maps are available under `assets/textures/`
- Eight food counters, menu boards, food displays and order kiosks
- Interactive self-service food ordering at kiosks: crispy/spicy chicken, wings, nuggets, sushi rolls, burgers, fries, pizza, noodles, drinks and desserts
- Working shopping flow with a cart, item quantities, prices, a 5,000 ₽ starting balance, checkout and order-ready notification; press **E** near a kiosk (or tap **ЗАКАЗАТЬ** on mobile)
- Ordered food appears on the nearest dining table after a short preparation delay, with pop-in serving animations and distinct procedural 3D food for chicken, sushi rolls, burgers, fries, pizza, drinks and desserts
- Eating animation: press **F** or tap **ЕСТЬ**; each portion lifts, tilts and disappears, with a floating feedback label and a simple fullness percentage
- Food-specific procedural bite audio: crisp crackling crunches for fried chicken and fries, layered crunch and low bite impacts for burgers and pizza, softer moist sounds for sushi and desserts, slurping for noodles and drinks, plus fizzy hiss for cola and lemonade. Audio is synthesized locally by Godot at runtime, so no external sound files or network access are needed.
- Interactive street-shop doors swing open and closed with a smooth hinge animation; aim at a nearby door and press **E** or tap the Android interaction button
- Atrium benches are interactive: approach and face a seat to see a contextual prompt, then press **E** or tap the action button for a spring/bounce animation and a rest message
- Street neon signs animate when switched on/off with a quick scale-in/scale-out transition; world interactions use the same proximity prompt on desktop and Android
- Street neon signs can be switched on/off from nearby; contextual prompts and feedback messages work on desktop and touch screens
- **18 animated NPC visitors** wander the atrium and food-court aisles; six additional visitors approach street shops, enter through the storefront doorway, browse briefly and return to the sidewalk. Their lightweight low-poly models use simple walk cycles and no physics bodies to keep mobile performance reasonable.
- Interactive drink vending machines in street shops dispense a visible can with a springy pop-out animation
- Street bins open and close with a hinged lid animation; existing atrium benches react with a quick bounce
- Interaction feedback animates smoothly alongside the existing door and neon transitions
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
The **Build How to MUKBANG Android** workflow imports assets, validates the 4K PBR maps, exports the Android APK, and uploads a downloadable Actions artifact. On the first successful push to `main`, it also creates the GitHub prerelease `v0.2.0-beta.2` with the APK attached. Subsequent pushes do not overwrite the published release. The build is a beta and should be tested on a real Android device before treating it as stable.
