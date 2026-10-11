extends Node3D
## Procedural first milestone map for How to MUKBANG.
## Coordinates are in metres. The central atrium connects four food-court wings.

const MALL_WIDTH := 100.0
const MALL_DEPTH := 86.0
const WALL_HEIGHT := 10.0

var mats: Dictionary = {}

func _ready() -> void:
	_make_materials()
	_build_mall_shell()
	_build_surface_detail()
	_build_atrium()
	_build_food_court()
	_build_vendor_row()
	_build_upper_gallery()
	_build_decor()
	_build_lighting()
	_build_player_camera()

func _material(key: String, color: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.55, 0.55, 0.55)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.1
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for py in range(256):
		for px in range(256):
			var n := noise.get_noise_2d(float(px), float(py))
			var v := clampf(0.92 + n * 0.075, 0.82, 1.0)
			image.set_pixel(px, py, Color(v, v, v, 1.0))
	m.albedo_texture = ImageTexture.create_from_image(image)
	mats[key] = m
	return m

func _make_materials() -> void:
	_material("floor", Color("c7cbd0"), 0.26)
	_material("tile_dark", Color("68717d"), 0.32)
	_material("wall", Color("e8e5df"), 0.82)
	_material("concrete", Color("a7adb5"), 0.86)
	_material("wood", Color("87563b"), 0.38)
	_material("wood_light", Color("c29161"), 0.42)
	_material("metal", Color("424b57"), 0.28, 0.55)
	_material("glass", Color(0.48, 0.78, 0.88, 0.32), 0.12, 0.1)
	_material("seat_red", Color("a94443"), 0.5)
	_material("seat_blue", Color("326b7a"), 0.5)
	_material("seat_green", Color("55745d"), 0.5)
	_material("sign_orange", Color("ff9b42"), 0.28, 0.1)
	_material("sign_pink", Color("ff5ca8"), 0.28, 0.1)
	_material("sign_blue", Color("55b9ff"), 0.28, 0.1)
	_material("black", Color("202631"), 0.32)
	_material("plant", Color("42734b"), 0.9)
	_material("soil", Color("574638"), 0.9)
	_material("white", Color("f4f3ed"), 0.4)

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, material_key: String, solid: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.position = pos
	visual.material_override = mats[material_key]
	parent.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		body.name = label + "_Body"
		body.position = pos
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		parent.add_child(body)
	return visual

func _cylinder(parent: Node3D, label: String, pos: Vector3, radius: float, height: float, material_key: String, solid: bool = true) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.position = pos
	visual.material_override = mats[material_key]
	parent.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		body.add_child(shape_node)
		parent.add_child(body)

func _build_mall_shell() -> void:
	_box(self, "GroundFloor", Vector3(0, -0.25, 0), Vector3(MALL_WIDTH, 0.5, MALL_DEPTH), "floor")
	_box(self, "NorthOuterWall", Vector3(0, WALL_HEIGHT / 2.0, -MALL_DEPTH / 2.0), Vector3(MALL_WIDTH, WALL_HEIGHT, 0.7), "wall")
	_box(self, "SouthOuterWallLeft", Vector3(-31, WALL_HEIGHT / 2.0, MALL_DEPTH / 2.0), Vector3(38, WALL_HEIGHT, 0.7), "wall")
	_box(self, "SouthOuterWallRight", Vector3(31, WALL_HEIGHT / 2.0, MALL_DEPTH / 2.0), Vector3(38, WALL_HEIGHT, 0.7), "wall")
	_box(self, "WestOuterWall", Vector3(-MALL_WIDTH / 2.0, WALL_HEIGHT / 2.0, 0), Vector3(0.7, WALL_HEIGHT, MALL_DEPTH), "wall")
	_box(self, "EastOuterWall", Vector3(MALL_WIDTH / 2.0, WALL_HEIGHT / 2.0, 0), Vector3(0.7, WALL_HEIGHT, MALL_DEPTH), "wall")
	# Tall open atrium roof, with a bright central skylight.
	_box(self, "Roof", Vector3(0, 10.4, 0), Vector3(MALL_WIDTH, 0.5, MALL_DEPTH), "concrete", false)
	_box(self, "SkylightGlass", Vector3(0, 10.1, 0), Vector3(34, 0.12, 28), "glass", false)
	for x in [-46.0, -24.0, 24.0, 46.0]:
		for z in [-38.0, 0.0, 38.0]:
			_box(self, "StructuralPillar_%s_%s" % [str(x), str(z)], Vector3(x, 4.8, z), Vector3(1.0, 9.6, 1.0), "concrete")


func _build_surface_detail() -> void:
	# Fine porcelain tile seams, realistic architectural trim and ceiling rails.
	for x in range(-48, 49, 4):
		_box(self, "FloorGroutX_%d" % x, Vector3(float(x), 0.012, 0), Vector3(0.018, 0.012, MALL_DEPTH - 2.0), "concrete", false)
	for z in range(-41, 42, 4):
		_box(self, "FloorGroutZ_%d" % z, Vector3(0, 0.013, float(z)), Vector3(MALL_WIDTH - 2.0, 0.012, 0.018), "concrete", false)
	for x in range(-40, 41, 8):
		_box(self, "CeilingBeamX_%d" % x, Vector3(float(x), 9.65, 0), Vector3(0.22, 0.28, MALL_DEPTH - 4.0), "metal", false)
	for z in range(-32, 33, 8):
		_box(self, "CeilingBeamZ_%d" % z, Vector3(0, 9.65, float(z)), Vector3(MALL_WIDTH - 4.0, 0.28, 0.22), "metal", false)
	# Brushed-metal trims break up large flat wall surfaces.
	for y in [0.35, 3.2, 6.2, 9.1]:
		_box(self, "NorthWallTrim_%s" % str(y), Vector3(0, y, -42.9), Vector3(MALL_WIDTH - 1.5, 0.09, 0.12), "metal", false)
		_box(self, "WestWallTrim_%s" % str(y), Vector3(-49.55, y, 0), Vector3(0.12, 0.09, MALL_DEPTH - 1.5), "metal", false)
		_box(self, "EastWallTrim_%s" % str(y), Vector3(49.55, y, 0), Vector3(0.12, 0.09, MALL_DEPTH - 1.5), "metal", false)
	# Vertical mullions give the upper shopfront glazing believable scale.
	for side in [-1.0, 1.0]:
		for z in range(-27, 29, 4):
			_box(self, "ShopfrontMullion_%s_%d" % [str(side), z], Vector3(side * 48.55, 6.6, float(z)), Vector3(0.16, 2.5, 0.12), "metal", false)
		for z in [-28.0, -14.0, 14.0, 28.0]:
			_box(self, "GalleryDownlight_%s_%s" % [str(side), str(z)], Vector3(side * 39.0, 5.0, z), Vector3(2.0, 0.06, 0.35), "white", false)

func _build_atrium() -> void:
	# Wide central promenade, patterned floor inlays, and decorative planters.
	_box(self, "AtriumInlay", Vector3(0, 0.015, 0), Vector3(31, 0.035, 42), "tile_dark", false)
	_box(self, "AtriumWalkway", Vector3(0, 0.04, 0), Vector3(27, 0.04, 39), "floor", false)
	for z in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		_box(self, "FloorStripe_%s" % str(z), Vector3(0, 0.07, z), Vector3(23, 0.025, 0.12), "white", false)
	for x in [-18.0, 18.0]:
		for z in [-20.0, -7.0, 7.0, 20.0]:
			_box(self, "Planter_%s_%s" % [str(x), str(z)], Vector3(x, 0.35, z), Vector3(3.0, 0.7, 2.5), "wood_light")
			_box(self, "PlanterSoil_%s_%s" % [str(x), str(z)], Vector3(x, 0.73, z), Vector3(2.7, 0.08, 2.2), "soil", false)
			for i in range(3):
				_cylinder(self, "PlantTrunk", Vector3(x + float(i - 1) * 0.55, 1.25, z), 0.12, 1.1, "plant", false)
				_cylinder(self, "PlantCanopy", Vector3(x + float(i - 1) * 0.55, 1.85, z), 0.48, 0.75, "plant", false)

func _build_food_court() -> void:
	# Dining island tables in four broad zones. Aisles remain open between them.
	var seat_colors := ["seat_red", "seat_blue", "seat_green"]
	for row in range(5):
		for col in range(6):
			var x := -39.0 + float(col) * 15.5
			var z := -30.0 + float(row) * 14.0
			if absf(x) < 18.0 and absf(z) < 22.0:
				continue
			_build_table_set(Vector3(x, 0, z), seat_colors[(row + col) % seat_colors.size()], row * 10 + col)

func _build_table_set(origin: Vector3, seat_key: String, index: int) -> void:
	_box(self, "DiningTable_%02d" % index, origin + Vector3(0, 1.0, 0), Vector3(3.1, 0.18, 2.1), "wood_light")
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			_box(self, "TableLeg_%02d" % index, origin + Vector3(dx * 1.25, 0.48, dz * 0.72), Vector3(0.14, 0.95, 0.14), "metal")
	for side in [-1.0, 1.0]:
		_box(self, "DiningBench_%02d_%s" % [index, str(side)], origin + Vector3(0, 0.52, side * 1.75), Vector3(2.5, 0.95, 0.58), seat_key)
		_box(self, "BenchBack_%02d_%s" % [index, str(side)], origin + Vector3(0, 1.12, side * 2.0), Vector3(2.5, 0.75, 0.18), seat_key)

func _build_vendor_row() -> void:
	var sign_keys := ["sign_orange", "sign_pink", "sign_blue", "sign_orange", "sign_pink", "sign_blue", "sign_orange", "sign_pink"]
	var vendor_names := ["BURGERS", "NOODLES", "PIZZA", "FRIED CHICKEN", "DESSERTS", "TACOS", "COFFEE", "MILKSHAKES"]
	for i in range(vendor_names.size()):
		var x := -40.0 + float(i) * 11.4
		_box(self, "VendorBack_%02d" % i, Vector3(x, 1.7, -39.0), Vector3(9.5, 3.4, 2.2), "black")
		_box(self, "VendorCounter_%02d" % i, Vector3(x, 1.0, -36.8), Vector3(9.4, 1.5, 1.5), "wood")
		_box(self, "VendorBrandPanel_%02d" % i, Vector3(x, 3.7, -37.85), Vector3(8.6, 1.1, 0.2), sign_keys[i], false)
		_box(self, "MenuBoard_%02d" % i, Vector3(x, 2.65, -37.75), Vector3(7.6, 0.65, 0.12), "white", false)
		# Display food props as colourful silhouettes until detailed food assets are added.
		for j in range(3):
			_box(self, "DisplayProp_%02d_%02d" % [i, j], Vector3(x - 2.6 + float(j) * 2.6, 1.85, -36.0), Vector3(0.75, 0.48, 0.45), sign_keys[i], false)
		_box(self, "VendorNamePlate_%02d" % i, Vector3(x, 4.45, -37.85), Vector3(7.0, 0.1, 0.12), "white", false)
	# Kiosks and pickup zone facing the food court.
	for i in range(6):
		var x := -17.5 + float(i) * 7.0
		_box(self, "OrderKiosk_%02d" % i, Vector3(x, 1.45, -32.0), Vector3(1.2, 2.9, 0.8), "metal")
		_box(self, "KioskScreen_%02d" % i, Vector3(x, 1.95, -32.45), Vector3(0.88, 1.1, 0.08), "sign_blue", false)
	_box(self, "PickupCounter", Vector3(0, 0.9, -28.8), Vector3(16, 1.3, 1.2), "wood")

func _build_upper_gallery() -> void:
	# Balcony-like gallery ledges and glass rails on both sides.
	for side in [-1.0, 1.0]:
		_box(self, "UpperGallery_%s" % str(side), Vector3(side * 39.0, 5.2, 0), Vector3(12, 0.5, 58), "tile_dark", false)
		_box(self, "GalleryRail_%s" % str(side), Vector3(side * 33.0, 6.0, 0), Vector3(0.16, 1.2, 58), "glass", false)
		for z in range(-24, 29, 8):
			_box(self, "GalleryShopFront_%s_%d" % [str(side), z], Vector3(side * 48.8, 6.6, float(z)), Vector3(0.4, 2.4, 6.2), "glass", false)
			_box(self, "GalleryShopSign_%s_%d" % [str(side), z], Vector3(side * 48.4, 8.0, float(z)), Vector3(0.25, 0.6, 4.2), "sign_blue", false)

func _build_decor() -> void:
	# Ceiling light panels in a repeating architectural grid.
	for x in range(-40, 41, 10):
		for z in range(-30, 31, 10):
			_box(self, "CeilingLightPanel_%d_%d" % [x, z], Vector3(float(x), 9.82, float(z)), Vector3(3.4, 0.08, 1.2), "white", false)
	# Bench seating beside the atrium.
	for z in [-12.0, 12.0]:
		for x in [-12.0, 12.0]:
			_box(self, "AtriumBenchSeat", Vector3(x, 0.55, z), Vector3(3.4, 0.35, 0.8), "wood_light")
			_box(self, "AtriumBenchBase", Vector3(x, 0.25, z), Vector3(2.8, 0.35, 0.55), "metal")
	# Entry doors and glass panels.
	for x in [-12.0, -6.0, 6.0, 12.0]:
		_box(self, "EntranceGlassPanel_%s" % str(x), Vector3(x, 2.0, 42.6), Vector3(5.5, 4.0, 0.12), "glass", false)
	_box(self, "EntranceCanopy", Vector3(0, 4.7, 43.5), Vector3(30, 0.35, 4.0), "metal", false)
	_box(self, "EntranceSign", Vector3(0, 5.4, 43.3), Vector3(18, 0.8, 0.2), "sign_orange", false)

func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("202a39")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9d8ed")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.08
	env.ssao_enabled = true
	env.ssao_radius = 2.2
	env.ssao_intensity = 1.35
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.06
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 0.9
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.035
	sun.shadow_enabled = true
	add_child(sun)
	for x in [-35.0, -15.0, 15.0, 35.0]:
		for z in [-25.0, -5.0, 15.0, 32.0]:
			var light := OmniLight3D.new()
			light.position = Vector3(x, 8.8, z)
			light.light_color = Color("ffe0b5")
			light.light_energy = 1.05
			light.shadow_enabled = true
			light.omni_range = 16.0
			add_child(light)

func _build_player_camera() -> void:
	var rig := CharacterBody3D.new()
	rig.name = "PlayerPreview"
	rig.position = Vector3(0, 0.1, 36.0)
	add_child(rig)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.88
	rig.add_child(collision)
	var body_mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.32
	capsule_mesh.height = 1.65
	body_mesh.mesh = capsule_mesh
	body_mesh.position.y = 0.84
	body_mesh.material_override = mats["sign_blue"]
	rig.add_child(body_mesh)
	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(0, 1.62, 0)
	camera.rotation_degrees = Vector3(-7, 0, 0)
	camera.fov = 78.0
	camera.current = true
	rig.add_child(camera)
