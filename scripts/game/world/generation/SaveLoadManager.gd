extends Node
class_name SaveLoadManager

# Модуль для збереження та завантаження терейну
# Важлива функція для великих світів

@export var save_directory := "user://terrain_data/"
@export var auto_save_interval := 300.0  # секунди
@export var compress_data := true

var last_save_time := 0.0
var save_queue: Array = []

func _ready():
	ensure_save_directory()

func _process(delta):
	# Автозбереження
	if Time.get_time_dict_from_system()["hour"] - last_save_time > auto_save_interval:
		auto_save()

func ensure_save_directory():
	"""Переконатися, що директорія для збереження існує"""
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("terrain_data"):
		dir.make_dir("terrain_data")

func save_chunk_data(chunk_pos: Vector2i, chunk_data: Dictionary):
	"""Збереження даних чанка"""
	var file_path = get_chunk_file_path(chunk_pos)
	var data_to_save = {
		"chunk_pos": [chunk_pos.x, chunk_pos.y],
		"timestamp": Time.get_unix_time_from_system(),
		"data": chunk_data
	}

	var json_string = JSON.stringify(data_to_save)
	if compress_data:
		json_string = compress_string(json_string)

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("SaveLoadManager: Чанк ", chunk_pos, " збережено")
	else:
		push_error("SaveLoadManager: Не вдалося зберегти чанк ", chunk_pos)

func load_chunk_data(chunk_pos: Vector2i) -> Dictionary:
	"""Завантаження даних чанка"""
	var file_path = get_chunk_file_path(chunk_pos)

	if not FileAccess.file_exists(file_path):
		return {}  # Чанк не збережений

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("SaveLoadManager: Не вдалося завантажити чанк ", chunk_pos)
		return {}

	var json_string = file.get_as_text()
	file.close()

	if compress_data:
		json_string = decompress_string(json_string)

	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		var data = json.data
		print("SaveLoadManager: Чанк ", chunk_pos, " завантажено")
		return data.get("data", {})
	else:
		push_error("SaveLoadManager: Помилка парсингу JSON для чанка ", chunk_pos)
		return {}

func get_chunk_file_path(chunk_pos: Vector2i) -> String:
	"""Отримати шлях до файлу чанка"""
	return save_directory + "chunk_" + str(chunk_pos.x) + "_" + str(chunk_pos.y) + ".json"

func compress_string(data: String) -> String:
	"""Стиснення рядка (спрощена версія)"""
	# В реальності можна використовувати більш ефективні алгоритми стиснення
	return data  # Спрощена заглушка

func decompress_string(data: String) -> String:
	"""Розтиснення рядка"""
	return data  # Спрощена заглушка

func auto_save():
	"""Автоматичне збереження активних чанків"""
	if not get_parent() or not get_parent().chunk_module:
		return

	print("SaveLoadManager: Автозбереження...")

	for chunk_pos in get_parent().chunk_module.active_chunks.keys():
		# Збираємо дані чанка для збереження
		var chunk_data = collect_chunk_data(chunk_pos)
		save_chunk_data(chunk_pos, chunk_data)

	last_save_time = Time.get_unix_time_from_system()
	print("SaveLoadManager: Автозбереження завершено")

func collect_chunk_data(chunk_pos: Vector2i) -> Dictionary:
	"""Збір даних чанка для збереження"""
	var chunk_data = {
		"blocks": {},
		"vegetation": {},
		"structures": []
	}

	# Зберігаємо блоки чанка
	if get_parent().target_gridmap:
		var chunk_size = get_parent().chunk_size
		var chunk_start = chunk_pos * chunk_size

		for x in range(chunk_start.x, chunk_start.x + chunk_size.x):
			for z in range(chunk_start.y, chunk_start.y + chunk_size.y):
				for y in range(-10, 20):  # Діапазон висоти
					var cell_item = get_parent().target_gridmap.get_cell_item(Vector3i(x, y, z))
					if cell_item >= 0:
						var key = str(x) + "_" + str(y) + "_" + str(z)
						chunk_data["blocks"][key] = cell_item

	# Зберігаємо дані рослинності
	if get_parent().vegetation_module:
		chunk_data["vegetation"] = get_parent().vegetation_module.get_chunk_vegetation_data(chunk_pos)

	# Зберігаємо дані структур
	if get_parent().structure_module:
		chunk_data["structures"] = get_parent().structure_module.get_chunk_structures(chunk_pos)

	return chunk_data

func restore_chunk_data(chunk_pos: Vector2i, chunk_data: Dictionary):
	"""Відновлення даних чанка"""
	if not get_parent().target_gridmap:
		return

	# Відновлюємо блоки
	var blocks = chunk_data.get("blocks", {})
	for key in blocks.keys():
		var coords = key.split("_")
		if coords.size() >= 3:
			var pos = Vector3i(int(coords[0]), int(coords[1]), int(coords[2]))
			get_parent().target_gridmap.set_cell_item(pos, blocks[key])

	# Відновлюємо рослинність
	if get_parent().vegetation_module:
		var vegetation_data = chunk_data.get("vegetation", {})
		get_parent().vegetation_module.restore_chunk_vegetation(chunk_pos, vegetation_data)

	# Відновлюємо структури
	if get_parent().structure_module:
		var structures = chunk_data.get("structures", [])
		get_parent().structure_module.restore_chunk_structures(chunk_pos, structures)

	print("SaveLoadManager: Чанк ", chunk_pos, " відновлено з збереження")

func save_world_metadata():
	"""Збереження метаданих світу"""
	var metadata = {
		"world_seed": get_parent().noise.seed if get_parent().noise else 0,
		"chunk_size": [get_parent().chunk_size.x, get_parent().chunk_size.y],
		"generation_settings": {
			"height_amplitude": get_parent().height_amplitude,
			"base_height": get_parent().base_height
		},
		"save_timestamp": Time.get_unix_time_from_system()
	}

	var file_path = save_directory + "world_metadata.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(metadata))
		file.close()
		print("SaveLoadManager: Метаданих світу збережено")

func load_world_metadata() -> Dictionary:
	"""Завантаження метаданих світу"""
	var file_path = save_directory + "world_metadata.json"

	if not FileAccess.file_exists(file_path):
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error == OK:
		print("SaveLoadManager: Метаданих світу завантажено")
		return json.data
	else:
		push_error("SaveLoadManager: Помилка парсингу метаданих")
		return {}

func cleanup_old_saves(max_age_days: int = 30):
	"""Очищення старих збережень"""
	var cutoff_time = Time.get_unix_time_from_system() - (max_age_days * 24 * 60 * 60)

	var dir = DirAccess.open(save_directory)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = save_directory + file_name
			var file_modified = FileAccess.get_modified_time(file_path)

			if file_modified < cutoff_time:
				dir.remove(file_path)
				print("SaveLoadManager: Видалено старий файл: ", file_name)

		file_name = dir.get_next()

	dir.list_dir_end()
