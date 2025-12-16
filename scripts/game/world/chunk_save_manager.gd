extends Node
class_name ChunkSaveManager
## Менеджер збереження/завантаження модифікацій чанків
## Зберігає воксельні зміни гравця для персистентності

@export_dir var save_directory: String = "user://worlds/current"
@export var world_name: String = "default_world"

# Структура для збереження модифікацій чанка
var loaded_chunks: Dictionary = {}  # Vector3 -> Dictionary (chunk data)
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
func load_chunk_modifications(chunk_coords: Vector3) -> Dictionary:
	if loaded_chunks.has(chunk_coords):
		return loaded_chunks[chunk_coords]

	var chunk_data = {
		"chunk_coords": chunk_coords,
		"modifications": {},  # Vector3 -> int
		"timestamp": Time.get_unix_time_from_system(),
		"save_path": _get_chunk_save_path(chunk_coords)
	}

	# Спробувати завантажити з диска
	if _load_chunk_from_disk(chunk_data):
		print("ChunkSaveManager: Loaded modifications for chunk ", chunk_coords, " (", chunk_data.modifications.size(), " modifications)")
	else:
		print("ChunkSaveManager: Created new chunk data for ", chunk_coords)

	loaded_chunks[chunk_coords] = chunk_data
	return chunk_data

## Зберегти модифікації чанка
func save_chunk_modifications(chunk_coords: Vector3) -> void:
	if not loaded_chunks.has(chunk_coords):
		return

	var chunk_data = loaded_chunks[chunk_coords]
	_save_chunk_to_disk(chunk_data)

	var mod_count = chunk_data.modifications.size()
	if mod_count > 0:
		print("ChunkSaveManager: Saved modifications for chunk ", chunk_coords, " (", mod_count, " modifications)")
	else:
		print("ChunkSaveManager: Cleared empty modifications for chunk ", chunk_coords)

## Додати модифікацію вокселя
func add_voxel_modification(world_pos: Vector3, material: int) -> void:
	# Конвертувати світові координати в координати чанка
	var chunk_coords = _world_to_chunk(world_pos)
	var chunk_data = load_chunk_modifications(chunk_coords)
	chunk_data.modifications[world_pos] = material
	chunk_data.timestamp = Time.get_unix_time_from_system()

## Отримати модифікацію вокселя (null якщо немає)
func get_voxel_modification(world_pos: Vector3) -> Variant:
	var chunk_coords = _world_to_chunk(world_pos)
	if not loaded_chunks.has(chunk_coords):
		return null

	var chunk_data = loaded_chunks[chunk_coords]
	return chunk_data.modifications.get(world_pos)

## Чи є модифікації в чанку
func chunk_has_modifications(chunk_coords: Vector3) -> bool:
	if not loaded_chunks.has(chunk_coords):
		return false
	return not loaded_chunks[chunk_coords].modifications.is_empty()

## Вивантажити чанк із пам'яті (але зберегти на диск)
func unload_chunk(chunk_coords: Vector3) -> void:
	if loaded_chunks.has(chunk_coords):
		var chunk_data = loaded_chunks[chunk_coords]
		_save_chunk_to_disk(chunk_data)
		loaded_chunks.erase(chunk_coords)
		print("ChunkSaveManager: Unloaded chunk ", chunk_coords, " from memory")

## Застосувати модифікації до чанка після генерації
func apply_modifications_to_chunk(terrain: VoxdotTerrain, chunk_coords: Vector3) -> void:
	if not loaded_chunks.has(chunk_coords):
		return

	var chunk_data = loaded_chunks[chunk_coords]
	if chunk_data.modifications.is_empty():
		return

	print("ChunkSaveManager: Applying ", chunk_data.modifications.size(), " modifications to chunk ", chunk_coords)

	# Застосувати кожну модифікацію
	for world_pos in chunk_data.modifications.keys():
		var material = chunk_data.modifications[world_pos]
		# Використовуємо place_edit для відновлення вокселя
		# Розмір 0.1 - базовий розмір вокселя
		terrain.place_edit(Vector3(0.1, 0.1, 0.1), world_pos, material, 1 if material > 0 else 0)

## Завантажити chunk data з диска
func _load_chunk_from_disk(chunk_data: Dictionary) -> bool:
	var save_path = chunk_data.save_path
	if not FileAccess.file_exists(save_path):
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("ChunkSaveManager: Failed to load chunk ", chunk_data.chunk_coords, " from ", save_path)
		return false

	var json = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json)
	if not data or typeof(data) != TYPE_DICTIONARY:
		push_error("ChunkSaveManager: Invalid JSON in ", save_path)
		return false

	chunk_data.timestamp = data.get("timestamp", Time.get_unix_time_from_system())

	# Відновити модифікації
	var mods_data = data.get("modifications", {})
	chunk_data.modifications.clear()
	for key in mods_data.keys():
		var coords_str = key.split(",")
		if coords_str.size() == 3:
			var pos = Vector3(
				float(coords_str[0]),
				float(coords_str[1]),
				float(coords_str[2])
			)
			chunk_data.modifications[pos] = mods_data[key]

	return true

## Зберегти chunk data на диск
func _save_chunk_to_disk(chunk_data: Dictionary) -> void:
	var save_path = chunk_data.save_path
	if chunk_data.modifications.is_empty():
		# Видалити файл якщо немає модифікацій
		var dir = DirAccess.open(save_path.get_base_dir())
		if dir and dir.file_exists(save_path):
			dir.remove(save_path)
		return

	var data = {
		"chunk_coords": {
			"x": chunk_data.chunk_coords.x,
			"y": chunk_data.chunk_coords.y,
			"z": chunk_data.chunk_coords.z
		},
		"timestamp": chunk_data.timestamp,
		"modifications": {}
	}

	# Конвертувати Vector3 ключі в серіалізований формат
	for pos in chunk_data.modifications.keys():
		var key = "%d,%d,%d" % [pos.x, pos.y, pos.z]
		data.modifications[key] = chunk_data.modifications[pos]

	var json = JSON.stringify(data)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
	else:
		push_error("ChunkSaveManager: Failed to save chunk ", chunk_data.chunk_coords, " to ", save_path)

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

	for chunk_data in loaded_chunks.values():
		if not chunk_data.modifications.is_empty():
			total_modifications += chunk_data.modifications.size()
			chunks_with_mods += 1

	return {
		"loaded_chunks": loaded_chunks.size(),
		"chunks_with_modifications": chunks_with_mods,
		"total_modifications": total_modifications
	}
