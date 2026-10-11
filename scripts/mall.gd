extends Node3D
## Procedural first milestone map for How to MUKBANG.
## Coordinates are in metres. The central atrium connects four food-court wings.

const MALL_WIDTH := 100.0
const MALL_DEPTH := 86.0
const WALL_HEIGHT := 10.0

var mats: Dictionary = {}
var imported_chair_scene: PackedScene
var imported_burger_scene: PackedScene
var imported_kiosk_scene: PackedScene

func _ready() -> void:
	imported_chair_scene = load("res://assets/models/cafe_chair.glb") as PackedScene
	imported_burger_scene = load("res://assets/models/burger_combo.glb") as PackedScene
	imported_kiosk_scene = load("res://assets/models/order_kiosk.glb") as PackedScene
	_make_materials()
	_build_mall_shell()
	_build_surface_detail()
	_build_atrium()
	_build_food_court()
	_build_vendor_row()
	_place_imported_assets()
	_build_upper_gallery()
	_build_decor()
	_build_lighting()
	_build_player_camera()
	_build_main_menu()

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

func _apply_pbr(key: String, family: String) -> void:
	var material := mats[key] as StandardMaterial3D
	if material == null:
		return
	var root := "res://assets/textures/pbr/%s_" % family
	material.albedo_texture = load(root + "basecolor_4k.svg") as Texture2D
	material.roughness_texture = load(root + "roughness_4k.svg") as Texture2D
	material.normal_texture = load(root + "normal_4k.svg") as Texture2D
	material.metallic_texture = load(root + "metallic_4k.svg") as Texture2D
	material.normal_enabled = true
	material.roughness = 1.0
	material.metallic = 1.0
	material.normal_scale = 0.28 if family == "food" else 0.2
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3(0.22, 0.22, 0.22)

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
	_material("bun", Color("d99a4e"), 0.72)
	_material("bun_top", Color("e8b86d"), 0.68)
	_material("patty", Color("493025"), 0.92)
	_material("lettuce", Color("65a83c"), 0.82)
	_material("tomato", Color("c9382d"), 0.45)
	_material("cheese", Color("f3c83f"), 0.48)
	_material("fries", Color("f2c35b"), 0.7)
	_material("paper", Color("fff2d6"), 0.8)
	_material("cup_red", Color("d83d35"), 0.32)
	_material("drink", Color("6b3928"), 0.18)
	_material("salad", Color("79a849"), 0.8)
	_material("ceramic", Color("e8edf1"), 0.22)
	_material("chrome", Color("aab7c4"), 0.2, 0.82)
	_material("screen", Color("152c42"), 0.16)
	_material("bun_seed", Color("f8e4b5"), 0.7)

	# Shared 4K SVG PBR maps; Godot rasterizes them on import and samples them with mipmapped filtering.
	for key in ["bun", "bun_top", "patty", "lettuce", "tomato", "cheese", "fries", "paper", "cup_red", "drink", "salad", "bun_seed"]:
		_apply_pbr(key, "food")
	for key in ["wood", "wood_light"]:
		_apply_pbr(key, "wood")
	_apply_pbr("ceramic", "ceramic")
	_apply_pbr("metal", "metal")
	_apply_pbr("chrome", "metal")

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


func _sphere(parent: Node3D, label: String, pos: Vector3, scale: Vector3, material_key: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.position = pos
	visual.scale = scale
	visual.material_override = mats[material_key]
	parent.add_child(visual)
	return visual

func _make_burger(origin: Vector3, index: int) -> void:
	_sphere(self, "BurgerBottom_%d" % index, origin + Vector3(0, 0.12, 0), Vector3(0.58, 0.2, 0.48), "bun")
	_box(self, "BurgerPatty_%d" % index, origin + Vector3(0, 0.24, 0), Vector3(0.52, 0.12, 0.44), "patty", false)
	_box(self, "BurgerCheese_%d" % index, origin + Vector3(0, 0.32, 0), Vector3(0.55, 0.055, 0.48), "cheese", false)
	_sphere(self, "BurgerLettuce_%d" % index, origin + Vector3(0, 0.37, 0), Vector3(0.59, 0.08, 0.49), "lettuce")
	_sphere(self, "BurgerTop_%d" % index, origin + Vector3(0, 0.49, 0), Vector3(0.6, 0.27, 0.5), "bun_top")
	for seed in range(5):
		var a := float(seed) * TAU / 5.0
		_sphere(self, "SesameSeed_%d_%d" % [index, seed], origin + Vector3(cos(a) * 0.15, 0.625, sin(a) * 0.12), Vector3(0.035, 0.012, 0.02), "bun_seed")

func _make_fries(origin: Vector3, index: int) -> void:
	_box(self, "FriesSleeve_%d" % index, origin + Vector3(0, 0.22, 0), Vector3(0.42, 0.42, 0.3), "sign_orange", false)
	for fry in range(7):
		var x := -0.15 + float(fry % 4) * 0.1
		var z := -0.07 + float(fry / 4) * 0.11
		_box(self, "FrenchFry_%d_%d" % [index, fry], origin + Vector3(x, 0.48 + float(fry % 3) * 0.025, z), Vector3(0.055, 0.38, 0.055), "fries", false)

func _make_drink(origin: Vector3, index: int) -> void:
	_cylinder(self, "DrinkCup_%d" % index, origin + Vector3(0, 0.28, 0), 0.17, 0.55, "cup_red", false)
	_cylinder(self, "DrinkLid_%d" % index, origin + Vector3(0, 0.57, 0), 0.18, 0.045, "white", false)
	_cylinder(self, "DrinkLiquid_%d" % index, origin + Vector3(0, 0.48, 0), 0.145, 0.12, "drink", false)
	_box(self, "DrinkStraw_%d" % index, origin + Vector3(0.045, 0.72, 0), Vector3(0.025, 0.28, 0.025), "white", false)

func _make_pizza(origin: Vector3, index: int) -> void:
	_cylinder(self, "PizzaCrust_%d" % index, origin + Vector3(0, 0.13, 0), 0.3, 0.09, "bun", false)
	_cylinder(self, "PizzaSauce_%d" % index, origin + Vector3(0, 0.19, 0), 0.27, 0.035, "tomato", false)
	_cylinder(self, "PizzaCheese_%d" % index, origin + Vector3(0, 0.215, 0), 0.255, 0.025, "cheese", false)
	for topping in range(5):
		var a := float(topping) * TAU / 5.0
		_sphere(self, "Pepperoni_%d_%d" % [index, topping], origin + Vector3(cos(a) * 0.14, 0.24, sin(a) * 0.14), Vector3(0.09, 0.025, 0.09), "tomato")

func _make_food_display(vendor_index: int, x: float, z: float) -> void:
	for j in range(3):
		var origin := Vector3(x - 2.7 + float(j) * 2.7, 1.95, z)
		var index := vendor_index * 10 + j
		match vendor_index:
			0:
				_make_burger(origin, index)
				if j == 1: _make_fries(origin + Vector3(0.55, 0, 0.1), index)
			1:
				_cylinder(self, "NoodleBowl_%d" % index, origin + Vector3(0, 0.12, 0), 0.3, 0.18, "ceramic", false)
				for noodle in range(5):
					_sphere(self, "Noodle_%d_%d" % [index, noodle], origin + Vector3(-0.16 + float(noodle) * 0.08, 0.25, sin(float(noodle)) * 0.08), Vector3(0.12, 0.035, 0.08), "bun_top")
			2:
				_make_pizza(origin, index)
			3:
				_sphere(self, "ChickenPiece_%d" % index, origin + Vector3(0, 0.16, 0), Vector3(0.42, 0.27, 0.34), "bun_top")
				_sphere(self, "ChickenCrunch_%d" % index, origin + Vector3(-0.08, 0.25, 0.02), Vector3(0.3, 0.15, 0.28), "bun")
			4:
				_cylinder(self, "DessertPlate_%d" % index, origin + Vector3(0, 0.08, 0), 0.32, 0.035, "ceramic", false)
				_sphere(self, "Donut_%d" % index, origin + Vector3(0, 0.2, 0), Vector3(0.4, 0.14, 0.38), "sign_pink")
				_cylinder(self, "DonutHole_%d" % index, origin + Vector3(0, 0.28, 0), 0.09, 0.025, "bun_top", false)
			5:
				_box(self, "TacoShell_%d" % index, origin + Vector3(0, 0.16, 0), Vector3(0.48, 0.2, 0.25), "bun_top", false)
				_sphere(self, "TacoFilling_%d" % index, origin + Vector3(0, 0.27, 0), Vector3(0.4, 0.12, 0.2), "lettuce")
			6:
				_make_drink(origin, index)
			7:
				_make_drink(origin, index)
				_sphere(self, "MilkshakeCream_%d" % index, origin + Vector3(0, 0.63, 0), Vector3(0.19, 0.11, 0.19), "white")

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
	_box(self, "DiningTableTop_%02d" % index, origin + Vector3(0, 1.05, 0), Vector3(2.65, 0.12, 1.65), "wood_light")
	_box(self, "DiningTableEdge_%02d" % index, origin + Vector3(0, 0.98, 0), Vector3(2.72, 0.08, 1.72), "metal", false)
	_box(self, "TablePedestal_%02d" % index, origin + Vector3(0, 0.5, 0), Vector3(0.22, 0.9, 0.22), "metal")
	_box(self, "TableFoot_%02d" % index, origin + Vector3(0, 0.08, 0), Vector3(1.05, 0.12, 0.7), "metal")
	if imported_chair_scene != null:
		var chair_positions := [
			[Vector3(-1.02, 0, 0), PI / 2.0],
			[Vector3(1.02, 0, 0), -PI / 2.0],
			[Vector3(0, 0, -1.22), 0.0],
			[Vector3(0, 0, 1.22), PI]
		]
		for chair_index in range(chair_positions.size()):
			var entry: Array = chair_positions[chair_index]
			var chair := imported_chair_scene.instantiate() as Node3D
			chair.name = "ImportedCafeChair_%02d_%d" % [index, chair_index]
			chair.position = origin + entry[0]
			chair.rotation.y = entry[1]
			chair.scale = Vector3.ONE * 0.95
			add_child(chair)
	else:
		for side in [-1.0, 1.0]:
			_box(self, "FallbackBench_%02d_%s" % [index, str(side)], origin + Vector3(0, 0.52, side * 1.25), Vector3(2.1, 0.95, 0.58), seat_key)

func _build_vendor_row() -> void:
	var sign_keys := ["sign_orange", "sign_pink", "sign_blue", "sign_orange", "sign_pink", "sign_blue", "sign_orange", "sign_pink"]
	var vendor_names := ["BURGERS", "NOODLES", "PIZZA", "FRIED CHICKEN", "DESSERTS", "TACOS", "COFFEE", "MILKSHAKES"]
	for i in range(vendor_names.size()):
		var x := -40.0 + float(i) * 11.4
		_box(self, "VendorBack_%02d" % i, Vector3(x, 1.7, -39.0), Vector3(9.5, 3.4, 2.2), "black")
		_box(self, "VendorCounterCabinet_%02d" % i, Vector3(x, 0.83, -36.8), Vector3(9.25, 1.05, 1.42), "wood")
		_box(self, "VendorCounterTop_%02d" % i, Vector3(x, 1.42, -36.8), Vector3(9.55, 0.16, 1.58), "chrome", false)
		_box(self, "VendorToeKick_%02d" % i, Vector3(x, 0.18, -36.03), Vector3(9.15, 0.22, 0.08), "metal", false)
		for drawer in range(4):
			_box(self, "CabinetPanel_%d_%d" % [i, drawer], Vector3(x - 3.45 + float(drawer) * 2.3, 0.77, -36.06), Vector3(2.05, 0.58, 0.055), "wood_light", false)
			_box(self, "CabinetHandle_%d_%d" % [i, drawer], Vector3(x - 3.45 + float(drawer) * 2.3, 0.8, -36.015), Vector3(0.45, 0.035, 0.035), "chrome", false)
		_box(self, "VendorBrandPanel_%02d" % i, Vector3(x, 3.7, -37.85), Vector3(8.6, 1.1, 0.2), sign_keys[i], false)
		_box(self, "MenuBoardFrame_%02d" % i, Vector3(x, 2.65, -37.73), Vector3(7.8, 0.82, 0.14), "metal", false)
		_box(self, "MenuBoard_%02d" % i, Vector3(x, 2.65, -37.63), Vector3(7.55, 0.62, 0.06), "screen", false)
		for menu_item in range(4):
			_box(self, "MenuItemLine_%d_%d" % [i, menu_item], Vector3(x - 2.4 + float(menu_item) * 1.55, 2.7, -37.585), Vector3(1.1, 0.035, 0.025), "white", false)
		_box(self, "VendorNamePlate_%02d" % i, Vector3(x, 4.45, -37.85), Vector3(7.0, 0.1, 0.12), "white", false)
		# Display glass guard and metal posts in front of food.
		_box(self, "DisplayGlass_%02d" % i, Vector3(x, 2.05, -35.95), Vector3(8.5, 0.75, 0.045), "glass", false)
		for post_x in [-4.1, 4.1]:
			_box(self, "DisplayPost_%02d" % i, Vector3(x + post_x, 2.05, -35.95), Vector3(0.07, 0.85, 0.07), "chrome", false)
		if i != 0:
			_make_food_display(i, x, -36.2)
func _place_imported_assets() -> void:
	# GLB assets use embedded PBR base-colour, roughness and normal maps.
	if imported_burger_scene != null:
		var burger := imported_burger_scene.instantiate() as Node3D
		burger.name = "ImportedBurgerCombo"
		burger.position = Vector3(-40.0, 1.53, -36.2)
		burger.scale = Vector3(1.15, 1.15, 1.15)
		add_child(burger)
	if imported_kiosk_scene != null:
		for i in range(6):
			var x := -17.5 + float(i) * 7.0
			var kiosk := imported_kiosk_scene.instantiate() as Node3D
			kiosk.name = "ImportedOrderKiosk_%02d" % i
			kiosk.position = Vector3(x, 0.0, -32.0)
			kiosk.scale = Vector3(1.15, 1.15, 1.15)
			add_child(kiosk)

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
	rig.name = "Player"
	rig.position = Vector3(0, 0.1, 36.0)
	rig.set_script(load("res://scripts/player_controller.gd"))
	add_child(rig)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.88
	rig.add_child(collision)

	# Visible first-person legs: they sit below the camera and appear when looking down.
	for side in [-1, 1]:
		var leg := MeshInstance3D.new()
		leg.name = "PlayerLeg_%d" % side
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.19, 0.69, 0.25)
		leg.mesh = leg_mesh
		leg.position = Vector3(0.15 * side, 0.43, -0.035)
		leg.material_override = mats["sign_blue"]
		rig.add_child(leg)
		var shoe := MeshInstance3D.new()
		shoe.name = "PlayerShoe_%d" % side
		var shoe_mesh := BoxMesh.new()
		shoe_mesh.size = Vector3(0.2, 0.12, 0.34)
		shoe.mesh = shoe_mesh
		shoe.position = Vector3(0.15 * side, 0.09, -0.085)
		shoe.material_override = mats["black"]
		rig.add_child(shoe)

	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(0, 1.62, 0)
	camera.fov = 78.0
	camera.current = true
	rig.add_child(camera)


# Main menu overlay: works on desktop and mobile without replacing the procedural mall scene.
var _main_menu_layer: CanvasLayer
var _main_menu_root: Control
var _settings_panel: PanelContainer
var _menu_player: CharacterBody3D

func _build_main_menu() -> void:
	_menu_player = get_node_or_null("Player") as CharacterBody3D
	_main_menu_layer = CanvasLayer.new()
	_main_menu_layer.name = "MainMenuLayer"
	_main_menu_layer.layer = 200
	add_child(_main_menu_layer)

	_main_menu_root = Control.new()
	_main_menu_root.name = "MainMenu"
	_main_menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_menu_layer.add_child(_main_menu_root)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.045, 0.82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_menu_root.add_child(backdrop)

	var layout := HBoxContainer.new()
	layout.name = "MenuLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 24)
	_main_menu_root.add_child(layout)

	var left_margin := MarginContainer.new()
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_margin.add_theme_constant_override("margin_left", 48)
	left_margin.add_theme_constant_override("margin_top", 30)
	left_margin.add_theme_constant_override("margin_bottom", 30)
	layout.add_child(left_margin)

	var intro := VBoxContainer.new()
	intro.alignment = BoxContainer.ALIGNMENT_CENTER
	intro.add_theme_constant_override("separation", 12)
	left_margin.add_child(intro)

	var eyebrow := Label.new()
	eyebrow.text = "THE ULTIMATE FOOD COURT"
	eyebrow.add_theme_font_size_override("font_size", 16)
	eyebrow.add_theme_color_override("font_color", Color("65d9ff"))
	intro.add_child(eyebrow)

	var title := Label.new()
	title.text = "HOW TO\nMUKBANG"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color("f5f8ff"))
	intro.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Explore. Grab a bite. Make it your mall."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("c1ccdc"))
	intro.add_child(subtitle)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(112, 4)
	accent.color = Color("65d9ff")
	intro.add_child(accent)

	var menu_margin := MarginContainer.new()
	menu_margin.custom_minimum_size = Vector2(310, 0)
	menu_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_margin.add_theme_constant_override("margin_right", 42)
	menu_margin.add_theme_constant_override("margin_top", 42)
	menu_margin.add_theme_constant_override("margin_bottom", 42)
	layout.add_child(menu_margin)

	var menu_card := PanelContainer.new()
	menu_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.035, 0.055, 0.085, 0.94)
	card_style.border_color = Color(0.30, 0.72, 0.92, 0.8)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(18)
	card_style.content_margin_left = 24
	card_style.content_margin_right = 24
	card_style.content_margin_top = 28
	card_style.content_margin_bottom = 28
	menu_card.add_theme_stylebox_override("panel", card_style)
	menu_margin.add_child(menu_card)

	var menu_buttons := VBoxContainer.new()
	menu_buttons.add_theme_constant_override("separation", 12)
	menu_card.add_child(menu_buttons)

	var menu_heading := Label.new()
	menu_heading.text = "MAIN MENU"
	menu_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_heading.add_theme_font_size_override("font_size", 21)
	menu_heading.add_theme_color_override("font_color", Color("f5f8ff"))
	menu_buttons.add_child(menu_heading)

	var start_button := _make_menu_button("PLAY", true)
	menu_buttons.add_child(start_button)
	start_button.pressed.connect(_start_game)

	var settings_button := _make_menu_button("SETTINGS", false)
	menu_buttons.add_child(settings_button)
	settings_button.pressed.connect(_toggle_settings)

	var quit_button := _make_menu_button("QUIT GAME", false)
	menu_buttons.add_child(quit_button)
	quit_button.pressed.connect(func() -> void:
		get_tree().quit()
	)

	var footer := Label.new()
	footer.text = "WASD / TOUCH CONTROLS"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color("8294aa"))
	menu_buttons.add_child(footer)

	_build_settings_panel(menu_buttons)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _make_menu_button(caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(230, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("48bfe8") if primary else Color(0.10, 0.15, 0.22, 0.96)
	normal.border_color = Color("83e2ff") if primary else Color(0.32, 0.46, 0.58, 0.8)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("72d7f5") if primary else Color(0.16, 0.25, 0.35, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("2499c6") if primary else Color(0.07, 0.11, 0.17, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color("f6fbff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	return button

func _build_settings_panel(parent: Control) -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.visible = false
	_settings_panel.custom_minimum_size = Vector2(280, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.045, 0.07, 0.98)
	panel_style.border_color = Color("65d9ff")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	_settings_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(_settings_panel)

	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 10)
	_settings_panel.add_child(settings_box)

	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 18)
	settings_box.add_child(heading)

	var sensitivity_label := Label.new()
	sensitivity_label.name = "SensitivityLabel"
	sensitivity_label.text = "Mouse sensitivity"
	settings_box.add_child(sensitivity_label)

	var sensitivity := HSlider.new()
	sensitivity.name = "SensitivitySlider"
	sensitivity.min_value = 0.0008
	sensitivity.max_value = 0.006
	sensitivity.step = 0.0002
	sensitivity.value = 0.0022
	sensitivity.custom_minimum_size = Vector2(220, 28)
	settings_box.add_child(sensitivity)
	sensitivity.value_changed.connect(func(value: float) -> void:
		if _menu_player != null:
			_menu_player.set("mouse_sensitivity", value)
		sensitivity_label.text = "Mouse sensitivity: %.4f" % value
	)

	var back_button := _make_menu_button("BACK", false)
	settings_box.add_child(back_button)
	back_button.pressed.connect(func() -> void:
		_settings_panel.visible = false
	)

func _toggle_settings() -> void:
	if _settings_panel != null:
		_settings_panel.visible = not _settings_panel.visible

func _start_game() -> void:
	if _main_menu_layer != null:
		_main_menu_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _menu_player != null:
		_menu_player.set_physics_process(true)
