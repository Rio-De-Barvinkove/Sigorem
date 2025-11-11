extends Node
class_name StartingAreaGenerator

# Starting Area - безпечна зона для нових гравців
# Створює комфортну зону для початку гри

@export_group("Starting Area Settings")
@export var enable_starting_area := true
@export var starting_area_radius := 3  # Радіус зони в чанках
@export var clear_trees_in_area := true
@export var add_tutorial_structures := false  # Заготовка

@export_group("Terrain Modifications")
@export var flatten_starting_area := true
@export var starting_area_height := 5
@export var create_paths := false  # Заготовка

@export_group("Safety Features")
@export var remove_hostile_mobs := true
@export var add_basic_resources := false  # Заготовка

var starting_area_chunks = []  # Список чанків що належать до starting area

func generate_starting_area(gridmap: GridMap, center_chunk: Vector2i, chunk_size: Vector2i):
	"""Згенерувати starting area навколо центру"""
	if not enable_starting_area:
		return

	starting_area_chunks.clear()

	# Позначити чанки як частина starting area
	for x in range(-starting_area_radius, starting_area_radius + 1):
		for z in range(-starting_area_radius, starting_area_radius + 1):
			if abs(x) + abs(z) <= starting_area_radius:  # Ромбовидна форма
				var chunk_pos = center_chunk + Vector2i(x, z)
				starting_area_chunks.append(chunk_pos)

	# Модифікувати кожен чанк starting area
	for chunk_pos in starting_area_chunks:
		modify_chunk_for_starting_area(gridmap, chunk_pos, chunk_size)

func modify_chunk_for_starting_area(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Модифікувати чанк для starting area"""
	var chunk_start = chunk_pos * chunk_size

	# Спростити генерацію - зробити площу рівною
	if flatten_starting_area:
		for x in range(chunk_start.x, chunk_start.x + chunk_size.x):
			for z in range(chunk_start.y, chunk_start.y + chunk_size.y):
				# Зробити поверхню рівною
				for y in range(starting_area_height):
					var block_type = "dirt" if y < starting_area_height - 1 else "grass"
					var mesh_index = _get_mesh_index_for_block(block_type)
					if mesh_index >= 0:
						gridmap.set_cell_item(Vector3i(x, y, z), mesh_index)

				# Очистити блоки вище поверхні
				for y in range(starting_area_height, 20):
					gridmap.set_cell_item(Vector3i(x, y, z), -1)

	# Додати базові структури (заготовка)
	if add_tutorial_structures:
		add_tutorial_structures_to_chunk(gridmap, chunk_pos, chunk_size)

func add_tutorial_structures_to_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Додати навчальні структури до чанка (заготовка)"""
	# В майбутньому: додати таблички з підказками, базові будинки, тощо
	pass

func is_chunk_in_starting_area(chunk_pos: Vector2i) -> bool:
	"""Перевірити чи чанк знаходиться в starting area"""
	return chunk_pos in starting_area_chunks

func get_starting_area_center() -> Vector2i:
	"""Отримати центр starting area"""
	if starting_area_chunks.is_empty():
		return Vector2i.ZERO

	# Повернути центр списку (спрощено)
	return starting_area_chunks[starting_area_chunks.size() / 2]

func get_safe_spawn_position() -> Vector3:
	"""Отримати безпечну позицію для спавну гравця"""
	var center_chunk = get_starting_area_center()
	var chunk_size = Vector2i(50, 50)  # Спрощено, треба передати

	var world_x = center_chunk.x * chunk_size.x + chunk_size.x / 2
	var world_z = center_chunk.y * chunk_size.y + chunk_size.y / 2
	var world_y = starting_area_height + 2  # Трохи вище поверхні

	return Vector3(world_x, world_y, world_z)

func clear_hostile_mobs_in_area():
	"""Видалити ворожих мобів з starting area (заготовка)"""
	# В майбутньому: знайти та видалити всіх мобів в зоні
	pass

func add_basic_resources_to_area():
	"""Додати базові ресурси в starting area (заготовка)"""
	# В майбутньому: додати дерево, камінь, їжу поруч з гравцем
	pass

func _get_mesh_index_for_block(block_name: String) -> int:
	"""Отримати mesh index для блоку"""
	# Спрощена версія
	var fallback_map = {
		"grass": 0,
		"dirt": 1,
		"stone": 2
	}
	return fallback_map.get(block_name, -1)

# Future features - заготовки

func create_tutorial_path(start_pos: Vector3, end_pos: Vector3):
	"""Створити навчальний шлях"""
	# В майбутньому: проложити стежку з підказками
	pass

func add_welcome_sign(position: Vector3, message: String):
	"""Додати табличку з вітальним повідомленням"""
	# В майбутньому: створити 3D табличку з текстом
	pass

func create_basic_shelter(position: Vector3):
	"""Створити базовий прихисток"""
	# В майбутньому: згенерувати простий будиночок
	pass

func setup_tutorial_quests():
	"""Налаштувати навчальні завдання"""
	# В майбутньому: створити квестову систему для нових гравців
	pass
