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
	"""Генерація гір для чанка
	
	ВИПРАВЛЕНО: Тепер використовує procedural_module для отримання висоти
	і додає блоки тільки зверху, не перезаписує весь стовпчик.
	"""
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

	# ВИПРАВЛЕНО: Отримуємо procedural_module для правильного отримання висоти
	var procedural = null
	if get_parent() and get_parent().procedural_module:
		procedural = get_parent().procedural_module

	# Застосовуємо гору до чанка
	for x in range(chunk_start.x, chunk_start.x + chunk_size.x):
		for z in range(chunk_start.y, chunk_start.y + chunk_size.y):
			var distance_to_center = Vector2(x, z).distance_to(Vector2(chunk_center_x, chunk_center_z))

			if distance_to_center <= mountain_radius:
				# Підвищуємо місцевість
				var height_boost = mountain_height * (1.0 - distance_to_center / mountain_radius)

				# ВИПРАВЛЕНО: Отримуємо поточну висоту через procedural_module або GridMap
				var current_surface_y = _get_current_height_at_position(gridmap, x, z)
				
				# ВИПРАВЛЕНО: Додаємо блоки тільки зверху, не перезаписуємо весь стовпчик
				var boost = int(height_boost)
				if boost > 0:
					_add_blocks_on_top(gridmap, x, z, current_surface_y, boost)

func generate_canyons_for_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація каньйонів для чанка
	
	ВАЖЛИВО: Поки не реалізовано. Заготовка для майбутньої реалізації
	прорізання каньйонів через місцевість.
	"""
	if not canyon_noise:
		return

	# Заготовка для генерації каньйонів
	# В майбутньому буде реалізація прорізання каньйонів через місцевість
	# Рекомендація: перенести логіку в ProceduralGeneration як додатковий шар шуму

func generate_caves_for_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація печер для чанка
	
	ВАЖЛИВО: Поки не реалізовано. Печери генеруються через ProceduralGeneration
	(enable_caves), тому цей метод залишено як заготовку.
	"""
	if not cave_noise:
		return

	# Заготовка для генерації печер
	# В майбутньому буде 3D генерація печер з використанням cave_noise
	# Рекомендація: перенести логіку в ProceduralGeneration як додатковий шар шуму

func _get_current_height_at_position(gridmap: GridMap, x: int, z: int) -> int:
	"""Отримати поточну висоту в позиції
	
	ВИПРАВЛЕНО: Тепер шукає блоки від max_height вниз до min_height,
	а не тільки від y=30. Це виправляє проблему з генерацією величезних
	стовпів каменю в чанках з високою поверхнею.
	"""
	if not gridmap or not is_instance_valid(gridmap):
		return 0
	
	# ВИПРАВЛЕНО: Отримуємо min_height та max_height з батьківського TerrainGenerator
	var min_height = -64  # Дефолт
	var max_height = 192  # Дефолт
	
	if get_parent() and get_parent().has_method("get_min_height"):
		min_height = get_parent().get_min_height()
	if get_parent() and get_parent().has_method("get_max_height"):
		max_height = get_parent().get_max_height()
	
	# ВИПРАВЛЕНО: Шукаємо найвищий блок від max_height вниз до min_height
	for y in range(max_height - 1, min_height - 1, -1):
		if gridmap.get_cell_item(Vector3i(x, y, z)) >= 0:
			return y + 1  # Поверхня блоку
	
	# ВИПРАВЛЕНО: Якщо блок не знайдено, намагаємося отримати висоту з procedural_module
	if get_parent() and get_parent().procedural_module:
		var procedural = get_parent().procedural_module
		if procedural.has_method("get_height_at"):
			var height = procedural.get_height_at(x, z)
			if height > 0:
				return int(height)
		elif procedural.has_method("sample_2dv"):
			# Альтернативний спосіб через noise
			var height = procedural.sample_2dv(Vector2(x, z))
			if height > 0:
				return int(height)
	
	# Останній fallback - повертаємо min_height як базову висоту
	return max(min_height, 0)

func _add_blocks_on_top(gridmap: GridMap, x: int, z: int, current_surface_y: int, boost: int):
	"""Додати блоки зверху на поточну поверхню
	
	ВИПРАВЛЕНО: Тепер тільки додає блоки зверху, не перезаписує весь стовпчик.
	Це зберігає біоми, траву, землю та печери.
	
	Args:
		gridmap: GridMap для встановлення блоків
		x, z: Координати колонки
		current_surface_y: Поточна висота поверхні
		boost: Кількість блоків для додавання зверху
	"""
	if not gridmap or not is_instance_valid(gridmap):
		return
	
	# ВИПРАВЛЕНО: Отримуємо min_height та max_height
	var min_height = -64  # Дефолт
	var max_height = 192  # Дефолт
	
	if get_parent() and get_parent().has_method("get_min_height"):
		min_height = get_parent().get_min_height()
	if get_parent() and get_parent().has_method("get_max_height"):
		max_height = get_parent().get_max_height()
	
	# ВИПРАВЛЕНО: Додаємо блоки тільки зверху від поточної поверхні
	# Не перезаписуємо існуючі блоки - це зберігає біоми, траву, землю, печери
	var stone_id = _get_mesh_index_for_block("stone")
	if stone_id < 0:
		return  # Не можемо додати блоки без валідного mesh_index
	
	for dy in range(boost):
		var y = current_surface_y + dy
		if y >= min_height and y < max_height:
			# Перевіряємо чи вже є блок (не перезаписуємо)
			if gridmap.get_cell_item(Vector3i(x, y, z)) < 0:
				gridmap.set_cell_item(Vector3i(x, y, z), stone_id)

func _fill_column_to_height(gridmap: GridMap, x: int, z: int, target_height: int):
	"""Заповнити колонку до заданої висоти
	
	ЗАСТАРІЛО: Використовуйте _add_blocks_on_top() замість цього методу.
	Цей метод перезаписує весь стовпчик і знищує біоми, траву, землю, печери.
	Залишено для сумісності, але не використовується в generate_mountains_for_chunk().
	"""
	if not gridmap or not is_instance_valid(gridmap):
		return
	
	# ВИПРАВЛЕНО: Отримуємо min_height та max_height
	var min_height = -64  # Дефолт
	var max_height = 192  # Дефолт
	
	if get_parent() and get_parent().has_method("get_min_height"):
		min_height = get_parent().get_min_height()
	if get_parent() and get_parent().has_method("get_max_height"):
		max_height = get_parent().get_max_height()
	
	# ВИПРАВЛЕНО: Обмежуємо target_height межами світу
	target_height = clamp(target_height, min_height, max_height)
	
	# Отримуємо поточну висоту
	var current_height = _get_current_height_at_position(gridmap, x, z)
	
	# ВИПРАВЛЕНО: Заповнюємо тільки від поточної висоти до target_height
	# Якщо target_height вище поточної - додаємо блоки
	# Якщо target_height нижче поточної - видаляємо блоки (не робимо нічого, бо це може зламати терейн)
	if target_height > current_height:
		# Додаємо блоки від поточної висоти до target_height
		var start_y = max(current_height, min_height)
		var end_y = min(target_height, max_height)
		
		for y in range(start_y, end_y):
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
