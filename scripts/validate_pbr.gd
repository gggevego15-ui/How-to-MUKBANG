extends SceneTree

const FAMILIES := ["food", "wood", "ceramic", "metal"]
const MAPS := ["basecolor", "roughness", "normal", "metallic"]
const EXPECTED_SIZE := 2048

func _initialize() -> void:
	call_deferred("_validate_textures")

func _validate_textures() -> void:
	var errors: Array[String] = []
	var imported_count := 0
	for family in FAMILIES:
		for map_name in MAPS:
			var path := "res://assets/textures/pbr/%s_%s_2k.svg" % [family, map_name]
			var texture := load(path) as Texture2D
			if texture == null:
				errors.append("Could not import texture: " + path)
				continue
			imported_count += 1
			if texture.get_width() != EXPECTED_SIZE or texture.get_height() != EXPECTED_SIZE:
				errors.append("%s has unexpected size %dx%d" % [path, texture.get_width(), texture.get_height()])
	if not errors.is_empty():
		for error_text in errors:
			push_error(error_text)
		quit(1)
		return
	print("PBR import validation passed: %d textures at %dx%d." % [imported_count, EXPECTED_SIZE, EXPECTED_SIZE])
	quit(0)
