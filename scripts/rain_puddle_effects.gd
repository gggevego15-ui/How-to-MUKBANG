extends Node3D
## Low-cost rain impacts: ten reusable ripple rings and tiny splash beads.
## No physics, no per-impact node creation, and no real-time reflection passes.

const RING_COUNT := 10
const STREET_X := 18.5
const STREET_Z_MIN := 64.0
const STREET_Z_MAX := 208.0
const GROUND_Y := 0.035

var _rng := RandomNumberGenerator.new()
var _rings: Array[MeshInstance3D] = []
var _ring_materials: Array[StandardMaterial3D] = []
var _timers: Array[float] = []
var _splashes: Array[MeshInstance3D] = []
var _splash_materials: Array[StandardMaterial3D] = []
var _enabled := true

func _ready() -> void:
	_rng.randomize()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.12
	ring_mesh.outer_radius = 0.145
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 12
	var splash_mesh := SphereMesh.new()
	splash_mesh.radius = 0.018
	splash_mesh.height = 0.036
	splash_mesh.radial_segments = 6
	splash_mesh.rings = 3
	for i in range(RING_COUNT):
		var ring := MeshInstance3D.new()
		ring.name = "RainRipple_%02d" % i
		ring.mesh = ring_mesh
		ring.position = _random_impact_position()
		ring.scale = Vector3(0.12, 1.0, 0.12)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.52, 0.78, 1.0, 0.0)
		mat.roughness = 0.25
		ring.material_override = mat
		add_child(ring)
		_rings.append(ring)
		_ring_materials.append(mat)
		_timers.append(_rng.randf_range(0.0, 0.65))
		for bead_index in range(3):
			var bead := MeshInstance3D.new()
			bead.name = "RainSplash_%02d_%d" % [i, bead_index]
			bead.mesh = splash_mesh
			bead.visible = false
			var bead_mat := StandardMaterial3D.new()
			bead_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bead_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bead_mat.albedo_color = Color(0.58, 0.82, 1.0, 0.0)
			bead.material_override = bead_mat
			add_child(bead)
			_splashes.append(bead)
			_splash_materials.append(bead_mat)

func _process(delta: float) -> void:
	if not _enabled:
		return
	for i in range(RING_COUNT):
		_timers[i] -= delta
		if _timers[i] <= 0.0:
			_timers[i] = _rng.randf_range(0.24, 0.72)
			_rings[i].position = _random_impact_position()
			_rings[i].scale = Vector3(0.12, 1.0, 0.12)
		var age := 1.0 - clampf(_timers[i] / 0.72, 0.0, 1.0)
		_rings[i].scale = Vector3.ONE * (0.12 + age * 0.8)
		_ring_materials[i].albedo_color.a = (1.0 - age) * 0.48
		for j in range(3):
			var bead_index := i * 3 + j
			var bead := _splashes[bead_index]
			var phase := age * 1.8 + float(j) * 0.34
			if age < 0.32:
				bead.visible = true
				bead.position = _rings[i].position + Vector3(cos(float(j) * TAU / 3.0) * phase * 0.09, sin(phase * PI) * 0.12, sin(float(j) * TAU / 3.0) * phase * 0.09)
				_splash_materials[bead_index].albedo_color.a = (1.0 - age / 0.32) * 0.7
			else:
				bead.visible = false

func _random_impact_position() -> Vector3:
	return Vector3(_rng.randf_range(-STREET_X, STREET_X), GROUND_Y, _rng.randf_range(STREET_Z_MIN, STREET_Z_MAX))

func set_quality(enabled: bool, effect_count: int = RING_COUNT) -> void:
	_enabled = enabled
	for i in range(RING_COUNT):
		var show_effect := enabled and i < clampi(effect_count, 0, RING_COUNT)
		_rings[i].visible = show_effect
		for j in range(3):
			_splashes[i * 3 + j].visible = false
