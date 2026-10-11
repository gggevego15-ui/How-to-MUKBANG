extends Node
## Spawns the purchased order on a nearby dining table and animates each bite.

var _player: CharacterBody3D
var _tray: Node3D
var _servings: Array[Node3D] = []
var _eat_button: Button
var _hint: Label
var _is_eating := false
var _fullness := 0
var _feedback: Label
const BITE_SAMPLE_RATE := 22050

func _ready() -> void:
	_player = get_parent().get_parent().get_node_or_null("Player") as CharacterBody3D
	var layer := CanvasLayer.new()
	layer.name = "EatingLayer"
	layer.layer = 190
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_hint = Label.new()
	_hint.text = "🍱 ЗАКАЗ ГОТОВ — НАЖМИ F ИЛИ ЕСТЬ"
	_hint.visible = false
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.position = Vector2(-245, 48)
	_hint.add_theme_font_size_override("font_size", 19)
	_hint.add_theme_color_override("font_color", Color("a6ffc8"))
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(_hint)
	_eat_button = Button.new()
	_eat_button.text = "🍴  ЕСТЬ"
	_eat_button.visible = false
	_eat_button.custom_minimum_size = Vector2(170, 58)
	_eat_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_eat_button.position = Vector2(-195, -220)
	_eat_button.add_theme_font_size_override("font_size", 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1689b0")
	style.border_color = Color("8ceaff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	_eat_button.add_theme_stylebox_override("normal", style)
	_eat_button.pressed.connect(_eat_one)
	ui.add_child(_eat_button)
	_feedback = Label.new()
	_feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_feedback.position = Vector2(-150, 100)
	_feedback.add_theme_font_size_override("font_size", 24)
	_feedback.add_theme_color_override("font_color", Color("a6ffc8"))
	_feedback.add_theme_color_override("font_shadow_color", Color.BLACK)
	_feedback.add_theme_constant_override("shadow_offset_x", 2)
	_feedback.add_theme_constant_override("shadow_offset_y", 2)
	_feedback.visible = false
	ui.add_child(_feedback)

func _process(_delta: float) -> void:
	var ready := not _servings.is_empty()
	_eat_button.visible = ready and not _is_eating
	_hint.visible = ready

func _input(event: InputEvent) -> void:
	if not _servings.is_empty() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_eat_one()

func serve(ordered_items: Array, products: Array, player: CharacterBody3D) -> void:
	_player = player
	if _tray != null and is_instance_valid(_tray):
		_tray.queue_free()
	_servings.clear()
	_tray = Node3D.new()
	_tray.name = "FreshlyServedFood"
	get_parent().get_parent().add_child(_tray)
	_tray.global_position = _nearest_table() + Vector3(0, 1.18, 0)
	_tray.rotation.y = _player.global_rotation.y
	var plate := MeshInstance3D.new()
	var plate_mesh := CylinderMesh.new()
	plate_mesh.top_radius = 1.0
	plate_mesh.bottom_radius = 1.0
	plate_mesh.height = 0.08
	plate.mesh = plate_mesh
	plate.position.y = 0.04
	plate.material_override = _mat(Color("f0f4fa"), 0.22)
	_tray.add_child(plate)
	var total := 0
	for entry in ordered_items:
		total += mini(int(entry["count"]), 3)
	total = mini(total, 8)
	var n := 0
	for entry in ordered_items:
		var product: Dictionary = products[int(entry["index"])]
		for amount in range(mini(int(entry["count"]), 3)):
			if n >= 8:
				break
			var food := _make_food(str(product["name"]), str(product["category"]), n)
			food.set_meta("food_product", str(product["name"]))
			food.set_meta("food_category", str(product["category"]))
			var angle := float(n) * TAU / float(maxi(total, 1))
			var radius := 0.52 if total > 1 else 0.0
			var target := Vector3(cos(angle) * radius, 0.16, sin(angle) * radius)
			food.position = target + Vector3(0, -0.6, 0)
			food.scale = Vector3.ONE * 0.04
			_tray.add_child(food)
			_servings.append(food)
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(food, "position", target, 0.45).set_delay(float(n) * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(food, "scale", Vector3.ONE, 0.4).set_delay(float(n) * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			n += 1
		if n >= 8:
			break
	_tray.scale = Vector3.ONE * 0.82
	var tray_tween := create_tween()
	tray_tween.tween_property(_tray, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _nearest_table() -> Vector3:
	var best := Vector3(0, 0, -38)
	var best_distance := INF
	for row in range(6):
		for col in range(7):
			var x := -48.0 + float(col) * 16.0
			var z := -38.0 + float(row) * 15.0
			if absf(x) < 18.0 and absf(z) < 22.0:
				continue
			var distance := Vector2(_player.global_position.x - x, _player.global_position.z - z).length()
			if distance < best_distance:
				best_distance = distance
				best = Vector3(x, 0, z)
	return best

func _mat(color: Color, roughness: float = 0.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _piece(parent: Node3D, mesh: Mesh, pos: Vector3, scale: Vector3, color: Color, label: String) -> void:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.position = pos
	part.scale = scale
	part.material_override = _mat(color)
	parent.add_child(part)

func _make_food(product: String, category: String, index: int) -> Node3D:
	var food := Node3D.new()
	food.name = "Serving_%02d" % index
	var gold := Color("e9a84f")
	var brown := Color("663b2c")
	var white := Color("f4f3ec")
	var red := Color("d84343")
	var green := Color("68a844")
	if category == "КУРОЧКА":
		_piece(food, SphereMesh.new(), Vector3(0, 0.17, 0), Vector3(0.42, 0.22, 0.3), gold, "CrispyChicken")
		for i in range(5):
			_piece(food, SphereMesh.new(), Vector3(-0.16 + float(i) * 0.07, 0.29, sin(float(i)) * 0.13), Vector3(0.07, 0.055, 0.06), Color("d99a4e"), "Crunch_%d" % i)
	elif category == "РОЛЛЫ":
		for i in range(3):
			_piece(food, CylinderMesh.new(), Vector3(-0.22 + float(i) * 0.22, 0.17, 0), Vector3(0.13, 0.1, 0.13), white, "Roll_%d" % i)
			_piece(food, SphereMesh.new(), Vector3(-0.22 + float(i) * 0.22, 0.23, 0), Vector3(0.07, 0.035, 0.07), red if i == 1 else green, "Topping_%d" % i)
	elif product == "Бургер":
		_piece(food, SphereMesh.new(), Vector3(0, 0.17, 0), Vector3(0.42, 0.16, 0.34), brown, "Patty")
		_piece(food, SphereMesh.new(), Vector3(0, 0.25, 0), Vector3(0.46, 0.15, 0.36), gold, "Bun")
		_piece(food, BoxMesh.new(), Vector3(0, 0.2, 0), Vector3(0.45, 0.045, 0.35), Color("f3c83f"), "Cheese")
	elif product == "Картошка фри":
		for i in range(6):
			_piece(food, BoxMesh.new(), Vector3(-0.2 + float(i % 3) * 0.18, 0.2 + float(i % 2) * 0.04, -0.08 + float(i / 3) * 0.15), Vector3(0.065, 0.32, 0.065), gold, "Fry_%d" % i)
	elif product == "Пицца пепперони":
		_piece(food, CylinderMesh.new(), Vector3(0, 0.14, 0), Vector3(0.38, 0.07, 0.38), gold, "Crust")
		_piece(food, CylinderMesh.new(), Vector3(0, 0.19, 0), Vector3(0.33, 0.025, 0.33), red, "Sauce")
		for i in range(4):
			_piece(food, SphereMesh.new(), Vector3(cos(float(i) * TAU / 4.0) * 0.16, 0.22, sin(float(i) * TAU / 4.0) * 0.16), Vector3(0.07, 0.025, 0.07), brown, "Pepperoni_%d" % i)
	elif category == "НАПИТКИ":
		_piece(food, CylinderMesh.new(), Vector3(0, 0.22, 0), Vector3(0.18, 0.28, 0.18), Color("d74745"), "Cup")
		_piece(food, CylinderMesh.new(), Vector3(0, 0.51, 0), Vector3(0.19, 0.035, 0.19), white, "Lid")
		_piece(food, BoxMesh.new(), Vector3(0.04, 0.67, 0), Vector3(0.025, 0.25, 0.025), white, "Straw")
	elif category == "ДЕСЕРТЫ":
		_piece(food, CylinderMesh.new(), Vector3(0, 0.1, 0), Vector3(0.31, 0.035, 0.31), white, "DessertPlate")
		_piece(food, SphereMesh.new(), Vector3(0, 0.24, 0), Vector3(0.28, 0.14, 0.25), Color("ff83b7") if product == "Пончик" else Color("f1d4a4"), "Dessert")
	elif product == "Лапша вок":
		_piece(food, CylinderMesh.new(), Vector3(0, 0.1, 0), Vector3(0.34, 0.11, 0.34), white, "NoodleBowl")
		for i in range(5):
			_piece(food, SphereMesh.new(), Vector3(-0.18 + float(i) * 0.09, 0.22, sin(float(i)) * 0.08), Vector3(0.11, 0.035, 0.07), gold, "Noodle_%d" % i)
	else:
		_piece(food, SphereMesh.new(), Vector3(0, 0.18, 0), Vector3(0.35, 0.2, 0.3), gold, "Food")
	return food

func _eat_one() -> void:
	if _is_eating or _servings.is_empty():
		return
	_is_eating = true
	var food := _servings.pop_front()
	_play_bite_sound(food)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(food, "position", food.position + Vector3(0, 0.62, 0.22), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(food, "rotation", Vector3(-0.45, 0.7, 0.28), 0.42)
	tween.tween_property(food, "scale", Vector3.ONE * 0.02, 0.42).set_delay(0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(food):
			food.queue_free()
		_fullness = mini(_fullness + 12, 100)
		_feedback.text = "НЯМ!  +12 сытости  •  %d%%" % _fullness
		_feedback.visible = true
		_feedback.modulate.a = 1.0
		var pop := create_tween()
		pop.set_parallel(true)
		pop.tween_property(_feedback, "position:y", 62.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		pop.tween_property(_feedback, "modulate:a", 0.0, 1.0).set_delay(0.25)
		pop.chain().tween_callback(func() -> void:
			_feedback.visible = false
			_feedback.position.y = 100.0
		)
		_is_eating = false
		if _servings.is_empty() and _tray != null and is_instance_valid(_tray):
			var cleanup := create_tween()
			cleanup.tween_property(_tray, "scale", Vector3.ONE * 0.01, 0.25)
			cleanup.tween_callback(_tray.queue_free)
	)


## Plays a short, food-specific procedural sound without external audio files.
## Layered filtered noise, crunchy transients and soft low-frequency impacts keep the
## sound small enough for mobile while making each food group recognizably different.
func _play_bite_sound(food: Node3D) -> void:
	var product := str(food.get_meta("food_product", "Еда"))
	var category := str(food.get_meta("food_category", "ФАСТФУД"))
	var stream := _make_bite_stream(product, category)
	var player := AudioStreamPlayer.new()
	player.name = "BiteSound"
	player.stream = stream
	player.volume_db = -3.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _make_bite_stream(product: String, category: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var duration := 0.72
	var crunch := 0.72
	var wetness := 0.18
	var low_hit := 0.25
	var fizz := false
	if category == "КУРОЧКА":
		crunch = 1.0
		wetness = 0.12
		low_hit = 0.32
	elif category == "РОЛЛЫ":
		crunch = 0.22
		wetness = 0.65
		low_hit = 0.16
	elif category == "НАПИТКИ":
		duration = 0.88
		crunch = 0.08
		wetness = 0.76
		low_hit = 0.08
		fizz = product == "Кола" or product == "Лимонад"
	elif category == "ДЕСЕРТЫ":
		crunch = 0.30
		wetness = 0.42
		low_hit = 0.18
	elif product == "Картошка фри":
		crunch = 0.92
		wetness = 0.10
	elif product == "Пицца пепперони":
		crunch = 0.84
		wetness = 0.20
		low_hit = 0.34
	elif product == "Лапша вок":
		duration = 0.78
		crunch = 0.16
		wetness = 0.82
		low_hit = 0.12
	elif product == "Бургер":
		crunch = 0.68
		wetness = 0.28
		low_hit = 0.42

	var sample_count := int(BITE_SAMPLE_RATE * duration)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var bursts: Array[float] = []
	for i in range(7):
		bursts.append(rng.randf_range(0.045, duration * 0.72) + float(i) * 0.025)
	var low_phase := rng.randf_range(0.0, TAU)
	for i in range(sample_count):
		var t := float(i) / float(BITE_SAMPLE_RATE)
		var envelope := minf(t / 0.025, 1.0) * maxf(0.0, 1.0 - t / duration)
		var noise := rng.randf_range(-1.0, 1.0)
		var crisp := 0.0
		for burst in bursts:
			var age := t - burst
			if age >= 0.0 and age < 0.055:
				crisp += noise * exp(-age * 78.0) * (1.0 if int(burst * 1000.0) % 2 == 0 else 0.58)
		var chew := sin(TAU * (82.0 + low_hit * 48.0) * t + low_phase) * low_hit
		var moist := sin(TAU * (210.0 + 95.0 * sin(t * 17.0)) * t) * wetness * 0.18
		var hiss := rng.randf_range(-1.0, 1.0) * (0.14 if fizz else 0.035)
		var value := (crisp * crunch * 0.58 + chew * 0.32 + moist + hiss) * envelope
		value = clampf(value, -0.92, 0.92)
		pcm.encode_s16(i * 2, int(value * 32767.0))
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = BITE_SAMPLE_RATE
	audio.stereo = false
	audio.data = pcm
	return audio
