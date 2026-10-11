extends Node
## Runtime quality presets for Android. Uses low-cost scene changes and render scaling.

const PROFILES := ["Battery saver", "Balanced", "High"]
const PROFILE_LABELS := ["ЭКО", "БАЛАНС", "ВЫСОКО"]
const SETTINGS_PATH := "user://graphics.cfg"

var profile_index := 1
var _fps_label: Label
var _quality_button: Button
var _fps_elapsed := 0.0
var _fps_frames := 0
var _world_environment: WorldEnvironment
var _rain: CPUParticles3D
var _omni_lights: Array[OmniLight3D] = []
var _directional_lights: Array[DirectionalLight3D] = []
var _visitors: Array[Node] = []

func _ready() -> void:
	_collect_nodes(get_parent())
	_load_profile()
	_apply_profile()
	_build_overlay()

func _process(delta: float) -> void:
	_fps_elapsed += delta
	_fps_frames += 1
	if _fps_elapsed >= 1.0:
		if _fps_label != null:
			_fps_label.text = "%d FPS  •  %s" % [int(round(float(_fps_frames) / _fps_elapsed)), PROFILE_LABELS[profile_index]]
		_fps_elapsed = 0.0
		_fps_frames = 0

func _collect_nodes(root: Node) -> void:
	for child in root.get_children():
		if child is WorldEnvironment:
			_world_environment = child as WorldEnvironment
		elif child is CPUParticles3D and child.name == "NightRain":
			_rain = child as CPUParticles3D
		elif child is OmniLight3D:
			_omni_lights.append(child as OmniLight3D)
		elif child is DirectionalLight3D:
			_directional_lights.append(child as DirectionalLight3D)
		if child.name.begins_with("MallVisitor_") or child.name.begins_with("FoodQueue_"):
			_visitors.append(child)
		_collect_nodes(child)

func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		profile_index = clampi(int(config.get_value("graphics", "profile", 1)), 0, 2)
	elif OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS":
		profile_index = 1
	else:
		profile_index = 2

func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "profile", profile_index)
	config.save(SETTINGS_PATH)

func _apply_profile() -> void:
	var mobile := OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS"
	var viewport := get_viewport()
	match profile_index:
		0:
			Engine.max_fps = 30 if mobile else 45
			viewport.scaling_3d_scale = 0.72
			_set_glow(false)
			_set_light_budget(4)
			_set_rain(100)
			_set_visitor_processing(false)
		1:
			Engine.max_fps = 45 if mobile else 60
			viewport.scaling_3d_scale = 0.85 if mobile else 1.0
			_set_glow(true)
			_set_light_budget(8)
			_set_rain(220)
			_set_visitor_processing(true)
		2:
			Engine.max_fps = 60
			viewport.scaling_3d_scale = 1.0
			_set_glow(true)
			_set_light_budget(_omni_lights.size())
			_set_rain(500)
			_set_visitor_processing(true)
	if _quality_button != null:
		_quality_button.text = "ГРАФИКА: " + PROFILE_LABELS[profile_index]

func _set_glow(enabled: bool) -> void:
	if _world_environment != null and _world_environment.environment != null:
		_world_environment.environment.glow_enabled = enabled

func _set_light_budget(count: int) -> void:
	for i in range(_omni_lights.size()):
		var light := _omni_lights[i]
		light.visible = i < count
		light.shadow_enabled = false
	for light in _directional_lights:
		light.shadow_enabled = profile_index == 2

func _set_rain(amount: int) -> void:
	if _rain == null:
		return
	_rain.amount = amount
	_rain.emitting = amount > 0

func _set_visitor_processing(enabled: bool) -> void:
	for visitor in _visitors:
		visitor.set_process(enabled)
		visitor.set_physics_process(enabled)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GraphicsOverlay"
	layer.layer = 50
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_fps_label = Label.new()
	_fps_label.name = "PerformanceReadout"
	_fps_label.position = Vector2(12, 12)
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0, 0.9))
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fps_label)

	_quality_button = Button.new()
	_quality_button.name = "GraphicsPresetButton"
	_quality_button.text = "ГРАФИКА: " + PROFILE_LABELS[profile_index]
	_quality_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_quality_button.position = Vector2(-190, 12)
	_quality_button.size = Vector2(178, 42)
	_quality_button.focus_mode = Control.FOCUS_NONE
	_quality_button.add_theme_font_size_override("font_size", 13)
	_quality_button.pressed.connect(_cycle_profile)
	root.add_child(_quality_button)

func _cycle_profile() -> void:
	profile_index = (profile_index + 1) % PROFILES.size()
	_apply_profile()
	_save_profile()
