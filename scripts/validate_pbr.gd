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
			var import_file := FileAccess.open(path + ".import", FileAccess.READ)
			if import_file == null:
				errors.append("Missing import settings: " + path + ".import")
				continue
			var settings := import_file.get_as_text()
			import_file.close()
			if not settings.contains("mipmaps/generate=true"):
				errors.append("Mipmaps are not enabled for " + path)
			if not settings.contains("compress/mode=2"):
				errors.append("VRAM compression is not enabled for " + path)
			if map_name == "normal" and not settings.contains("compress/normal_map=1"):
				errors.append("Normal-map compression mode is not enabled for " + path)
	if not errors.is_empty():
		for error_text in errors:
			push_error(error_text)
		quit(1)
		return
	print("PBR validation passed: %d imported 2K textures; mipmaps and VRAM compression enabled." % imported_count)
	quit(0)
