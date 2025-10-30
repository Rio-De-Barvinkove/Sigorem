extends Node
# Менеджер ресурсів (остаточна версія, на базі простої)

signal batch_loading_progress(current: int, total: int)
signal batch_loading_complete()

var resource_cache = {}

func load_resource(path: String) -> Resource:
	if ResourceLoader.exists(path):
		var resource = resource_cache.get(path, null)
		if resource:
			return resource
		resource = load(path)
		if resource:
			resource_cache[path] = resource
			return resource
	return null

func preload_resources_by_type(resource_type: String):
	# Заглушка для майбутнього розширення
	emit_signal("batch_loading_complete")

func get_texture(name: String) -> Texture2D:
	var path = "res://assets/textures/" + name + ".png"
	var resource = load_resource(path)
	if resource is Texture2D:
		return resource
	return null


