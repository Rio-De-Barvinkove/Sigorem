extends Node
class_name ChunkSaveManager
## Менеджер збереження/завантаження модифікацій чанків
## Зберігає воксельні зміни гравця для персистентності

## Структура даних для збереження модифікацій чанка
class ChunkModifications:
	var chunk_coords: Vector3
	var modifications: Dictionary  # Vector3 -> int (позиція -> матеріал)
	var timestamp: int  # час останньої модифікації

	var save_path: String

	func _init(coords: Vector3, path: String):
		chunk_coords = coords
		modifications = {}
		timestamp = Time.get_unix_time_from_system()
		save_path = path

	## Додати модифікацію вокселя
	func add_modification(world_pos: Vector3, material: int) -> void:
		modifications[world_pos] = material
		timestamp = Time.get_unix_time_from_system()

	## Отримати матеріал на позиції (null якщо немає модифікації)
	func get_modification(world_pos: Vector3) -> Variant:
		return modifications.get(world_pos)

	## Чи є модифікації в цьому чанку
	func has_modifications() -> bool:
		return not modifications.is_empty()

	## Зберегти на диск
	func save_to_disk() -> void:
		if modifications.is_empty():
			# Видалити файл якщо немає модифікацій
			var dir = DirAccess.open(save_path.get_base_dir())
			if dir and dir.file_exists(save_path):
				dir.remove(save_path)
			return

		var data = {
			"chunk_coords": {"x": chunk_coords.x, "y": chunk_coords.y, "z": chunk_coords.z},
			"timestamp": timestamp,
			"modifications": {}
		}

		# Конвертувати Vector3 ключі в серіалізований формат
		for pos in modifications.keys():
			var key = "%d,%d,%d" % [pos.x, pos.y, pos.z]
			data.modifications[key] = modifications[pos]

		var json = JSON.stringify(data)
		var file = FileAccess.open(save_path, FileAccess.WRITE)
		if file:
			file.store_string(json)
			file.close()
		else:
			push_error("ChunkSaveManager: Failed to save chunk ", chunk_coords, " to ", save_path)

	## Завантажити з диска
	func load_from_disk() -> bool:
		if not FileAccess.file_exists(save_path):
			return false

		var file = FileAccess.open(save_path, FileAccess.READ)
		if not file:
			push_error("ChunkSaveManager: Failed to load chunk ", chunk_coords, " from ", save_path)
			return false

		var json = file.get_as_text()
		file.close()

		var data = JSON.parse_string(json)
		if not data or typeof(data) != TYPE_DICTIONARY:
			push_error("ChunkSaveManager: Invalid JSON in ", save_path)
			return false

		modifications.clear()
		timestamp = data.get("timestamp", Time.get_unix_time_from_system())

		# Відновити модифікації
		var mods_data = data.get("modifications", {})
		for key in mods_data.keys():
			var coords_str = key.split(",")
			if coords_str.size() == 3:
				var pos = Vector3(
					float(coords_str[0]),
					float(coords_str[1]),
					float(coords_str[2])
				)
				modifications[pos] = mods_data[key]

		return true

@export_dir var save_directory: String = "user://worlds/current"
@export var world_name: String = "default_world"

var loaded_chunks: Dictionary = {}  # Vector3 -> ChunkModifications
var _world_seed: int = 0

func _ready() -> void:
	# Створити директорію для збереження
	var dir = DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive(save_directory)

func initialize(world_seed: int, world_name_param: String = "default_world") -> void:
	_world_seed = world_seed
	world_name = world_name_param
	save_directory = "user://worlds/" + world_name

	# Створити директорію
	var dir = DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive(save_directory)

	print("ChunkSaveManager: Initialized for world '", world_name, "' with seed ", _world_seed)

## Отримати шлях до файлу чанка
func _get_chunk_save_path(chunk_coords: Vector3) -> String:
	return save_directory + "/chunk_%d_%d_%d.json" % [chunk_coords.x, chunk_coords.y, chunk_coords.z]

## Завантажити модифікації чанка
func load_chunk_modifications(chunk_coords: Vector3) -> ChunkModifications:
	if loaded_chunks.has(chunk_coords):
		return loaded_chunks[chunk_coords]

	var mods = ChunkModifications.new(chunk_coords, _get_chunk_save_path(chunk_coords))
	if mods.load_from_disk():
		loaded_chunks[chunk_coords] = mods
		print("ChunkSaveManager: Loaded modifications for chunk ", chunk_coords, " (", mods.modifications.size(), " modifications)")
	else:
		loaded_chunks[chunk_coords] = mods

	return mods

## Зберегти модифікації чанка
func save_chunk_modifications(chunk_coords: Vector3) -> void:
	if not loaded_chunks.has(chunk_coords):
		return

	var mods = loaded_chunks[chunk_coords]
	mods.save_to_disk()

	if mods.has_modifications():
		print("ChunkSaveManager: Saved modifications for chunk ", chunk_coords, " (", mods.modifications.size(), " modifications)")
	else:
		print("ChunkSaveManager: Cleared empty modifications for chunk ", chunk_coords)

## Додати модифікацію вокселя
func add_voxel_modification(world_pos: Vector3, material: int) -> void:
	# Конвертувати світові координати в координати чанка
	var chunk_coords = _world_to_chunk(world_pos)
	var mods = load_chunk_modifications(chunk_coords)
	mods.add_modification(world_pos, material)

## Отримати модифікацію вокселя (null якщо немає)
func get_voxel_modification(world_pos: Vector3) -> Variant:
	var chunk_coords = _world_to_chunk(world_pos)
	if not loaded_chunks.has(chunk_coords):
		return null

	var mods = loaded_chunks[chunk_coords]
	return mods.get_modification(world_pos)

## Чи є модифікації в чанку
func chunk_has_modifications(chunk_coords: Vector3) -> bool:
	if not loaded_chunks.has(chunk_coords):
		return false
	return loaded_chunks[chunk_coords].has_modifications()

## Вивантажити чанк із пам'яті (але зберегти на диск)
func unload_chunk(chunk_coords: Vector3) -> void:
	if loaded_chunks.has(chunk_coords):
		var mods = loaded_chunks[chunk_coords]
		mods.save_to_disk()
		loaded_chunks.erase(chunk_coords)
		print("ChunkSaveManager: Unloaded chunk ", chunk_coords, " from memory")

## Застосувати модифікації до чанка після генерації
func apply_modifications_to_chunk(terrain: VoxdotTerrain, chunk_coords: Vector3) -> void:
	if not loaded_chunks.has(chunk_coords):
		return

	var mods = loaded_chunks[chunk_coords]
	if not mods.has_modifications():
		return

	print("ChunkSaveManager: Applying ", mods.modifications.size(), " modifications to chunk ", chunk_coords)

	# Застосувати кожну модифікацію
	for world_pos in mods.modifications.keys():
		var material = mods.modifications[world_pos]
		# Використовуємо place_edit для відновлення вокселя
		# Розмір 0.1 - базовий розмір вокселя
		terrain.place_edit(Vector3(0.1, 0.1, 0.1), world_pos, material, 1 if material > 0 else 0)

## Конвертувати світові координати в координати чанка
func _world_to_chunk(world_pos: Vector3) -> Vector3:
	const CHUNK_SIZE = 6.2  # Приблизний розмір чанка в метрах (62 * 0.1)
	return Vector3(
		floor(world_pos.x / CHUNK_SIZE),
		floor(world_pos.y / CHUNK_SIZE),
		floor(world_pos.z / CHUNK_SIZE)
	)

## Зберегти всі незбережені чанки
func save_all_chunks() -> void:
	print("ChunkSaveManager: Saving all chunks...")
	for chunk_coords in loaded_chunks.keys():
		save_chunk_modifications(chunk_coords)
	print("ChunkSaveManager: All chunks saved")

## Очистити всі дані (для нового світу)
func clear_all_data() -> void:
	loaded_chunks.clear()

	var dir = DirAccess.open(save_directory)
	if dir:
		# Рекурсивно видалити всі файли
		_clear_directory(dir, save_directory)

	print("ChunkSaveManager: All data cleared")

func _clear_directory(dir: DirAccess, path: String) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			var subdir_path = path + "/" + file_name
			var subdir = DirAccess.open(subdir_path)
			if subdir:
				_clear_directory(subdir, subdir_path)
				DirAccess.remove_absolute(subdir_path)
		else:
			DirAccess.remove_absolute(path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

## Отримати статистику
func get_stats() -> Dictionary:
	var total_modifications = 0
	var chunks_with_mods = 0

	for mods in loaded_chunks.values():
		if mods.has_modifications():
			total_modifications += mods.modifications.size()
			chunks_with_mods += 1

	return {
		"loaded_chunks": loaded_chunks.size(),
		"chunks_with_modifications": chunks_with_mods,
		"total_modifications": total_modifications
	}
