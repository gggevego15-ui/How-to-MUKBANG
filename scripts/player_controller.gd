extends CharacterBody3D
## First-person controls: WASD move, mouse look, Space jump, Shift sprint, Esc release mouse.

@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0022
@export var blur_gain := 0.012
@export var blur_fade_speed := 5.5

var _camera: Camera3D
var _pitch := 0.0
var _blur_strength := 0.0
var _blur_direction := Vector2.ZERO
var _blur_material: ShaderMaterial

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
const TOUCH_LOOK_SENSITIVITY := 0.0034

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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_add_motion_blur_overlay()
	_setup_touch_controls()

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
			_touch_move_vector = Vector2(offset.x / STICK_MAX_TRAVEL, offset.y / STICK_MAX_TRAVEL)
			_update_stick_visuals(_touch_move_origin, offset)
		elif drag.index == _touch_look_index and _camera != null:
			var motion := drag.position - _touch_look_last
			_touch_look_last = drag.position
			rotation.y -= motion.x * TOUCH_LOOK_SENSITIVITY
			_pitch = clampf(_pitch - motion.y * TOUCH_LOOK_SENSITIVITY, deg_to_rad(-88.0), deg_to_rad(88.0))
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

func _create_action_buttons() -> void:
\t_jump_button = _make_action_button("JUMP", Vector2(92, 64))
\t_sprint_button = _make_action_button("RUN", Vector2(92, 64))
\t_touch_ui.add_child(_jump_button)
\t_touch_ui.add_child(_sprint_button)
\t_layout_action_buttons()
\t_jump_button.pressed.connect(func() -> void:
\t\t_touch_jump_requested = true
\t)
\t_sprint_button.button_down.connect(func() -> void:
\t\t_touch_sprint_active = true
\t\t_sprint_button.modulate = Color(0.72, 1.0, 0.82, 1.0)
\t)
\t_sprint_button.button_up.connect(func() -> void:
\t\t_touch_sprint_active = false
\t\tsprint_button_reset()
\t)

func _make_action_button(label: String, button_size: Vector2) -> Button:
\tvar button := Button.new()
\tbutton.name = label + "Button"
\tbutton.text = label
\tbutton.size = button_size
\tbutton.focus_mode = Control.FOCUS_NONE
\tbutton.add_theme_font_size_override("font_size", 18)
\tvar normal := StyleBoxFlat.new()
\tnormal.bg_color = Color(0.10, 0.14, 0.19, 0.72)
\tnormal.corner_radius_top_left = 18
\tnormal.corner_radius_top_right = 18
\tnormal.corner_radius_bottom_left = 18
\tnormal.corner_radius_bottom_right = 18
\tnormal.border_width_left = 2
\tnormal.border_width_top = 2
\tnormal.border_width_right = 2
\tnormal.border_width_bottom = 2
\tnormal.border_color = Color(0.78, 0.88, 1.0, 0.72)
\tvar hover := normal.duplicate() as StyleBoxFlat
\thover.bg_color = Color(0.20, 0.31, 0.42, 0.9)
\tvar pressed := normal.duplicate() as StyleBoxFlat
\tpressed.bg_color = Color(0.22, 0.48, 0.36, 0.95)
\tbutton.add_theme_stylebox_override("normal", normal)
\tbutton.add_theme_stylebox_override("hover", hover)
\tbutton.add_theme_stylebox_override("pressed", pressed)
\tbutton.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
\tbutton.add_theme_color_override("font_hover_color", Color.WHITE)
\tbutton.add_theme_color_override("font_pressed_color", Color.WHITE)
\treturn button

func _layout_action_buttons() -> void:
\tif _touch_ui == null or _jump_button == null or _sprint_button == null:
\t\treturn
\tvar viewport_size := get_viewport().get_visible_rect().size
\t_jump_button.position = Vector2(viewport_size.x - 116.0, viewport_size.y - 198.0)
\t_sprint_button.position = Vector2(viewport_size.x - 224.0, viewport_size.y - 112.0)

func _is_touch_button_position(point: Vector2) -> bool:
\treturn (_jump_button != null and _jump_button.get_global_rect().has_point(point)) or (_sprint_button != null and _sprint_button.get_global_rect().has_point(point))

func sprint_button_reset() -> void:
\tif _sprint_button != null:
\t\t_sprint_button.modulate = Color.WHITE

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
	var center := Vector2(104.0, size.y - 112.0)
	_stick_base.position = center - _stick_base.size * 0.5
	_stick_knob.position = center - _stick_knob.size * 0.5

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Also support WASD directly, independent of project InputMap configuration.
	var x_axis := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var z_axis := float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	if Vector2(x_axis, z_axis).length_squared() > 0.0:
		input_vector = Vector2(x_axis, z_axis).normalized()
	if _touch_move_index != -1:
		input_vector = _touch_move_vector

	var move_direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var speed := sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	if move_direction.length_squared() > 0.0:
		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 7.0 * delta)
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
