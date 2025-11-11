extends Node
class_name ProceduralGeneration

# Модуль для базової процедурної генерації терейну з шуму

var noise: FastNoiseLite
var height_amplitude := 5
var base_height := 5
var max_height := 64

# Додаткові шари шуму (з infinite_heightmap_terrain)
@export var extra_terrain_noise_layers: Array[FastNoiseLite] = []
@export var terrain_height_multiplier: float = 150.0
@export var terrain_height_offset: float = 0.0

# Налаштування кольорів (з infinite_heightmap_terrain)
@export var two_colors := true
@export var terrain_color_steepness_curve: Curve
@export var terrain_level_color: Color = Color.DARK_OLIVE_GREEN
@export var terrain_cliff_color: Color = Color.DIM_GRAY
@export var terrain_material: StandardMaterial3D

# Biome Transitions - налаштування біомів
@export var enable_biomes := true
@export var biome_blend_distance := 3.0  # Відстань blending між біомами
@export var biome_scale := 100.0  # Масштаб біомів

# Cave Generation - налаштування печер
@export var enable_caves := false  # Вимкнено поки - заготовка
@export var cave_density := 0.3    # Ймовірність печери в блоці
@export var cave_noise_scale := 0.05  # Масштаб шуму печер

func _ready():
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.05

	if not terrain_color_steepness_curve:
		terrain_color_steepness_curve = Curve.new()
		terrain_color_steepness_curve.add_point(Vector2(0.0, 0.0))
		terrain_color_steepness_curve.add_point(Vector2(1.0, 1.0))

	if not terrain_material:
		terrain_material = StandardMaterial3D.new()
		terrain_material.vertex_color_use_as_albedo = true

func generate_terrain(gridmap: GridMap, start_pos: Vector2i, size: Vector2i):
	"""Генерація терейну в заданій області"""
	if not gridmap or not noise:
		push_error("ProceduralGeneration: GridMap або noise не встановлені!")
		return

	print("ProceduralGeneration: Генерація терейну від ", start_pos, " розміром ", size)

	for x in range(start_pos.x, start_pos.x + size.x):
		for z in range(start_pos.y, start_pos.y + size.y):
			var height = _clamp_height(int(noise.get_noise_2d(x, z) * height_amplitude) + base_height)

			for y in range(height):
				var block_id: String

				# Визначення типу блоку залежно від висоти
				if y < height - 2:
					block_id = "stone"
				elif y < height - 1:
					block_id = "dirt"
				else:
					block_id = "grass"

				var mesh_index = get_mesh_index_for_block(gridmap, block_id)
				if mesh_index >= 0:
					gridmap.set_cell_item(Vector3i(x, y, z), mesh_index)

func generate_chunk(gridmap: GridMap, chunk_pos: Vector2i, optimization: Dictionary = {}):
	"""Генерація окремого чанка з оптимізацією та врахуванням границь"""
	# Отримуємо chunk_size з батьківського chunk_module або використовуємо дефолт
	var chunk_size = Vector2i(50, 50)  # дефолт
	if get_parent() and get_parent().has_method("get_chunk_size"):
		chunk_size = get_parent().get_chunk_size()
	elif get_parent() and get_parent().chunk_size:
		chunk_size = get_parent().chunk_size

	var chunk_start = chunk_pos * chunk_size

	# Застосовуємо оптимізацію якщо вона є
	var resolution = optimization.get("resolution", 1.0)
	if resolution < 1.0:
		# Зменшуємо розмір чанка або деталізацію
		chunk_size = Vector2i(int(chunk_size.x * resolution), int(chunk_size.y * resolution))

	# Генеруємо чанк з врахуванням границь
	generate_chunk_with_boundaries(gridmap, chunk_pos, chunk_size, chunk_start)

func get_height_at(x: int, z: int) -> int:
	"""Отримати висоту терейну в точці"""
	if not noise:
		return _clamp_height(base_height)
	return _clamp_height(int(sample_2dv(Vector2(x, z)) * height_amplitude) + base_height)

func sample_2dv(point: Vector2) -> float:
	"""Семплінг шуму з додатковими шарами (з infinite_heightmap_terrain)"""
	var value: float = noise.get_noise_2dv(point)

	for extra_noise in extra_terrain_noise_layers:
		value += extra_noise.get_noise_2dv(point)

	return value

func generate_chunk_with_boundaries(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i, chunk_start: Vector2i):
	"""Генерація чанка з врахуванням границь сусідніх чанків"""
	if not gridmap or not noise:
		push_error("ProceduralGeneration: GridMap або noise не встановлені!")
		return

	# Збираємо дані про сусідні чанки для плавних границь
	var neighbor_heights = _gather_neighbor_chunk_data(gridmap, chunk_pos, chunk_size)

	# Генеруємо терейн з врахуванням границь
	for x in range(chunk_start.x, chunk_start.x + chunk_size.x):
		for z in range(chunk_start.y, chunk_start.y + chunk_size.y):
			# Визначаємо чи це граничний блок
			var is_boundary = _is_boundary_block(x, z, chunk_start, chunk_size)

			if is_boundary:
				# Для граничних блоків використовуємо дані сусідів
				var height = _get_height_with_boundary_smoothing(x, z, neighbor_heights)
				_set_blocks_at_position(gridmap, x, z, height)
			else:
				# Для внутрішніх блоків використовуємо звичайну генерацію
				var height = int(noise.get_noise_2d(x, z) * height_amplitude) + base_height
				_set_blocks_at_position(gridmap, x, z, height)

	# Генеруємо печери після основного терейну
	if enable_caves:
		generate_caves_in_chunk(gridmap, chunk_pos, chunk_size)

func _gather_neighbor_chunk_data(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i) -> Dictionary:
	"""Збирає дані про висоти з сусідніх чанків"""
	var neighbor_data = {}

	# Напрямки сусідів
	var directions = [
		{"name": "north", "offset": Vector2i(0, -1)},
		{"name": "south", "offset": Vector2i(0, 1)},
		{"name": "east", "offset": Vector2i(1, 0)},
		{"name": "west", "offset": Vector2i(-1, 0)},
		{"name": "northeast", "offset": Vector2i(1, -1)},
		{"name": "northwest", "offset": Vector2i(-1, -1)},
		{"name": "southeast", "offset": Vector2i(1, 1)},
		{"name": "southwest", "offset": Vector2i(-1, 1)}
	]

	for direction in directions:
		var neighbor_pos = chunk_pos + direction["offset"]
		var heights = _get_neighbor_chunk_heights(gridmap, neighbor_pos, chunk_size)
		if heights.size() > 0:
			neighbor_data[direction["name"]] = heights

	return neighbor_data

func _get_neighbor_chunk_heights(gridmap: GridMap, neighbor_chunk_pos: Vector2i, chunk_size: Vector2i) -> Array:
	"""Отримує висоти з сусіднього чанка"""
	var heights = []

	# Перевіряємо чи чанк існує (спрощена перевірка)
	# В повній реалізації треба перевірити чи чанк завантажений
	var neighbor_chunk_start = neighbor_chunk_pos * chunk_size

	# Збираємо висоти з краю сусіднього чанка (перші кілька блоків)
	for i in range(min(3, chunk_size.x)):  # Беремо перші 3 блоки для smoothing
		var world_x = neighbor_chunk_start.x + i
		var world_z = neighbor_chunk_start.y + i
		var height = _sample_height_from_existing_terrain(gridmap, world_x, world_z)
		heights.append(height)

	return heights

func _sample_height_from_existing_terrain(gridmap: GridMap, x: int, z: int) -> int:
	"""Визначає висоту з існуючих блоків у GridMap"""
	# Шукаємо найвищий блок у цій позиції
	for y in range(_get_max_height(), -1, -1):  # Перевіряємо зверху вниз
		var cell_item = gridmap.get_cell_item(Vector3i(x, y, z))
		if cell_item >= 0:  # Блок існує
			return y + 1  # Висота поверхні

	# Якщо блоки не знайдені, повертаємо базову висоту
	return _clamp_height(base_height)

func _is_boundary_block(x: int, z: int, chunk_start: Vector2i, chunk_size: Vector2i) -> bool:
	"""Перевіряє чи блок знаходиться на границі чанка"""
	var local_x = x - chunk_start.x
	var local_z = z - chunk_start.y

	# Граничні блоки - це блоки на краю чанка (перші та останні рядки/стовпці)
	return local_x <= 1 or local_x >= chunk_size.x - 2 or local_z <= 1 or local_z >= chunk_size.y - 2

func _get_height_with_boundary_smoothing(x: int, z: int, neighbor_heights: Dictionary) -> int:
	"""Обчислює висоту з smoothing для граничних блоків"""
	var base_height = _clamp_height(int(noise.get_noise_2d(x, z) * height_amplitude) + self.base_height)

	# Якщо є дані сусідів, використовуємо їх для smoothing
	if neighbor_heights.size() > 0:
		var neighbor_avg = _calculate_neighbor_average_height(neighbor_heights)
		# Змішуємо висоту з середнім значенням сусідів (70% власна, 30% сусідів)
		base_height = int(base_height * 0.7 + neighbor_avg * 0.3)

	return _clamp_height(base_height)

func _calculate_neighbor_average_height(neighbor_heights: Dictionary) -> float:
	"""Обчислює середню висоту з даних сусідніх чанків"""
	var total_height = 0
	var count = 0

	for neighbor_name in neighbor_heights.keys():
		var heights = neighbor_heights[neighbor_name]
		for height in heights:
			total_height += height
			count += 1

	return float(total_height) / count if count > 0 else base_height

func _set_blocks_at_position(gridmap: GridMap, x: int, z: int, surface_height: int):
	"""Встановлює блоки в позиції (x, z) до заданої висоти поверхні з врахуванням біомів"""
	# Отримуємо біом та його характеристики
	var biome_data = get_biome_at_position(x, z)
	var clamped_height = _clamp_height(surface_height)

	for y in range(clamped_height):
		var block_id: String

		# Визначення типу блоку залежно від висоти та біому
		if y < clamped_height - 2:
			block_id = biome_data["stone_block"]
		elif y < clamped_height - 1:
			block_id = biome_data["dirt_block"]
		else:
			block_id = biome_data["surface_block"]

		var mesh_index = get_mesh_index_for_block(gridmap, block_id)
		if mesh_index >= 0:
			gridmap.set_cell_item(Vector3i(x, y, z), mesh_index)

func _clamp_height(value: int) -> int:
	return clamp(value, 0, _get_max_height())

func _get_max_height() -> int:
	if get_parent() and get_parent().has_method("get_max_height"):
		return max(get_parent().get_max_height(), 1)
	return max_height

func get_mesh_index_for_block(gridmap: GridMap, block_name: String) -> int:
	"""Fallback функція для отримання mesh index з пріоритетом:
	1. BlockRegistry (якщо доступний)
	2. Пошук у gridmap.mesh_library за ім’ям
	3. Жорстка мапа як останній резерв
	"""
	if not gridmap:
		return -1

	# Спроба 1: BlockRegistry
	if BlockRegistry and BlockRegistry.has_method("get_mesh_index"):
		var index = BlockRegistry.get_mesh_index(block_name)
		if index >= 0:
			return index

	# Спроба 2: Пошук у mesh_library за ім’ям
	if gridmap.mesh_library:
		var item_ids := gridmap.mesh_library.get_item_list()
		for item_id in item_ids:
			var item_name = gridmap.mesh_library.get_item_name(item_id)
			if item_name.to_lower().contains(block_name.to_lower()):
				return item_id

	# Спроба 3: Жорстка мапа як резерв
	var fallback_map = {
		"grass": 0,
		"dirt": 1,
		"stone": 2
	}

	return fallback_map.get(block_name, -1)

# Biome Transitions - методи для роботи з біомами

func get_biome_at_position(x: int, z: int) -> Dictionary:
	"""Визначає біом в заданій позиції з blending"""
	if not enable_biomes:
		return _get_default_biome()

	# Отримуємо біоми в цій точці та навколо неї для blending
	var biome_weights = _calculate_biome_weights(x, z)

	# Якщо є тільки один біом, повертаємо його
	if biome_weights.size() == 1:
		var biome_name = biome_weights.keys()[0]
		return _get_biome_data(biome_name)

	# Blending між біомами
	return _blend_biomes(biome_weights)

func _calculate_biome_weights(x: int, z: int) -> Dictionary:
	"""Обчислює ваги біомів в точці для blending"""
	var weights = {}

	# Визначаємо біоми в точці та навколо неї
	var sample_points = [
		Vector2(x, z),  # Центр
		Vector2(x + biome_blend_distance, z),  # Схід
		Vector2(x - biome_blend_distance, z),  # Захід
		Vector2(x, z + biome_blend_distance),  # Південь
		Vector2(x, z - biome_blend_distance),  # Північ
	]

	for point in sample_points:
		var biome_name = _get_biome_name_at_point(point)
		if not weights.has(biome_name):
			weights[biome_name] = 0.0

		# Додаємо вагу залежно від відстані до центру
		var distance = point.distance_to(Vector2(x, z))
		var weight = 1.0 / (1.0 + distance / biome_blend_distance)
		weights[biome_name] += weight

	# Нормалізуємо ваги
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight

	for biome_name in weights.keys():
		weights[biome_name] /= total_weight

	return weights

func _get_biome_name_at_point(point: Vector2) -> String:
	"""Визначає ім'я біому в точці"""
	if not noise:
		return "plains"

	# Використовуємо шум для визначення біому
	var biome_value = noise.get_noise_2d(point.x / biome_scale, point.y / biome_scale)

	# Простий розподіл біомів залежно від шуму
	if biome_value < -0.5:
		return "desert"
	elif biome_value < 0.0:
		return "plains"
	elif biome_value < 0.5:
		return "forest"
	else:
		return "mountains"

func _get_biome_data(biome_name: String) -> Dictionary:
	"""Повертає характеристики біому"""
	var biomes = {
		"plains": {
			"surface_block": "grass",
			"dirt_block": "dirt",
			"stone_block": "stone",
			"height_modifier": 0.0,
			"color": Color.GREEN
		},
		"forest": {
			"surface_block": "grass",
			"dirt_block": "dirt",
			"stone_block": "stone",
			"height_modifier": 1.0,
			"color": Color.DARK_GREEN
		},
		"desert": {
			"surface_block": "sand",
			"dirt_block": "sand",
			"stone_block": "stone",
			"height_modifier": -0.5,
			"color": Color.YELLOW
		},
		"mountains": {
			"surface_block": "stone",
			"dirt_block": "dirt",
			"stone_block": "stone",
			"height_modifier": 2.0,
			"color": Color.GRAY
		}
	}

	return biomes.get(biome_name, _get_default_biome())

func _get_default_biome() -> Dictionary:
	"""Повертає дефолтний біом"""
	return {
		"surface_block": "grass",
		"dirt_block": "dirt",
		"stone_block": "stone",
		"height_modifier": 0.0,
		"color": Color.GREEN
	}

func _blend_biomes(biome_weights: Dictionary) -> Dictionary:
	"""Змішує характеристики біомів"""
	var blended = {
		"surface_block": "grass",
		"dirt_block": "dirt",
		"stone_block": "stone",
		"height_modifier": 0.0,
		"color": Color.GREEN
	}

	# Знаходимо біом з найбільшою вагою для основних блоків
	var max_weight = 0.0
	var dominant_biome = "plains"

	for biome_name in biome_weights.keys():
		if biome_weights[biome_name] > max_weight:
			max_weight = biome_weights[biome_name]
			dominant_biome = biome_name

	var dominant_data = _get_biome_data(dominant_biome)

	# Використовуємо блоки домінуючого біому
	blended["surface_block"] = dominant_data["surface_block"]
	blended["dirt_block"] = dominant_data["dirt_block"]
	blended["stone_block"] = dominant_data["stone_block"]

	# Змішуємо числові характеристики
	for biome_name in biome_weights.keys():
		var biome_data = _get_biome_data(biome_name)
		var weight = biome_weights[biome_name]

		blended["height_modifier"] += biome_data["height_modifier"] * weight
		blended["color"] = blended["color"].lerp(biome_data["color"], weight * 0.5)

	return blended

# Cave Generation - методи для генерації печер

func generate_caves_in_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація печер в чанку"""
	if not enable_caves:
		return

	var chunk_start = chunk_pos * chunk_size

	# Створюємо окремий шум для печер
	var cave_noise = FastNoiseLite.new()
	cave_noise.seed = noise.seed + 1000  # Різний seed від основного шуму
	cave_noise.frequency = cave_noise_scale

	# Проходимо по всіх блоках чанка
	for x in range(chunk_start.x, chunk_start.x + chunk_size.x):
		for z in range(chunk_start.y, chunk_start.y + chunk_size.y):
			# Генеруємо печери тільки під землею (нижче рівня 8)
			for y in range(8):
				var cave_value = cave_noise.get_noise_3d(x, y, z)

				# Якщо шум перевищує поріг cave_density, створюємо порожнечу
				if cave_value > cave_density:
					gridmap.set_cell_item(Vector3i(x, y, z), -1)  # Видаляємо блок

func carve_cave_tunnel(gridmap: GridMap, start_pos: Vector3i, length: int, radius: float):
	"""Заготовка для генерації тунелів печер"""
	# В майбутньому: генерувати звивисті тунелі
	pass

func add_cave_features(gridmap: GridMap, cave_pos: Vector3i):
	"""Заготовка для додавання фіч печер (руд, сталактитів тощо)"""
	# В майбутньому: додавати руду, кристали, воду в печерах
	pass
