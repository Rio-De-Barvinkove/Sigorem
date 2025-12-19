extends Node
class_name ChunkSaveManager
## Менеджер збереження/завантаження модифікацій чанків
## Зберігає воксельні зміни гравця для персистентності

@export_dir var save_directory: String = "user://worlds/current"
@export var world_name: String = "default_world"
@export var voxel_scale: float = 0.1

# Структура для збереження модифікацій чанка
var loaded_chunks: Dictionary = {}  # Vector3 -> Dictionary (chunk data)
var dirty_chunks: Dictionary = {}    # Vector3 -> timestamp (змінені чанки)
var _world_seed: int = 0
var _world_version: String = "1.0"
var _auto_save_timer: float = 0.0
var _background_save_thread: Thread = null
var _save_queue: Array = []  # Черга чанків для збереження

func _ready() -> void:
	# Створити директорію для збереження
	var dir = DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive(save_directory)
		dir.make_dir_recursive(save_directory + "/region")  # Директорія для регіонів


func _exit_tree() -> void:
	## Очистити ресурси при видаленні ноду
	# Завершити фоновий потік якщо активний
	if _background_save_thread:
		_save_queue.clear()  # Очистити чергу щоб потік завершився швидше
		_background_save_thread.wait_to_finish()
		_background_save_thread = null
	
	# Зберегти всі dirty chunks перед виходом
	if not dirty_chunks.is_empty():
		for chunk_coords in dirty_chunks.keys():
			if loaded_chunks.has(chunk_coords):
				save_chunk_modifications(chunk_coords)

func _process(delta: float) -> void:
	# Автозбереження кожні TerrainConstants.AUTO_SAVE_INTERVAL секунд
	_auto_save_timer += delta
	if _auto_save_timer >= TerrainConstants.AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		_auto_save_dirty_chunks()

	# Обробити чергу background saving (якщо немає активного потоку)
	if _background_save_thread == null and not _save_queue.is_empty():
		_start_background_save()

func _auto_save_dirty_chunks() -> void:
	if dirty_chunks.is_empty():
		return

	# Видалити надмірне логування

	# Додати всі dirty чанки в чергу збереження
	for chunk_coords in dirty_chunks.keys():
		if not _save_queue.has(chunk_coords):
			_save_queue.append(chunk_coords)

	dirty_chunks.clear()

func _start_background_save() -> void:
	if _save_queue.is_empty() or _background_save_thread != null:
		return

	_background_save_thread = Thread.new()
	_background_save_thread.start(_background_save_worker.bind(_save_queue.duplicate()))

func _background_save_worker(queue: Array) -> void:
	# Видалити надмірне логування
	for chunk_coords in queue:
		# Перевірити чи не було видалено нод
		if is_instance_valid(self) and loaded_chunks.has(chunk_coords):
			save_chunk_modifications(chunk_coords)
		else:
			break  # Вийти якщо нод видалено

	# Очистити чергу після завершення
	if is_instance_valid(self):
		call_deferred("_on_background_save_complete", queue.size())

func _on_background_save_complete(saved_count: int) -> void:
	if _background_save_thread:
		_background_save_thread.wait_to_finish()
		_background_save_thread = null

	# Видалити надмірне логування
	_save_queue.clear()

func initialize(world_seed: int, world_name_param: String = "default_world", voxel_scale_param: float = 0.1) -> void:
	_world_seed = world_seed
	_world_version = "1.0"
	world_name = world_name_param
	voxel_scale = voxel_scale_param
	save_directory = "user://worlds/" + world_name

	# Створити директорію
	var dir = DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive(save_directory)

	# Зберегти world metadata
	_save_world_metadata()

	# Логування тільки в debug mode
	if OS.is_debug_build():
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
		"modifications": {},  # Vector3 -> int (покриття вокселів)
		"operations": [],  # Список операцій для відтворення (cube, sphere тощо)
		"timestamp": Time.get_unix_time_from_system(),
		"save_path": _get_chunk_save_path(chunk_coords)
	}

	# Спробувати завантажити з диска
	if _load_chunk_from_disk(chunk_data):
		pass  # Видалити надмірне логування
	else:
		pass  # Видалити надмірне логування

	loaded_chunks[chunk_coords] = chunk_data
	return chunk_data

## Зберегти модифікації чанка
func save_chunk_modifications(chunk_coords: Vector3) -> void:
	if not loaded_chunks.has(chunk_coords):
		# Якщо чанк не завантажений, спробувати завантажити його спочатку
		load_chunk_modifications(chunk_coords)
	
	if not loaded_chunks.has(chunk_coords):
		return

	var chunk_data = loaded_chunks[chunk_coords]
	var has_modifications = not chunk_data.modifications.is_empty()
	var has_operations = chunk_data.get("operations", []).size() > 0
	var is_dirty = dirty_chunks.has(chunk_coords)
	
	if not has_modifications and not has_operations and not is_dirty:
		return  # Нема чого зберігати
	
	_save_chunk_to_disk(chunk_data)
	# Очистити з dirty_chunks після збереження
	dirty_chunks.erase(chunk_coords)

## Додати модифікацію вокселя (одна точка)
func add_voxel_modification(world_pos: Vector3, material: int) -> void:
	# Конвертувати світові координати в координати чанка
	var chunk_coords = _world_to_chunk(world_pos)
	var chunk_data = load_chunk_modifications(chunk_coords)
	chunk_data.modifications[world_pos] = material
	chunk_data.timestamp = Time.get_unix_time_from_system()

## Додати операцію модифікації (cube, sphere тощо) для відтворення
func add_modification_operation(op_type: String, world_pos: Vector3, size_or_radius: Vector3, material: int) -> void:
	var chunk_coords = _world_to_chunk(world_pos)
	var chunk_data = load_chunk_modifications(chunk_coords)
	
	# Додати операцію для відтворення
	var operation = {
		"type": op_type,  # "cube", "sphere", "point"
		"pos": {"x": world_pos.x, "y": world_pos.y, "z": world_pos.z},
		"size": {"x": size_or_radius.x, "y": size_or_radius.y, "z": size_or_radius.z},
		"material": material
	}
	
	if not chunk_data.has("operations"):
		chunk_data.operations = []
	chunk_data.operations.append(operation)
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
	if not loaded_chunks.has(chunk_coords):
		return
	
	var chunk_data = loaded_chunks[chunk_coords]
	# Переконатися що модифікації збережені перед вивантаженням
	var has_modifications = not chunk_data.modifications.is_empty()
	var has_operations = chunk_data.get("operations", []).size() > 0
	var is_dirty = dirty_chunks.has(chunk_coords)
	
	if has_modifications or has_operations or is_dirty:
		_save_chunk_to_disk(chunk_data)
	
	loaded_chunks.erase(chunk_coords)
	dirty_chunks.erase(chunk_coords)  # Очистити dirty після збереження

## Застосувати модифікації до чанка після генерації
func apply_modifications_to_chunk(terrain: VoxdotTerrain, chunk_coords: Vector3) -> void:
	if not loaded_chunks.has(chunk_coords):
		return

	var chunk_data = loaded_chunks[chunk_coords]
	var has_mods = not chunk_data.modifications.is_empty()
	var has_ops = chunk_data.get("operations", []).size() > 0
	
	if not has_mods and not has_ops:
		return

	# Спочатку відтворити операції (cube, sphere тощо)
	var operations = chunk_data.get("operations", [])
	for op in operations:
		var pos = Vector3(op.pos.x, op.pos.y, op.pos.z)
		var size = Vector3(op.size.x, op.size.y, op.size.z)
		var material = op.material
		
		match op.type:
			"cube":
				# place_edit очікує half_size
				var half_size = size * 0.5
				terrain.place_edit(half_size, pos, material, 1)
			"sphere":
				# Для сфери size вже є радіусом, тому передаємо як є
				terrain.place_edit(size, pos, material, 0)
			"point":
				# place_edit очікує half_size
				var half_voxel = voxel_scale * 0.5
				var voxel_half_size = Vector3(half_voxel, half_voxel, half_voxel)
				terrain.place_edit(voxel_half_size, pos, material, 1)

	# Потім застосувати точкові модифікації (для сумісності зі старим форматом)
	for world_pos in chunk_data.modifications.keys():
		var material = chunk_data.modifications[world_pos]
		# place_edit очікує half_size
		var half_voxel = voxel_scale * 0.5
		var voxel_half_size = Vector3(half_voxel, half_voxel, half_voxel)
		terrain.place_edit(voxel_half_size, world_pos, material, 1 if material > 0 else 0)

## Завантажити chunk data з диска
func _load_chunk_from_disk(chunk_data: Dictionary) -> bool:
	var save_path = chunk_data.save_path
	if not FileAccess.file_exists(save_path):
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		print("ChunkSaveManager: No saved data for chunk ", chunk_data.chunk_coords, " at ", save_path)
		return false

	var file_size = file.get_length()
	if file_size == 0:
		print("ChunkSaveManager: Empty file for chunk ", chunk_data.chunk_coords, " at ", save_path)
		file.close()
		return false

	var file_data = file.get_buffer(file_size)
	file.close()

	# Видалити надмірне логування

	var json: String
	var data: Variant

	# Перевірити чи файл має заголовок стиснутого формату
	var header_string = file_data.slice(0, TerrainConstants.COMPRESSED_HEADER.length()).get_string_from_utf8()
	if header_string == TerrainConstants.COMPRESSED_HEADER:
		# Це стиснутий файл - видалити заголовок і декомпресувати
		var compressed_data = file_data.slice(TerrainConstants.COMPRESSED_HEADER.length())
		var decompressed_data = compressed_data.decompress(compressed_data.size() * 10, FileAccess.COMPRESSION_GZIP)
		if decompressed_data.size() > 0:
			json = decompressed_data.get_string_from_utf8()
			data = JSON.parse_string(json)
			if data and typeof(data) == TYPE_DICTIONARY:
				pass  # Видалити надмірне логування
			else:
				print("ChunkSaveManager: Failed to parse compressed chunk ", chunk_data.chunk_coords)
				print("ChunkSaveManager: Decompressed content preview: ", json.substr(0, 200), "..." if json.length() > 200 else "")
				push_error("ChunkSaveManager: Failed to parse compressed chunk ", chunk_data.chunk_coords)
				return false
		else:
			print("ChunkSaveManager: Failed to decompress chunk ", chunk_data.chunk_coords, " - file may be corrupted")
			push_error("ChunkSaveManager: Failed to decompress chunk ", chunk_data.chunk_coords)
			return false
	else:
		# Це звичайний JSON файл (старий формат)
		json = file_data.get_string_from_utf8()
		data = JSON.parse_string(json)
		if data and typeof(data) == TYPE_DICTIONARY:
			pass  # Видалити надмірне логування
		else:
			print("ChunkSaveManager: Failed to parse uncompressed chunk ", chunk_data.chunk_coords)
			print("ChunkSaveManager: File content preview: ", json.substr(0, 200), "..." if json.length() > 200 else "")
			print("ChunkSaveManager: File size: ", file_data.size(), " bytes")

			# Якщо файл пошкоджений або порожній, видалити його
			if file_data.size() < 10 or not json.strip_edges():
				print("ChunkSaveManager: Deleting corrupted/empty chunk file ", save_path)
				DirAccess.remove_absolute(save_path)
			else:
				push_error("ChunkSaveManager: Invalid JSON in chunk file ", save_path, " - keeping file for manual inspection")

			return false
	if not data or typeof(data) != TYPE_DICTIONARY:
		push_error("ChunkSaveManager: Invalid JSON in ", save_path)
		return false

	chunk_data.timestamp = data.get("timestamp", Time.get_unix_time_from_system())

	# Завантажити operations (список операцій для відтворення)
	if data.has("operations"):
		chunk_data.operations = data.operations
	else:
		chunk_data.operations = []

	# Оптимізоване відновлення модифікацій (для сумісності зі старим форматом)
	var mods_data = data.get("modifications", {})
	chunk_data.modifications.clear()
	for key in mods_data.keys():
		if typeof(key) == TYPE_INT:
			# Новий формат - розпакування
			var packed = int(key)
			var x = (packed & 0xFFFFF) - (0x80000 if (packed & 0x80000) else 0)
			var y = ((packed >> 20) & 0xFFFFF) - (0x80000 if ((packed >> 20) & 0x80000) else 0)
			var z = ((packed >> 40) & 0xFFFFF) - (0x80000 if ((packed >> 40) & 0x80000) else 0)
			chunk_data.modifications[Vector3(x, y, z)] = mods_data[key]
		elif typeof(key) == TYPE_STRING:
			# Старий формат для сумісності
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
	if not chunk_data.has("save_path") or not chunk_data.has("modifications"):
		push_error("ChunkSaveManager: Invalid chunk_data structure")
		return
	
	var save_path = chunk_data.save_path
	var has_operations = chunk_data.get("operations", []).size() > 0
	if chunk_data.modifications.is_empty() and not has_operations:
		# Видалити файл якщо немає модифікацій і операцій
		var dir = DirAccess.open(save_path.get_base_dir())
		if dir and dir.file_exists(save_path):
			var err = dir.remove(save_path)
			if err != OK:
				push_warning("ChunkSaveManager: Failed to remove empty chunk file: ", save_path)
		return

	var data = {
		"chunk_coords": {
			"x": chunk_data.chunk_coords.x,
			"y": chunk_data.chunk_coords.y,
			"z": chunk_data.chunk_coords.z
		},
		"timestamp": chunk_data.timestamp,
		"modifications": {},
		"operations": chunk_data.get("operations", [])  # Зберегти операції
	}

	# Оптимізована серіалізація Vector3 - використати цілі числа
	for pos in chunk_data.modifications.keys():
		# Пакування координат в одно int64 для ефективності
		var packed_coord = (int(pos.x) & 0xFFFFF) | ((int(pos.y) & 0xFFFFF) << 20) | ((int(pos.z) & 0xFFFFF) << 40)
		data.modifications[packed_coord] = chunk_data.modifications[pos]

	var json = JSON.stringify(data)
	var compressed_data = json.to_utf8_buffer()
	compressed_data = compressed_data.compress(FileAccess.COMPRESSION_GZIP)

	# Додати заголовок для ідентифікації стиснутих файлів
	var header_data = TerrainConstants.COMPRESSED_HEADER.to_utf8_buffer()
	var final_data = header_data + compressed_data

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_buffer(final_data)
		file.flush()  # Форсувати запис на диск
		file.close()
		if not FileAccess.file_exists(save_path):
			push_error("ChunkSaveManager: File was not created despite successful write: ", save_path)
	else:
		var error = FileAccess.get_open_error()
		push_error("ChunkSaveManager: Failed to save chunk ", chunk_data.chunk_coords, " to ", save_path, " Error: ", error)

## Конвертувати світові координати в координати чанка
func _world_to_chunk(world_pos: Vector3) -> Vector3:
	return TerrainConstants.world_to_chunk(world_pos, voxel_scale)

## Конвертувати координати чанка в координати регіону
func _chunk_to_region(chunk_coords: Vector3) -> Vector3:
	return TerrainConstants.chunk_to_region(chunk_coords)

## Отримати шлях до файлу регіону
func _get_region_file_path(region_coords: Vector3) -> String:
	return save_directory + "/region/r.%d.%d.mca" % [region_coords.x, region_coords.z]

## Зберегти всі незбережені чанки
func save_all_chunks() -> void:
	print("ChunkSaveManager: Saving all chunks...")
	for chunk_coords in loaded_chunks.keys():
		save_chunk_modifications(chunk_coords)
	print("ChunkSaveManager: All chunks saved")

## Примусове збереження всіх чанків (для ручного виклику)
func force_save_all() -> void:
	print("ChunkSaveManager: Force saving all chunks...")
	save_all_chunks()
	print("ChunkSaveManager: Force save completed")

## Позначити чанк як змінений (для відстеження модифікацій)
func mark_chunk_dirty(chunk_coords: Vector3) -> void:
	# Переконатися що чанк завантажений перед позначенням як dirty
	if not loaded_chunks.has(chunk_coords):
		load_chunk_modifications(chunk_coords)
	
	if loaded_chunks.has(chunk_coords):
		var chunk_data = loaded_chunks[chunk_coords]
		chunk_data.timestamp = Time.get_unix_time_from_system()
		dirty_chunks[chunk_coords] = Time.get_unix_time_from_system()

## Очистити всі дані (для нового світу)
func clear_all_data() -> void:
	loaded_chunks.clear()
	dirty_chunks.clear()
	_save_queue.clear()

	var dir = DirAccess.open(save_directory)
	if dir:
		# Рекурсивно видалити всі файли (з захистом від рекурсії)
		_clear_directory(dir, save_directory, 0)
	else:
		push_warning("ChunkSaveManager: Save directory doesn't exist: ", save_directory)

func _clear_directory(dir: DirAccess, path: String, depth: int = 0) -> void:
	# Захист від глибокої рекурсії
	if depth > 10:
		push_error("ChunkSaveManager: Directory recursion too deep, stopping at: ", path)
		return
	
	var err = dir.list_dir_begin()
	if err != OK:
		push_error("ChunkSaveManager: Failed to list directory: ", path)
		return
	
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			var subdir_path = path + "/" + file_name
			var subdir = DirAccess.open(subdir_path)
			if subdir:
				_clear_directory(subdir, subdir_path, depth + 1)
				DirAccess.remove_absolute(subdir_path)
		else:
			var file_path = path + "/" + file_name
			var remove_err = DirAccess.remove_absolute(file_path)
			if remove_err != OK:
				push_warning("ChunkSaveManager: Failed to remove file: ", file_path)
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

## Зберегти metadata світу
func _save_world_metadata() -> void:
	var metadata = {
		"seed": _world_seed,
		"version": _world_version,
		"voxel_scale": voxel_scale,
		"name": world_name
	}

	var json = JSON.stringify(metadata)
	var file = FileAccess.open(save_directory + "/world.json", FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()

## Завантажити metadata світу
func _load_world_metadata() -> void:
	var file = FileAccess.open(save_directory + "/world.json", FileAccess.READ)
	if file:
		var json = file.get_as_text()
		file.close()
		var data = JSON.parse_string(json)
		if data is Dictionary:
			_world_seed = data.get("seed", 0)
			_world_version = data.get("version", "1.0")
			voxel_scale = data.get("voxel_scale", 0.1)
