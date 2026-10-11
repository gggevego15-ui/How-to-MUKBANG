# How to MUKBANG

A mobile 3D mukbang game prototype made with Godot 4.

## Current milestone: shopping mall food court
- Large shopping mall shell with a central atrium, skylight and upper gallery
- Cafe-style tables and individual chairs with metal legs and upholstered backs
- Eight food counters with cabinet fronts, handles, metal worktops and glass display guards
- Individual procedural food props: layered burgers with sesame seeds, fries, pizza toppings, noodle bowls, fried chicken, donuts, tacos and drinks with lids and straws
- Self-service kiosks with bezels, screens and interface details
- Procedural surface materials, floor tile seams, architectural trim and upgraded real-time lighting

## Visuals and current limitations
Food and furniture props are generated from procedural 3D meshes in GDScript. They are more detailed than simple colored placeholder blocks, but they are not scanned or professionally sculpted assets, and the procedural material textures are not a replacement for authored 4K PBR texture sets. The next art pass can replace these props with optimized GLB models and dedicated albedo/normal/roughness maps.

## Android build
Open **Actions → Build How to MUKBANG Android**, wait for the workflow to finish, then download the **How-to-MUKBANG-Android** artifact. You can also start a run manually with **Run workflow**.
