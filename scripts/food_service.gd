extends Node
## Delivers each order to the selected table with a procedural waiter.

signal delivery_started
signal delivery_completed


var _player: CharacterBody3D
var _tray: Node3D
var _waiter: Node3D
var _servings: Array[Node3D] = []
var _eat_button: Button
var _hint: Label
var _is_eating := false
var _fullness := 0
var _feedback: Label
var _hand_rig: Node3D
var _camera: Camera3D
var _hand_home_position := Vector3(0.46, -0.55, -0.68)
var _hand_home_rotation := Vector3(-0.12, 0.08, -0.08)
const BITES_PER_SERVING := 3
const BITE_SAMPLE_RATE := 22050

func _ready() -> void:
	_player = get_parent().get_parent().get_node_or_null("Player") as CharacterBody3D
	if _player != null:
		_camera = _player.get_node_or_null("PreviewCamera") as Camera3D
	if _camera != null:
		_build_hand_rig()
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
	if ready:
		_hint.text = "🍱 ЗАКАЗ ГОТОВ — F / ЕСТЬ  •  %d порций" % _servings.size()

func _input(event: InputEvent) -> void:
	if not _servings.is_empty() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_eat_one()

func serve(ordered_items: Array, products: Array, player: CharacterBody3D) -> void:
	_player = player
	if _waiter != null and is_instance_valid(_waiter):
		_waiter.queue_free()
	if _tray != null and is_instance_valid(_tray):
		_tray.queue_free()
	_servings.clear()
	var world := get_parent().get_parent()
	var table_origin := _nearest_table()
	var start_position := Vector3(clampf(table_origin.x, -40.0, 39.8), 0.0, -35.0)
	_waiter = _build_waiter()
	_waiter.name = "OrderDeliveryWaiter"
	world.add_child(_waiter)
	_waiter.global_position = start_position
	_waiter.rotation.y = atan2(-(table_origin.x - start_position.x), -(table_origin.z - start_position.z))
	_tray = Node3D.new()
	_tray.name = "WaiterServingTray"
	_waiter.add_child(_tray)
	_tray.position = Vector3(0, 1.18, -0.38)
	_tray.rotation = Vector3.ZERO
	emit_signal("delivery_started")
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
	var travel_distance := Vector2(table_origin.x - start_position.x, table_origin.z - start_position.z).length()
	var travel_time := clampf(travel_distance / 2.6, 1.8, 6.0)
	var walk := create_tween()
	walk.set_trans(Tween.TRANS_CUBIC)
	walk.set_ease(Tween.EASE_IN_OUT)
	walk.tween_property(_waiter, "global_position", Vector3(table_origin.x, 0.0, table_origin.z + 0.45), travel_time)
	var sway := create_tween()
	sway.set_loops(maxi(1, int(ceil(travel_time / 0.32))))
	sway.tween_property(_waiter, "rotation:z", deg_to_rad(3.0), 0.16)
	sway.tween_property(_waiter, "rotation:z", deg_to_rad(-3.0), 0.16)
	await walk.finished
	if not is_inside_tree() or not is_instance_valid(_tray) or not is_instance_valid(_waiter):
		return
	if sway.is_running():
		sway.kill()
	_waiter.rotation.z = 0.0
	_tray.reparent(world, true)
	_tray.global_position = table_origin + Vector3(0, 1.18, 0)
	_tray.rotation.y = _player.global_rotation.y
	var tray_tween := create_tween()
	tray_tween.set_parallel(true)
	tray_tween.tween_property(_tray, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tray_tween.tween_property(_tray, "position:y", 1.18, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var waiter_fade := create_tween()
	waiter_fade.tween_property(_waiter, "scale", Vector3.ONE * 0.85, 0.22)
	waiter_fade.tween_property(_waiter, "scale", Vector3.ZERO, 0.3)
	waiter_fade.tween_callback(_waiter.queue_free)
	emit_signal("delivery_completed")

func _build_waiter() -> Node3D:
	var waiter := Node3D.new()
	waiter.name = "ProceduralWaiter"
	var uniform := _mat(Color("24364f"), 0.68)
	var apron := _mat(Color("e7eaf0"), 0.72)
	var skin := _mat(Color("c88e68"), 0.78)
	var hair := _mat(Color("30251f"), 0.9)
	_piece(waiter, CapsuleMesh.new(), Vector3(0, 0.91, 0), Vector3(0.34, 0.48, 0.28), Color("24364f"), "WaiterUniform")
	_piece(waiter, BoxMesh.new(), Vector3(0, 0.88, -0.155), Vector3(0.27, 0.38, 0.035), Color("e7eaf0"), "WaiterApron")
	_piece(waiter, SphereMesh.new(), Vector3(0, 1.52, 0), Vector3(0.22, 0.25, 0.22), Color("c88e68"), "WaiterHead")
	_piece(waiter, SphereMesh.new(), Vector3(0, 1.66, 0.015), Vector3(0.225, 0.13, 0.23), Color("30251f"), "WaiterHair")
	_piece(waiter, BoxMesh.new(), Vector3(0, 1.79, 0), Vector3(0.34, 0.09, 0.32), Color("f3f5f8"), "WaiterCap")
	var left_leg := Node3D.new()
	left_leg.position = Vector3(-0.105, 0.58, 0)
	waiter.add_child(left_leg)
	_piece(left_leg, CapsuleMesh.new(), Vector3(0, -0.25, 0), Vector3(0.11, 0.29, 0.12), Color("172333"), "LeftLeg")
	var right_leg := Node3D.new()
	right_leg.position = Vector3(0.105, 0.58, 0)
	waiter.add_child(right_leg)
	_piece(right_leg, CapsuleMesh.new(), Vector3(0, -0.25, 0), Vector3(0.11, 0.29, 0.12), Color("172333"), "RightLeg")
	var left_arm := Node3D.new()
	left_arm.position = Vector3(-0.23, 1.13, -0.01)
	waiter.add_child(left_arm)
	_piece(left_arm, CapsuleMesh.new(), Vector3(0, -0.22, -0.02), Vector3(0.085, 0.25, 0.09), Color("24364f"), "LeftArm")
	var right_arm := Node3D.new()
	right_arm.position = Vector3(0.23, 1.13, -0.01)
	waiter.add_child(right_arm)
	_piece(right_arm, CapsuleMesh.new(), Vector3(0, -0.22, -0.02), Vector3(0.085, 0.25, 0.09), Color("24364f"), "RightArm")
	var arms := create_tween()
	arms.set_loops()
	arms.tween_property(left_arm, "rotation:x", -0.42, 0.18)
	arms.parallel().tween_property(right_arm, "rotation:x", 0.42, 0.18)
	arms.tween_property(left_arm, "rotation:x", 0.42, 0.18)
	arms.parallel().tween_property(right_arm, "rotation:x", -0.42, 0.18)
	var gait := create_tween()
	gait.set_loops()
	gait.tween_property(left_leg, "rotation:x", 0.42, 0.18)
	gait.parallel().tween_property(right_leg, "rotation:x", -0.42, 0.18)
	gait.tween_property(left_leg, "rotation:x", -0.42, 0.18)
	gait.parallel().tween_property(right_leg, "rotation:x", 0.42, 0.18)
	return waiter

func _nearest_table() -> Vector3:
	if _player != null and _player.has_meta("seated_table_position"):
		var seated_table: Vector3 = _player.get_meta("seated_table_position")
		return seated_table
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

func _build_hand_rig() -> void:
	# Lightweight first-person hand model attached to the camera.
	_hand_rig = Node3D.new()
	_hand_rig.name = "EatingHandRig"
	_hand_rig.position = _hand_home_position
	_hand_rig.rotation = _hand_home_rotation
	_hand_rig.visible = false
	_camera.add_child(_hand_rig)
	var skin := _mat(Color("c98f70"), 0.68)
	var sleeve := _mat(Color("e8edf1"), 0.82)
	var arm := MeshInstance3D.new()
	arm.name = "Forearm"
	var arm_mesh := CylinderMesh.new()
	arm_mesh.top_radius = 0.075
	arm_mesh.bottom_radius = 0.105
	arm_mesh.height = 0.38
	arm.mesh = arm_mesh
	arm.position = Vector3(0.0, -0.13, 0.02)
	arm.rotation.z = -0.22
	arm.material_override = sleeve
	_hand_rig.add_child(arm)
	var palm := MeshInstance3D.new()
	palm.name = "Palm"
	palm.mesh = SphereMesh.new()
	palm.position = Vector3(0.0, 0.09, -0.06)
	palm.scale = Vector3(0.105, 0.115, 0.07)
	palm.material_override = skin
	_hand_rig.add_child(palm)
	for finger in range(4):
		var digit := MeshInstance3D.new()
		digit.name = "Finger_%d" % finger
		var digit_mesh := CapsuleMesh.new()
		digit_mesh.radius = 0.018
		digit_mesh.height = 0.105
		digit.mesh = digit_mesh
		digit.position = Vector3(-0.063 + float(finger) * 0.042, 0.17, -0.09)
		digit.rotation.x = -0.38
		digit.material_override = skin
		_hand_rig.add_child(digit)
	var thumb := MeshInstance3D.new()
	thumb.name = "Thumb"
	var thumb_mesh := CapsuleMesh.new()
	thumb_mesh.radius = 0.022
	thumb_mesh.height = 0.11
	thumb.mesh = thumb_mesh
	thumb.position = Vector3(0.105, 0.08, -0.08)
	thumb.rotation.z = -0.8
	thumb.rotation.x = -0.35
	thumb.material_override = skin
	_hand_rig.add_child(thumb)

func _animate_hand_for_food(food: Node3D, lifting: bool) -> void:
	if _hand_rig == null or not is_instance_valid(_hand_rig):
		return
	var product := str(food.get_meta("food_product", "Еда"))
	var category := str(food.get_meta("food_category", "ФАСТФУД"))
	var target_position := _hand_home_position
	var target_rotation := _hand_home_rotation
	var curl := 0.45
	var thumb_angle := -0.55
	# Product-specific grips and wrist paths: cup, pinch, flat slice, noodles or wrap.
	if category == "НАПИТКИ":
		target_position += Vector3(-0.07, 0.04, 0.13)
		target_rotation += Vector3(-0.35, 0.10, 0.20)
		curl = 0.70
		thumb_angle = -0.95
	elif category == "РОЛЛЫ" or product == "Картошка фри":
		target_position += Vector3(-0.02, 0.01, 0.04)
		target_rotation += Vector3(-0.18, 0.02, -0.12)
		curl = 0.28
		thumb_angle = -0.72
	elif product == "Пицца пепперони":
		target_position += Vector3(-0.11, 0.00, 0.02)
		target_rotation += Vector3(-0.05, 0.0, 0.34)
		curl = 0.18
		thumb_angle = -0.42
	elif product == "Лапша вок":
		target_position += Vector3(-0.06, 0.03, 0.10)
		target_rotation += Vector3(-0.28, 0.06, 0.12)
		curl = 0.34
		thumb_angle = -0.60
	elif category == "ДЕСЕРТЫ":
		target_position += Vector3(-0.03, 0.02, 0.06)
		target_rotation += Vector3(-0.20, 0.0, -0.08)
		curl = 0.32
		thumb_angle = -0.65
	elif category == "КУРОЧКА":
		target_position += Vector3(-0.03, 0.02, 0.07)
		target_rotation += Vector3(-0.22, 0.08, -0.16)
		curl = 0.56
		thumb_angle = -0.78
	else:
		target_position += Vector3(-0.02, 0.02, 0.08)
		target_rotation += Vector3(-0.25, 0.02, -0.18)
		curl = 0.62
		thumb_angle = -0.86
	if not lifting:
		target_position = _hand_home_position
		target_rotation = _hand_home_rotation
	_hand_rig.visible = true
	var hand_tween := create_tween()
	hand_tween.set_trans(Tween.TRANS_CUBIC)
	hand_tween.set_ease(Tween.EASE_OUT)
	hand_tween.tween_property(_hand_rig, "position", target_position, 0.22)
	hand_tween.parallel().tween_property(_hand_rig, "rotation", target_rotation, 0.22)
	for finger in range(4):
		var digit := _hand_rig.get_node_or_null("Finger_%d" % finger) as Node3D
		if digit != null:
			var finger_rotation := -0.15 - curl * (0.70 + float(finger % 2) * 0.12)
			hand_tween.parallel().tween_property(digit, "rotation:z", finger_rotation if lifting else -0.05, 0.18)
	var thumb := _hand_rig.get_node_or_null("Thumb") as Node3D
	if thumb != null:
		hand_tween.parallel().tween_property(thumb, "rotation:z", thumb_angle if lifting else -0.35, 0.18)

func _eat_one() -> void:
	if _is_eating or _servings.is_empty():
		return
	_is_eating = true
	var food := _servings[0]
	if not is_instance_valid(food):
		_servings.pop_front()
		_is_eating = false
		return
	var original_position := food.global_position
	var original_rotation := food.rotation
	var original_scale := food.scale
	var bites_left := int(food.get_meta("bites_left", BITES_PER_SERVING))
	food.set_meta("bites_left", bites_left)
	_animate_hand_for_food(food, true)
	_play_bite_sound(food)
	var tween := create_tween()
	tween.set_parallel(true)
	var mouth_position := _camera.global_position + (-_camera.global_transform.basis.z * 0.62) + Vector3.UP * -0.20 if _camera != null else original_position + Vector3.UP * 0.5
	tween.tween_property(food, "global_position", mouth_position, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(food, "rotation", Vector3(-0.35, food.rotation.y + 0.55, 0.22), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(food, "scale", original_scale * 0.88, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.12)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(food):
			_is_eating = false
			return
		bites_left -= 1
		food.set_meta("bites_left", bites_left)
		_animate_chewing()
		_spawn_bite_effects(food)
		_fullness = mini(_fullness + int(ceil(12.0 / float(BITES_PER_SERVING))), 100)
		_feedback.text = "НЯМ!  Укус %d/%d  •  %d%%" % [BITES_PER_SERVING - bites_left, BITES_PER_SERVING, _fullness]
		_feedback.visible = true
		_feedback.modulate.a = 1.0
		var pop := create_tween()
		pop.set_parallel(true)
		pop.tween_property(_feedback, "position:y", 62.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		pop.tween_property(_feedback, "modulate:a", 0.0, 0.75).set_delay(0.15)
		pop.chain().tween_callback(func() -> void:
			if is_instance_valid(_feedback):
				_feedback.visible = false
				_feedback.position.y = 100.0
		)
		if bites_left > 0:
			var return_tween := create_tween()
			return_tween.set_parallel(true)
			return_tween.tween_property(food, "global_position", original_position, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			return_tween.tween_property(food, "rotation", original_rotation, 0.22)
			var remaining_ratio := float(bites_left) / float(BITES_PER_SERVING)
			return_tween.tween_property(food, "scale", original_scale * (0.55 + 0.45 * remaining_ratio), 0.22)
			return_tween.chain().tween_callback(func() -> void:
				_is_eating = false
				if _hand_rig != null and is_instance_valid(_hand_rig):
					_hand_rig.visible = false
					_hand_rig.position = _hand_home_position
					_hand_rig.rotation = _hand_home_rotation
			)
		else:
			_servings.pop_front()
			var remove_tween := create_tween()
			remove_tween.set_parallel(true)
			remove_tween.tween_property(food, "scale", Vector3.ONE * 0.015, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			remove_tween.tween_property(food, "position:y", food.position.y + 0.08, 0.16)
			remove_tween.chain().tween_callback(func() -> void:
				if is_instance_valid(food):
					food.queue_free()
				if _hand_rig != null and is_instance_valid(_hand_rig):
					_hand_rig.visible = false
					_hand_rig.position = _hand_home_position
					_hand_rig.rotation = _hand_home_rotation
				_is_eating = false
				if _servings.is_empty() and _tray != null and is_instance_valid(_tray):
					var cleanup := create_tween()
					cleanup.tween_property(_tray, "scale", Vector3.ONE * 0.01, 0.25)
					cleanup.tween_callback(_tray.queue_free)
		)
	)

func _animate_chewing() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var home_position := _camera.position
	var home_rotation := _camera.rotation
	var chew := create_tween()
	chew.set_trans(Tween.TRANS_SINE)
	chew.set_ease(Tween.EASE_IN_OUT)
	for cycle in range(3):
		chew.tween_property(_camera, "rotation:x", home_rotation.x + deg_to_rad(1.1), 0.09)
		chew.parallel().tween_property(_camera, "position:y", home_position.y - 0.012, 0.09)
		chew.tween_property(_camera, "rotation:x", home_rotation.x - deg_to_rad(0.7), 0.10)
		chew.parallel().tween_property(_camera, "position:y", home_position.y + 0.006, 0.10)
	chew.tween_property(_camera, "rotation", home_rotation, 0.12)
	chew.parallel().tween_property(_camera, "position", home_position, 0.12)

func _spawn_bite_effects(food: Node3D) -> void:
	if not is_instance_valid(food):
		return
	var category := str(food.get_meta("food_category", "ФАСТФУД"))
	var product := str(food.get_meta("food_product", "Еда"))
	if category == "НАПИТКИ" or product == "Лапша вок":
		return
	var crumbs := Node3D.new()
	crumbs.name = "BiteCrumbs"
	get_parent().get_parent().add_child(crumbs)
	var origin := food.global_position
	var crumb_color := Color("d9a45c") if category == "КУРОЧКА" or product == "Картошка фри" else Color("b77b48")
	for i in range(4):
		var crumb := MeshInstance3D.new()
		crumb.mesh = SphereMesh.new()
		crumb.scale = Vector3.ONE * (0.018 + float(i % 2) * 0.008)
		crumb.position = origin
		crumb.material_override = _mat(crumb_color, 0.92)
		crumbs.add_child(crumb)
		var direction := Vector3(randf_range(-0.22, 0.22), randf_range(0.08, 0.25), randf_range(-0.16, 0.16))
		var crumb_tween := create_tween()
		crumb_tween.set_parallel(true)
		crumb_tween.tween_property(crumb, "position", origin + direction + Vector3(0, 0.12, 0), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		crumb_tween.tween_property(crumb, "scale", Vector3.ZERO, 0.32).set_delay(0.12)
	var cleanup := create_tween()
	cleanup.tween_interval(0.5)
	cleanup.tween_callback(crumbs.queue_free)

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
