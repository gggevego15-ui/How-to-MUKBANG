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
