extends Node
## Proximity-based interactions shared by desktop and Android.
## Press E or tap the action button while facing a nearby door or neon sign.

var _player: CharacterBody3D
var _camera: Camera3D
var _prompt: Label
var _toast: Label
var _touch_button: Button
var _active_target: Node3D
var _toast_generation := 0
var _touch_mode := false

func _ready() -> void:
	_player = get_parent().get_node_or_null("Player") as CharacterBody3D
	if _player == null:
		push_error("WorldInteractions: Player node not found.")
		return
	_camera = _player.get_node_or_null("PreviewCamera") as Camera3D
	_touch_mode = OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS"
	_build_interaction_ui()
	get_viewport().size_changed.connect(_layout_touch_button)

func _process(_delta: float) -> void:
	if _player == null or _camera == null:
		return
	_active_target = _find_target()
	if _active_target == null:
		_prompt.visible = false
		if _touch_button != null:
			_touch_button.visible = false
		return
	var label := str(_active_target.get_meta("interaction_label", "Взаимодействовать"))
	_prompt.text = "E  ·  " + label
	_prompt.visible = true
	if _touch_button != null:
		_touch_button.text = label
		_touch_button.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _active_target != null:
			_interact()
			get_viewport().set_input_as_handled()

func _find_target() -> Node3D:
	var best: Node3D
	var best_distance := 999.0
	var origin := _player.global_position + Vector3.UP * 1.2
	var forward := -_camera.global_transform.basis.z
	for candidate in get_tree().get_nodes_in_group("world_interactable"):
		if not candidate is Node3D or not is_instance_valid(candidate):
			continue
		var item := candidate as Node3D
		var offset := item.global_position - origin
		var distance := offset.length()
		if distance > 4.0 or distance < 0.01:
			continue
		if forward.dot(offset.normalized()) < 0.25:
			continue
		if distance < best_distance:
			best = item
			best_distance = distance
	return best

func _interact() -> void:
	if _active_target == null or not is_instance_valid(_active_target):
		return
	match str(_active_target.get_meta("interaction_type", "")):
		"door":
			var door := _active_target
			var is_open := absf(door.rotation.y) > 0.6
			var target_angle := 0.0 if is_open else (PI * 0.5)
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(door, "rotation:y", target_angle, 0.42)
			_show_toast("Дверь открывается" if not is_open else "Дверь закрывается")
		"sign":
			_active_target.visible = not _active_target.visible
			_show_toast("Неон включён" if _active_target.visible else "Неон выключен")
	_active_target = null

func _build_interaction_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "InteractionUI"
	layer.layer = 30
	add_child(layer)
	_prompt = Label.new()
	_prompt.name = "InteractionPrompt"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(0, 74)
	_prompt.size = Vector2(1280, 48)
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color("e9f8ff"))
	_prompt.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_prompt.add_theme_constant_override("shadow_offset_x", 2)
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_prompt.visible = false
	layer.add_child(_prompt)
	_toast = Label.new()
	_toast.name = "InteractionToast"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(0, 126)
	_toast.size = Vector2(1280, 42)
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color("7de4ff"))
	_toast.visible = false
	layer.add_child(_toast)
	if _touch_mode:
		_touch_button = Button.new()
		_touch_button.name = "InteractButton"
		_touch_button.custom_minimum_size = Vector2(270, 66)
		_touch_button.focus_mode = Control.FOCUS_NONE
		_touch_button.add_theme_font_size_override("font_size", 18)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.10, 0.16, 0.88)
		style.border_color = Color("65d9ff")
		style.set_border_width_all(2)
		style.set_corner_radius_all(16)
		_touch_button.add_theme_stylebox_override("normal", style)
		_touch_button.add_theme_color_override("font_color", Color("f1fbff"))
		_touch_button.visible = false
		_touch_button.pressed.connect(_interact)
		layer.add_child(_touch_button)
		_layout_touch_button()

func _layout_touch_button() -> void:
	if _touch_button == null:
		return
	var size := get_viewport().get_visible_rect().size
	_touch_button.position = Vector2(size.x - 300.0, size.y - 292.0)

func _show_toast(message: String) -> void:
	_toast_generation += 1
	var generation := _toast_generation
	_toast.text = message
	_toast.visible = true
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if generation == _toast_generation and is_instance_valid(_toast):
			_toast.visible = false
	)
