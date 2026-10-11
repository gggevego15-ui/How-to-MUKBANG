extends CharacterBody3D
## First-person controls: WASD move, mouse look, Space jump, Shift sprint, Esc release mouse.

@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0022
@export var touch_look_sensitivity := 0.0034
@export var blur_gain := 0.012
@export var blur_fade_speed := 5.5

var _camera: Camera3D
var _pitch := 0.0
var _camera_base_position := Vector3.ZERO
var _camera_base_fov := 78.0
var _bob_time := 0.0
var _camera_effect_weight := 0.0
var _blur_strength := 0.0
var _blur_direction := Vector2.ZERO
var _blur_material: ShaderMaterial
var _is_seated := false
var _seat_camera_offset := 0.0

# Touch controls are created at runtime, so the same scene works on desktop and Android.
var _touch_move_index := -1
var _touch_look_index := -1
var _touch_move_origin := Vector2.ZERO
var _touch_move_vector := Vector2.ZERO
var _touch_look_last := Vector2.ZERO
var _touch_ui: Control
var _stick_base: Panel
var _stick_knob: Panel
var _touch_enabled := false
var _jump_button: Button
var _sprint_button: Button
var _touch_jump_requested := false
var _touch_sprint_active := false

const STICK_RADIUS := 66.0
const STICK_MAX_TRAVEL := 48.0
const STICK_DEADZONE := 0.12

const BLUR_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float blur_amount : hint_range(0.0, 10.0) = 0.0;
uniform vec2 blur_direction = vec2(1.0, 0.0);

void fragment() {
	vec2 step_uv = blur_direction * SCREEN_PIXEL_SIZE * blur_amount;
	vec4 color = texture(screen_texture, SCREEN_UV) * 0.28;
	color += texture(screen_texture, SCREEN_UV + step_uv * 0.5) * 0.18;
	color += texture(screen_texture, SCREEN_UV - step_uv * 0.5) * 0.18;
	color += texture(screen_texture, SCREEN_UV + step_uv) * 0.12;
	color += texture(screen_texture, SCREEN_UV - step_uv) * 0.12;
	color += texture(screen_texture, SCREEN_UV + step_uv * 1.5) * 0.06;
	color += texture(screen_texture, SCREEN_UV - step_uv * 1.5) * 0.06;
	vec4 original = texture(screen_texture, SCREEN_UV);
	COLOR = mix(original, color, clamp(blur_amount / 8.0, 0.0, 0.72));
}
"""

func _ready() -> void:
	_camera = get_node_or_null("PreviewCamera") as Camera3D
	if _camera == null:
		push_error("Player controller: PreviewCamera is missing.")
		return
	_pitch = _camera.rotation.x
	_camera_base_position = _camera.position
	_camera_base_fov = _camera.fov
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_add_motion_blur_overlay()
	_setup_touch_controls()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _touch_ui != null:
		call_deferred("_relayout_touch_controls")

func _relayout_touch_controls() -> void:
	if _touch_ui == null:
		return
	_layout_action_buttons()
	if _touch_move_index == -1:
		_reset_stick_visuals()

func _process(delta: float) -> void:
	if _camera == null:
		return
	# Smooth first-person camera work: subtle walking bob, sprint FOV kick and body lean.
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := clampf(horizontal_speed / maxf(walk_speed, 0.01), 0.0, 1.35)
	var sprinting := 1.0 if (Input.is_key_pressed(KEY_SHIFT) or _touch_sprint_active) else 0.0
	_bob_time += delta * (8.5 + horizontal_speed * 1.25)
	_camera_effect_weight = move_toward(_camera_effect_weight, moving, delta * 5.0)
	var bob_y := absf(sin(_bob_time)) * 0.035 * _camera_effect_weight
	var bob_z := cos(_bob_time * 0.5) * 0.018 * _camera_effect_weight
	var sitting_offset := -0.34 if _is_seated else 0.0
	var target_position := _camera_base_position + Vector3(0.0, sitting_offset + bob_y, bob_z)
	_camera.position = _camera.position.lerp(target_position, clampf(delta * 5.0, 0.0, 1.0))
	var target_fov := _camera_base_fov + sprinting * 5.0 + moving * 1.5
	_camera.fov = lerpf(_camera.fov, target_fov, clampf(delta * 4.5, 0.0, 1.0))
	var local_side_speed := transform.basis.x.dot(Vector3(velocity.x, 0.0, velocity.z))
	var target_lean := clampf(-local_side_speed * 0.012, -0.055, 0.055) * _camera_effect_weight
	_camera.rotation.z = lerpf(_camera.rotation.z, target_lean, clampf(delta * 7.0, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _camera != null:
		var motion := (event as InputEventMouseMotion).relative
		rotation.y -= motion.x * mouse_sensitivity
		_pitch = clampf(_pitch - motion.y * mouse_sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))
		_camera.rotation.x = _pitch
		var motion_size := motion.length()
		if motion_size > 1.0:
			_blur_strength = clampf(motion_size * blur_gain, 0.0, 8.0)
			_blur_direction = Vector2(motion.x, motion.y).normalized()

func _input(event: InputEvent) -> void:
	if not _touch_enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _is_touch_button_position(touch.position):
				return
			var viewport_size := get_viewport().get_visible_rect().size
			if touch.position.x < viewport_size.x * 0.45 and touch.position.y > viewport_size.y * 0.48 and _touch_move_index == -1:
				_touch_move_index = touch.index
				_touch_move_origin = touch.position
				_touch_move_vector = Vector2.ZERO
				_update_stick_visuals(touch.position, Vector2.ZERO)
			elif touch.position.x >= viewport_size.x * 0.42 and _touch_look_index == -1:
				_touch_look_index = touch.index
				_touch_look_last = touch.position
		else:
			if touch.index == _touch_move_index:
				_touch_move_index = -1
				_touch_move_vector = Vector2.ZERO
				_reset_stick_visuals()
			elif touch.index == _touch_look_index:
				_touch_look_index = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_move_index:
			var offset := drag.position - _touch_move_origin
			if offset.length() > STICK_MAX_TRAVEL:
				offset = offset.normalized() * STICK_MAX_TRAVEL
			var strength := offset.length() / STICK_MAX_TRAVEL
			if strength <= STICK_DEADZONE:
				_touch_move_vector = Vector2.ZERO
			else:
				var scaled_strength := inverse_lerp(STICK_DEADZONE, 1.0, minf(strength, 1.0))
				_touch_move_vector = offset.normalized() * scaled_strength
			_update_stick_visuals(_touch_move_origin, offset)
		elif drag.index == _touch_look_index and _camera != null:
			var motion := drag.position - _touch_look_last
			_touch_look_last = drag.position
			rotation.y -= motion.x * touch_look_sensitivity
			_pitch = clampf(_pitch - motion.y * touch_look_sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))
			_camera.rotation.x = _pitch
			var motion_size := motion.length()
			if motion_size > 1.0:
				_blur_strength = clampf(motion_size * blur_gain * 0.45, 0.0, 8.0)
				_blur_direction = motion.normalized()

func _setup_touch_controls() -> void:
	var os_name := OS.get_name()
	_touch_enabled = OS.has_feature("mobile") or os_name == "Android" or os_name == "iOS"
	if not _touch_enabled:
		return
	_touch_ui = Control.new()
	_touch_ui.name = "TouchControls"
	_touch_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_ui.z_index = 20
	var layer := CanvasLayer.new()
	layer.name = "TouchControlsLayer"
	layer.layer = 10
	add_child(layer)
	layer.add_child(_touch_ui)
	_stick_base = _make_touch_disc("JoystickBase", Vector2(132, 132), Color(0.10, 0.14, 0.19, 0.42))
	_stick_knob = _make_touch_disc("JoystickKnob", Vector2(62, 62), Color(0.72, 0.82, 0.92, 0.72))
	_touch_ui.add_child(_stick_base)
	_touch_ui.add_child(_stick_knob)
	_reset_stick_visuals()
	_create_action_buttons()

func _create_action_buttons() -> void:
	_jump_button = _make_action_button("JUMP", Vector2(92, 64))
	_sprint_button = _make_action_button("RUN", Vector2(92, 64))
	_touch_ui.add_child(_jump_button)
	_touch_ui.add_child(_sprint_button)
	_layout_action_buttons()
	_jump_button.pressed.connect(func() -> void:
		_touch_jump_requested = true
	)
	_sprint_button.button_down.connect(func() -> void:
		_touch_sprint_active = true
		_sprint_button.modulate = Color(0.72, 1.0, 0.82, 1.0)
	)
	_sprint_button.button_up.connect(func() -> void:
		_touch_sprint_active = false
		sprint_button_reset()
	)

func _make_action_button(label: String, button_size: Vector2) -> Button:
	var button := Button.new()
	button.name = label + "Button"
	button.text = label
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.14, 0.19, 0.72)
	normal.set_corner_radius_all(18)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.78, 0.88, 1.0, 0.72)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.20, 0.31, 0.42, 0.9)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.22, 0.48, 0.36, 0.95)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	return button

func _layout_action_buttons() -> void:
	if _touch_ui == null or _jump_button == null or _sprint_button == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var scale_factor := clampf(minf(viewport_size.x / 960.0, viewport_size.y / 540.0), 0.78, 1.35)
	_jump_button.size = Vector2(92.0, 64.0) * scale_factor
	_sprint_button.size = Vector2(92.0, 64.0) * scale_factor
	_jump_button.position = Vector2(viewport_size.x - _jump_button.size.x - 28.0 * scale_factor, viewport_size.y - _jump_button.size.y - 42.0 * scale_factor)
	_sprint_button.position = Vector2(viewport_size.x - _sprint_button.size.x - 124.0 * scale_factor, viewport_size.y - _sprint_button.size.y - 28.0 * scale_factor)

func _is_touch_button_position(point: Vector2) -> bool:
	return (_jump_button != null and _jump_button.get_global_rect().has_point(point)) or (_sprint_button != null and _sprint_button.get_global_rect().has_point(point))

func sprint_button_reset() -> void:
	if _sprint_button != null:
		_sprint_button.modulate = Color.WHITE

func _make_touch_disc(label: String, disc_size: Vector2, tint: Color) -> Panel:
	var disc := Panel.new()
	disc.name = label
	disc.size = disc_size
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.corner_radius_top_left = int(disc_size.x * 0.5)
	style.corner_radius_top_right = int(disc_size.x * 0.5)
	style.corner_radius_bottom_left = int(disc_size.x * 0.5)
	style.corner_radius_bottom_right = int(disc_size.x * 0.5)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.92, 1.0, 0.42)
	disc.add_theme_stylebox_override("panel", style)
	return disc

func _update_stick_visuals(origin: Vector2, offset: Vector2) -> void:
	if _stick_base == null or _stick_knob == null:
		return
	_stick_base.position = origin - _stick_base.size * 0.5
	_stick_knob.position = origin + offset - _stick_knob.size * 0.5

func _reset_stick_visuals() -> void:
	if _stick_base == null or _stick_knob == null:
		return
	var size := get_viewport().get_visible_rect().size
	var center := Vector2(clampf(size.x * 0.115, 82.0, 130.0), size.y - clampf(size.y * 0.22, 100.0, 142.0))
	_stick_base.position = center - _stick_base.size * 0.5
	_stick_knob.position = center - _stick_knob.size * 0.5

func set_seated(seated: bool, seat_position: Vector3 = Vector3.ZERO, facing_y: float = 0.0, table_position: Vector3 = Vector3.ZERO) -> void:
	_is_seated = seated
	if seated:
		global_position = seat_position
		global_rotation.y = facing_y
		velocity = Vector3.ZERO
		set_meta("seated_table_position", table_position)
	else:
		velocity = Vector3.ZERO
		global_position += -global_transform.basis.z * -0.65 + global_transform.basis.x * 0.15
		if has_meta("seated_table_position"):
			remove_meta("seated_table_position")

func is_seated() -> bool:
	return _is_seated

func _physics_process(delta: float) -> void:
	if _is_seated:
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	if (Input.is_key_pressed(KEY_SPACE) or _touch_jump_requested) and is_on_floor():
		velocity.y = jump_velocity
	_touch_jump_requested = false

	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Also support WASD directly, independent of project InputMap configuration.
	var x_axis := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var z_axis := float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	if Vector2(x_axis, z_axis).length_squared() > 0.0:
		input_vector = Vector2(x_axis, z_axis).normalized()
	if _touch_move_index != -1:
		input_vector = _touch_move_vector

	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	var move_direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var speed := sprint_speed if (Input.is_key_pressed(KEY_SHIFT) or _touch_sprint_active) else walk_speed
	var acceleration := 18.0 if move_direction.length_squared() > 0.0 else walk_speed * 7.0
	var target_x := move_direction.x * speed
	var target_z := move_direction.z * speed
	velocity.x = move_toward(velocity.x, target_x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_z, acceleration * delta)
	move_and_slide()

	_blur_strength = move_toward(_blur_strength, 0.0, blur_fade_speed * delta)
	if _blur_material != null:
		_blur_material.set_shader_parameter("blur_amount", _blur_strength)
		_blur_material.set_shader_parameter("blur_direction", _blur_direction)

func _add_motion_blur_overlay() -> void:
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "MotionBlurLayer"
	overlay_layer.layer = 100
	add_child(overlay_layer)
	var overlay := ColorRect.new()
	overlay.name = "MotionBlur"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = BLUR_SHADER
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = shader
	_blur_material.set_shader_parameter("blur_amount", 0.0)
	overlay.material = _blur_material
	overlay_layer.add_child(overlay)
