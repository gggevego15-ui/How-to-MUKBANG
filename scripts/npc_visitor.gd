extends Node3D
## Lightweight animated visitor for the mobile mall scene.
## Visitors use waypoint routes and intentionally have no physics bodies.

var waypoints: Array[Vector3] = []
var walk_speed: float = 1.25
var outfit_color: Color = Color("4bb8e8")
var skin_color: Color = Color("d7a17e")
var start_waypoint: int = 0

var _target_index: int = 0
var _pause_left: float = 0.0
var _phase: float = 0.0
var _body: MeshInstance3D
var _left_leg: MeshInstance3D
var _right_leg: MeshInstance3D
var _left_arm: MeshInstance3D
var _right_arm: MeshInstance3D
var _outfit_material: StandardMaterial3D

func _ready() -> void:
	_target_index = posmod(start_waypoint, maxi(waypoints.size(), 1))
	_phase = float(get_instance_id() % 100) * 0.11
	_outfit_material = StandardMaterial3D.new()
	_outfit_material.albedo_color = outfit_color
	_outfit_material.roughness = 0.82
	var skin := StandardMaterial3D.new()
	skin.albedo_color = skin_color
	skin.roughness = 0.9
	var shoes := StandardMaterial3D.new()
	shoes.albedo_color = Color("202634")
	shoes.roughness = 0.8

	_body = _capsule_part("Body", 0.27, 0.78, Vector3(0, 1.02, 0), _outfit_material)
	_capsule_part("Head", 0.19, 0.38, Vector3(0, 1.68, 0), skin)
	_capsule_part("Hair", 0.195, 0.12, Vector3(0, 1.84, -0.025), shoes)
	_left_leg = _capsule_part("LeftLeg", 0.085, 0.48, Vector3(-0.115, 0.34, 0), shoes)
	_right_leg = _capsule_part("RightLeg", 0.085, 0.48, Vector3(0.115, 0.34, 0), shoes)
	_left_arm = _capsule_part("LeftArm", 0.075, 0.48, Vector3(-0.34, 1.02, 0), skin)
	_right_arm = _capsule_part("RightArm", 0.075, 0.48, Vector3(0.34, 1.02, 0), skin)
	# A small contrasting panel makes silhouettes readable in the dim mall.
	var badge := MeshInstance3D.new()
	badge.name = "ShirtDetail"
	var badge_mesh := BoxMesh.new()
	badge_mesh.size = Vector3(0.09, 0.18, 0.025)
	badge.mesh = badge_mesh
	badge.position = Vector3(0, 1.08, -0.276)
	badge.material_override = shoes
	add_child(badge)

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
	if waypoints.size() < 2:
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		_set_walk_pose(0.0)
		return
	var target := waypoints[_target_index]
	var offset := target - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.32:
		_target_index = (_target_index + 1) % waypoints.size()
		# Short pauses feel like people looking at menus or window displays.
		if int(_target_index + get_instance_id()) % 4 == 0:
			_pause_left = 0.65
		return
	var direction := offset / distance
	global_position += direction * walk_speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(delta * 5.0, 1.0))
	_set_walk_pose(1.0)

func _set_walk_pose(amount: float) -> void:
	var swing := sin(_phase) * 0.32 * amount
	if _left_leg != null:
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
		_left_arm.rotation.x = -swing * 0.7
		_right_arm.rotation.x = swing * 0.7
		_body.position.y = 1.02 + absf(sin(_phase)) * 0.035 * amount
