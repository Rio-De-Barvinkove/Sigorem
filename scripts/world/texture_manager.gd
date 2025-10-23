extends Node

# Singleton for managing texture loading and access.
var textures = {}

func _ready():
	load_all_textures()

func load_all_textures():
	load_textures_recursively("res://assets/textures")

func load_textures_recursively(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir() and not file_name.begins_with("."):
				load_textures_recursively(full_path)
			elif file_name.ends_with(".png") or file_name.ends_with(".svg"):
				var texture_name = file_name.get_slice(".", 0)
				var texture = load(full_path)
				if texture:
					textures[texture_name] = texture
			file_name = dir.get_next()
	else:
		print("Could not open directory: " + path)

func get_texture(name: String):
	if textures.has(name):
		return textures[name]
	else:
		print("Texture not found: %s" % name)
		return null
