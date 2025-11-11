extends Node
class_name LargeStructureGenerator

# Large-scale Structures Generator
# Заготовка для генерації великих структур: гори, каньйони, печери
# Це фундамент для майбутніх фіч генерації будинків, дерев тощо

@export_group("Large Structures")
@export var enable_large_structures := false
@export var mountain_density := 0.1  # Ймовірність генерації гори в чанку
@export var canyon_density := 0.05   # Ймовірність генерації каньйону
@export var cave_density := 0.2      # Ймовірність генерації печери

@export_group("Mountain Parameters")
@export var mountain_min_height := 15
@export var mountain_max_height := 25
@export var mountain_radius_min := 10
@export var mountain_radius_max := 30

@export_group("Canyon Parameters")
@export var canyon_min_depth := 8
@export var canyon_max_depth := 15
@export var canyon_width_min := 3
@export var canyon_width_max := 8

@export_group("Cave Parameters")
@export var cave_min_size := 5
@export var cave_max_size := 15
@export var cave_noise_scale := 0.1

var mountain_noise: FastNoiseLite
var canyon_noise: FastNoiseLite
var cave_noise: FastNoiseLite

func _ready():
	initialize_noise()

func initialize_noise():
	"""Ініціалізація шумів для генерації структур"""
	mountain_noise = FastNoiseLite.new()
	mountain_noise.seed = 12345  # Фіксований seed для консистентності
	mountain_noise.frequency = 0.01

	canyon_noise = FastNoiseLite.new()
	canyon_noise.seed = 67890
	canyon_noise.frequency = 0.005

	cave_noise = FastNoiseLite.new()
	cave_noise.seed = 11111
	cave_noise.frequency = cave_noise_scale

func generate_large_structures_for_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація великих структур для чанка"""
	if not enable_large_structures:
		return

	# Генеруємо гори
	generate_mountains_for_chunk(gridmap, chunk_pos, chunk_size)

	# Генеруємо каньйони
	generate_canyons_for_chunk(gridmap, chunk_pos, chunk_size)

	# Генеруємо печери
	generate_caves_for_chunk(gridmap, chunk_pos, chunk_size)

func generate_mountains_for_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація гір для чанка"""
	if not mountain_noise:
		return

	var chunk_start = chunk_pos * chunk_size

	# Перевіряємо чи треба генерувати гору в цьому чанку
	var chunk_center_x = chunk_start.x + chunk_size.x / 2.0
	var chunk_center_z = chunk_start.y + chunk_size.y / 2.0

	var mountain_value = mountain_noise.get_noise_2d(chunk_center_x, chunk_center_z)
	if mountain_value < (1.0 - mountain_density):
		return  # Не генеруємо гору тут

	# Генеруємо гору
	var mountain_height = mountain_min_height + (mountain_value + 1.0) * 0.5 * (mountain_max_height - mountain_min_height)
	var mountain_radius = mountain_radius_min + (mountain_value + 1.0) * 0.5 * (mountain_radius_max - mountain_radius_min)

	# Застосовуємо гору до чанка
	for x in range(chunk_start.x, chunk_start.x + chunk_size.x):
		for z in range(chunk_start.y, chunk_start.y + chunk_size.y):
			var distance_to_center = Vector2(x, z).distance_to(Vector2(chunk_center_x, chunk_center_z))

			if distance_to_center <= mountain_radius:
				# Підвищуємо місцевість
				var height_boost = mountain_height * (1.0 - distance_to_center / mountain_radius)

				# Тут треба отримати поточну висоту і додати boost
				# Заготовка - в майбутньому інтегрувати з основною генерацією
				var current_height = _get_current_height_at_position(gridmap, x, z)
				var new_height = current_height + height_boost

				_fill_column_to_height(gridmap, x, z, new_height)

func generate_canyons_for_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація каньйонів для чанка"""
	if not canyon_noise:
		return

	# Заготовка для генерації каньйонів
	# В майбутньому буде реалізація прорізання каньйонів через місцевість

func generate_caves_for_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація печер для чанка"""
	if not cave_noise:
		return

	# Заготовка для генерації печер
	# В майбутньому буде 3D генерація печер з використанням cave_noise

func _get_current_height_at_position(gridmap: GridMap, x: int, z: int) -> int:
	"""Отримати поточну висоту в позиції"""
	# Шукаємо найвищий блок
	for y in range(30, -1, -1):  # Перевіряємо зверху вниз
		if gridmap.get_cell_item(Vector3i(x, y, z)) >= 0:
			return y + 1
	return 5  # Базова висота якщо блоки не знайдені

func _fill_column_to_height(gridmap: GridMap, x: int, z: int, target_height: int):
	"""Заповнити колонку до заданої висоти"""
	# Спрощена версія - в майбутньому треба враховувати біоми та типи блоків
	for y in range(target_height):
		var block_type = "stone"  # Спрощено
		var mesh_index = _get_mesh_index_for_block(block_type)
		if mesh_index >= 0:
			gridmap.set_cell_item(Vector3i(x, y, z), mesh_index)

func _get_mesh_index_for_block(block_name: String) -> int:
	"""Отримати mesh index для блоку"""
	# Спрощена версія - в майбутньому інтегрувати з BlockRegistry
	var fallback_map = {
		"stone": 2,
		"dirt": 1,
		"grass": 0
	}
	return fallback_map.get(block_name, -1)

# Future features - заготовки для розширення

func add_tree_at_position(gridmap: GridMap, position: Vector3i):
	"""Заготовка для генерації дерева"""
	# В майбутньому: генерувати стовбур + листя
	pass

func add_house_at_position(gridmap: GridMap, position: Vector3i, house_type: String):
	"""Заготовка для генерації будинку"""
	# В майбутньому: генерувати стіни, дах, двері залежно від типу
	pass

func generate_village_in_area(gridmap: GridMap, center_pos: Vector2i, radius: int):
	"""Заготовка для генерації села"""
	# В майбутньому: розмістити будинки, дороги, etc.
	pass

func get_structure_at_position(position: Vector3i) -> Dictionary:
	"""Перевірити чи є структура в позиції"""
	# В майбутньому: повернути інформацію про структуру
	return {}
