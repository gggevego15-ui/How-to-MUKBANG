extends Node3D
## Low-cost animated rain ripples: 12 shared torus meshes, no particles or physics.

const RING_COUNT := 12
const CYCLE_SECONDS := 1.7
var rings: Array[MeshInstance3D] = []
var elapsed := 0.0
var centers: Array[Vector3] = []
var ripple_material: StandardMaterial3D

func _ready() -> void:
	set_process(true)
	ripple_material = StandardMaterial3D.new()
	ripple_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ripple_material.albedo_color = Color(0.55, 0.78, 0.95, 0.52)
	ripple_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ripple_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ripple_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	ripple_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(RING_COUNT):
		var torus := TorusMesh.new()
		torus.inner_radius = 0.13
		torus.outer_radius = 0.17
		torus.rings = 4
		torus.ring_segments = 8
		var ring := MeshInstance3D.new()
		ring.name = "RainRipple_%02d" % i
		ring.mesh = torus
		ring.material_override = ripple_material
		ring.rotation_degrees.x = 90.0
		ring.visible = false
		add_child(ring)
		rings.append(ring)

func configure(puddle_positions: Array[Vector3]) -> void:
	centers = puddle_positions
	for i in range(rings.size()):
		if centers.is_empty():
			break
		rings[i].position = centers[i % centers.size()]

func _process(delta: float) -> void:
	if centers.is_empty():
		return
	elapsed += delta
	for i in range(rings.size()):
		var phase := fposmod(elapsed / CYCLE_SECONDS + float(i) / float(RING_COUNT), 1.0)
		var ring := rings[i]
		var center := centers[i % centers.size()]
		# Each ring expands, fades, then reuses the same mesh instance.
		ring.position = center
		ring.visible = phase < 0.88
		var radius := lerpf(0.16, 0.78, phase)
		ring.scale = Vector3(radius, radius, radius)
		var color := Color(0.55, 0.78, 0.95, (1.0 - phase) * 0.48)
		ripple_material.albedo_color = color
