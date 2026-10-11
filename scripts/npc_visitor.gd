extends Node3D
## Lightweight animated mall visitor with mood labels, dialogue and a shared food queue.

var waypoints: Array[Vector3] = []
var walk_speed: float = 1.25
var outfit_color: Color = Color("4bb8e8")
var skin_color: Color = Color("d7a17e")
var start_waypoint: int = 0

# Queue visitors use a shared group per vendor so only the front person can order.
var queue_mode: bool = false
var queue_vendor_index: int = -1
var queue_slot: int = 0
var queue_waypoint_index: int = 0
var service_waypoint_index: int = 1
var queue_wait_seconds: float = 1.8
var service_wait_seconds: float = 2.5

var _target_index: int = 0
var _pause_left: float = 0.0
var _pause_action: String = ""
var _phase: float = 0.0
var _speech_left: float = 0.0
var _body: MeshInstance3D
var _left_leg: MeshInstance3D
var _right_leg: MeshInstance3D
var _left_arm: MeshInstance3D
var _right_arm: MeshInstance3D
var _emotion_label: Label3D
var _speech_label: Label3D

var _casual_lines: Array[String] = [
	"Привет!", "Куда дальше?", "Здесь так уютно.", "Пахнет вкусно!",
	"Надо выбрать что-нибудь.", "Вау, сколько еды!", "Позову друзей сюда."
]
var _queue_lines: Array[String] = [
	"Что сегодня заказать?", "Ммм, пахнет бургером!", "Я уже проголодался.",
	"Надеюсь, очередь быстрая.", "Возьму что-нибудь вкусное!"
]

func _ready() -> void:
	_target_index = posmod(start_waypoint, maxi(waypoints.size(), 1))
	_phase = float(get_instance_id() % 100) * 0.11
	set_meta("queue_waiting", false)
	set_meta("queue_serving", false)
	if queue_mode:
		add_to_group("food_queue_vendor_%d" % queue_vendor_index)

	var outfit := StandardMaterial3D.new()
	outfit.albedo_color = outfit_color
	outfit.roughness = 0.72
	outfit.metallic = 0.0
	var skin := StandardMaterial3D.new()
	skin.albedo_color = skin_color
	skin.roughness = 0.74
	var shoes := StandardMaterial3D.new()
	shoes.albedo_color = Color("202634")
	shoes.roughness = 0.68
	var hair_material := StandardMaterial3D.new()
	var hair_colors := [Color("241a17"), Color("493126"), Color("171b22"), Color("76543b")]
	hair_material.albedo_color = hair_colors[posmod(get_instance_id(), hair_colors.size())]
	hair_material.roughness = 0.82
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color("171b22")
	eye_material.roughness = 0.28
	var white_material := StandardMaterial3D.new()
	white_material.albedo_color = Color("f8f3e9")
	white_material.roughness = 0.42
	var accent_material := StandardMaterial3D.new()
	accent_material.albedo_color = outfit_color.lightened(0.25)
	accent_material.roughness = 0.6

	_body = _capsule_part("Body", 0.27, 0.78, Vector3(0, 1.02, 0), outfit)
	_capsule_part("Neck", 0.075, 0.16, Vector3(0, 1.43, 0), skin)
	_capsule_part("Head", 0.19, 0.38, Vector3(0, 1.68, 0), skin)
	_sphere_part("HairCap", Vector3(0, 1.825, 0.005), Vector3(0.36, 0.18, 0.35), hair_material)
	_sphere_part("HairBack", Vector3(0, 1.72, 0.105), Vector3(0.34, 0.30, 0.22), hair_material)
	_sphere_part("LeftEar", Vector3(-0.185, 1.68, 0), Vector3(0.075, 0.105, 0.075), skin)
	_sphere_part("RightEar", Vector3(0.185, 1.68, 0), Vector3(0.075, 0.105, 0.075), skin)
	# Eyes, brows, nose and a small smile make visitors read as people rather than blank mannequins.
	_sphere_part("LeftEyeWhite", Vector3(-0.067, 1.705, -0.164), Vector3(0.052, 0.045, 0.025), white_material)
	_sphere_part("RightEyeWhite", Vector3(0.067, 1.705, -0.164), Vector3(0.052, 0.045, 0.025), white_material)
	_sphere_part("LeftPupil", Vector3(-0.065, 1.704, -0.185), Vector3(0.024, 0.029, 0.014), eye_material)
	_sphere_part("RightPupil", Vector3(0.069, 1.704, -0.185), Vector3(0.024, 0.029, 0.014), eye_material)
	_sphere_part("LeftBrow", Vector3(-0.067, 1.755, -0.158), Vector3(0.07, 0.018, 0.022), hair_material)
	_sphere_part("RightBrow", Vector3(0.067, 1.755, -0.158), Vector3(0.07, 0.018, 0.022), hair_material)
	_sphere_part("Nose", Vector3(0, 1.665, -0.19), Vector3(0.045, 0.06, 0.045), skin)
	_sphere_part("Smile", Vector3(0, 1.615, -0.177), Vector3(0.085, 0.018, 0.018), eye_material)
	# Shirt collar, buttons and cuffs add small readable clothing details at normal play distance.
	_sphere_part("CollarLeft", Vector3(-0.085, 1.355, -0.12), Vector3(0.13, 0.09, 0.055), accent_material)
	_sphere_part("CollarRight", Vector3(0.085, 1.355, -0.12), Vector3(0.13, 0.09, 0.055), accent_material)
	for button_index in range(3):
		_sphere_part("ShirtButton_%d" % button_index, Vector3(0, 1.25 - float(button_index) * 0.13, -0.137), Vector3(0.025, 0.025, 0.018), white_material)
	_left_leg = _capsule_part("LeftLeg", 0.085, 0.48, Vector3(-0.115, 0.34, 0), shoes)
	_right_leg = _capsule_part("RightLeg", 0.085, 0.48, Vector3(0.115, 0.34, 0), shoes)
	_left_arm = _capsule_part("LeftArm", 0.075, 0.48, Vector3(-0.34, 1.02, 0), skin)
	_right_arm = _capsule_part("RightArm", 0.075, 0.48, Vector3(0.34, 1.02, 0), skin)
	_sphere_part("LeftSleeve", Vector3(-0.29, 1.17, 0), Vector3(0.17, 0.22, 0.18), outfit)
	_sphere_part("RightSleeve", Vector3(0.29, 1.17, 0), Vector3(0.17, 0.22, 0.18), outfit)
	_sphere_part("LeftHand", Vector3(-0.35, 0.77, 0), Vector3(0.12, 0.13, 0.12), skin)
	_sphere_part("RightHand", Vector3(0.35, 0.77, 0), Vector3(0.12, 0.13, 0.12), skin)
	_sphere_part("LeftShoe", Vector3(-0.115, 0.09, -0.045), Vector3(0.16, 0.12, 0.26), shoes)
	_sphere_part("RightShoe", Vector3(0.115, 0.09, -0.045), Vector3(0.16, 0.12, 0.26), shoes)

	_emotion_label = Label3D.new()
	_emotion_label.name = "Emotion"
	_emotion_label.position = Vector3(0, 2.18, 0)
	_emotion_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_emotion_label.font_size = 34
	_emotion_label.pixel_size = 0.006
	_emotion_label.outline_size = 7
	_emotion_label.modulate = Color("ffe07a")
	_emotion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_emotion_label.text = "HAPPY"
	add_child(_emotion_label)

	_speech_label = Label3D.new()
	_speech_label.name = "DialogueBubble"
	_speech_label.position = Vector3(0, 2.65, 0)
	_speech_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech_label.font_size = 26
	_speech_label.pixel_size = 0.005
	_speech_label.outline_size = 8
	_speech_label.outline_modulate = Color(0.05, 0.07, 0.1, 0.95)
	_speech_label.modulate = Color("f4f7ff")
	_speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech_label.visible = false
	add_child(_speech_label)

	if queue_mode and _target_index == queue_waypoint_index:
		set_meta("queue_waiting", true)
		_set_emotion("HUNGRY", Color("ffbf70"))
		_say(_queue_lines[posmod(queue_slot, _queue_lines.size())], 2.5)
		_pause_left = queue_wait_seconds + float(queue_slot) * 0.25
		_pause_action = "queue"

func _sphere_part(label: String, part_position: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	part.mesh = mesh
	part.position = part_position
	part.scale = dimensions
	part.material_override = material
	add_child(part)
	return part

func _capsule_part(label: String, radius: float, height: float, part_position: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 3
	part.mesh = mesh
	part.position = part_position
	part.material_override = material
	add_child(part)
	return part

func _process(delta: float) -> void:
	_phase += delta * 8.0
	if _speech_left > 0.0:
		_speech_left -= delta
		if _speech_left <= 0.0 and _speech_label != null:
			_speech_label.visible = false
	if waypoints.size() < 2:
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		_set_walk_pose(0.0)
		if _pause_left <= 0.0:
			_finish_pause()
		return

	var target := waypoints[_target_index]
	var offset := target - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.32:
		if queue_mode and _target_index == queue_waypoint_index:
			set_meta("queue_waiting", true)
			_set_emotion("HUNGRY", Color("ffbf70"))
			_say(_queue_lines[randi_range(0, _queue_lines.size() - 1)], 2.4)
			_pause_left = queue_wait_seconds + float(queue_slot) * 0.25
			_pause_action = "queue"
			return
		if queue_mode and _target_index == service_waypoint_index:
			if not _queue_can_serve():
				if _speech_left <= 0.0:
					_set_emotion("IMPATIENT", Color("ff9b61"))
					_say("Скоро моя очередь...", 1.8)
				_pause_left = 0.3
				_pause_action = "hold"
				return
			set_meta("queue_waiting", false)
			set_meta("queue_serving", true)
			_set_emotion("EXCITED", Color("a6ffc8"))
			_say("Ура! Заказываю!", service_wait_seconds)
			_pause_left = service_wait_seconds
			_pause_action = "service"
			return

		_target_index = (_target_index + 1) % waypoints.size()
		if not queue_mode and randi_range(0, 4) == 0:
			_set_emotion("CURIOUS", Color("9ce7ff"))
			_say(_casual_lines[randi_range(0, _casual_lines.size() - 1)], 2.2)
			_pause_left = 0.7 + randf() * 0.8
			_pause_action = "wander"
		return

	var direction := offset / distance
	global_position += direction * walk_speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(delta * 5.0, 1.0))
	_set_walk_pose(1.0)

func _queue_can_serve() -> bool:
	if not queue_mode:
		return true
	for other in get_tree().get_nodes_in_group("food_queue_vendor_%d" % queue_vendor_index):
		if other == self or not is_instance_valid(other):
			continue
		if bool(other.get_meta("queue_serving", false)):
			return false
		if int(other.get("queue_slot")) < queue_slot and bool(other.get_meta("queue_waiting", false)):
			return false
	return true

func _finish_pause() -> void:
	match _pause_action:
		"queue":
			_target_index = (_target_index + 1) % waypoints.size()
		"service":
			set_meta("queue_serving", false)
			_target_index = (_target_index + 1) % waypoints.size()
			_set_emotion("HAPPY", Color("a6ffc8"))
			_say("Спасибо! Отличный выбор.", 2.0)
		"hold":
			pass
		"wander":
			pass
	_pause_action = ""

func _set_emotion(label: String, color: Color) -> void:
	if _emotion_label != null:
		_emotion_label.text = label
		_emotion_label.modulate = color

func _say(line: String, duration: float) -> void:
	if _speech_label == null:
		return
	_speech_label.text = line
	_speech_label.visible = true
	_speech_left = duration

func _set_walk_pose(amount: float) -> void:
	var swing := sin(_phase) * 0.32 * amount
	if _left_leg != null:
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
		_left_arm.rotation.x = -swing * 0.7
		_right_arm.rotation.x = swing * 0.7
		_body.position.y = 1.02 + absf(sin(_phase)) * 0.035 * amount
