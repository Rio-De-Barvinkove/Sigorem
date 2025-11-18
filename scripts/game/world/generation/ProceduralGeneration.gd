extends Node
class_name ProceduralGeneration

# Модуль для базової процедурної генерації терейну з шуму

const DEFAULT_CHUNK_SIZE := Vector2i(32, 32)

var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var height_amplitude := 5
var base_height := 5
var min_height := -64   # Мінімальна висота для шарів під землею (оптимізовано)
var max_height := 192   # Збільшена максимальна висота (оптимізовано)

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
@export var enable_caves := true  # УВІМКНЕНО - генерація печер через 3D шум
@export var cave_density := 0.4    # Поріг шуму для печер (0.0-1.0, вище = більше печер)
@export var cave_noise_scale := 0.03  # Масштаб шуму печер (менше = більші печери)
@export var cave_min_height := 1  # Мінімальна висота для генерації печер
@export var cave_max_height_offset := -3  # Відступ від поверхні (щоб не було дірок зверху)

func _ready():
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.05
	
	if not biome_noise:
		biome_noise = FastNoiseLite.new()
		biome_noise.seed = (noise.seed if noise else randi()) + 9137
		biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		biome_noise.frequency = 1.0 / max(biome_scale, 0.001)
		biome_noise.fractal_octaves = 1

	if not terrain_color_steepness_curve:
		terrain_color_steepness_curve = Curve.new()
		terrain_color_steepness_curve.add_point(Vector2(0.0, 0.0))
		terrain_color_steepness_curve.add_point(Vector2(1.0, 1.0))

	if not terrain_material:
		terrain_material = StandardMaterial3D.new()
		terrain_material.vertex_color_use_as_albedo = true
	
	# ВИПРАВЛЕНО: Синхронізуємо height_amplitude та base_height з TerrainGenerator
	# Це виправляє проблему з висотою завжди 5 замість 32/16
	# Використовуємо call_deferred щоб parent був готовий
	call_deferred("_sync_with_parent")

func generate_terrain(gridmap: GridMap, start_pos: Vector2i, size: Vector2i):
	"""Генерація терейну в заданій області"""
	if not gridmap or not noise:
		push_error("ProceduralGeneration: GridMap або noise не встановлені!")
		return

	print("ProceduralGeneration: Генерація терейну від ", start_pos, " розміром ", size)

	for x in range(start_pos.x, start_pos.x + size.x):
		for z in range(start_pos.y, start_pos.y + size.y):
			var height = _clamp_height(int(noise.get_noise_2d(x, z) * height_amplitude) + base_height)
			_set_blocks_at_position(gridmap, x, z, height)

func generate_chunk(gridmap: GridMap, chunk_pos: Vector2i, optimization: Dictionary = {}):
	"""Генерація окремого чанка з оптимізацією та врахуванням границь"""
	# Отримуємо chunk_size з батьківського chunk_module або використовуємо дефолт
	var chunk_size = DEFAULT_CHUNK_SIZE
	if get_parent() and get_parent().has_method("get_chunk_size"):
		chunk_size = get_parent().get_chunk_size()

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

	var context = prepare_chunk_context(gridmap, chunk_pos, chunk_size)

	# Генеруємо терейн з врахуванням границь
	for x in range(chunk_start.x, chunk_start.x + chunk_size.x):
		for z in range(chunk_start.y, chunk_start.y + chunk_size.y):
			generate_column_with_context(gridmap, context, x, z)

	# Генеруємо печери після основного терейну
	if enable_caves:
		_carve_caves_full_with_context(gridmap, context)

func prepare_chunk_context(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i) -> Dictionary:
	"""Готує контекст для поступової генерації чанка"""
	var chunk_start = chunk_pos * chunk_size
	var context: Dictionary = {
		"chunk_pos": chunk_pos,
		"chunk_size": chunk_size,
		"chunk_start": chunk_start,
		"neighbor_heights": _gather_neighbor_chunk_data(gridmap, chunk_pos, chunk_size),
		"height_cache": {},
		"caves_enabled": enable_caves
	}

	if enable_caves:
		context["cave_noise"] = _create_cave_noise()

	return context

func generate_column_with_context(gridmap: GridMap, context: Dictionary, world_x: int, world_z: int):
	if not gridmap:
		push_error("[ProceduralGeneration] generate_column_with_context: GridMap is null для координат (" + str(world_x) + ", " + str(world_z) + ")")
		return
	
	if not is_instance_valid(gridmap):
		push_error("[ProceduralGeneration] generate_column_with_context: GridMap не валідний для координат (" + str(world_x) + ", " + str(world_z) + ")")
		return
	
	if context.is_empty():
		push_error("[ProceduralGeneration] generate_column_with_context: Context порожній для координат (" + str(world_x) + ", " + str(world_z) + ")")
		return
	
	if not noise:
		push_error("[ProceduralGeneration] generate_column_with_context: Noise не встановлений")
		return

	# Перевірка валідності координат
	if world_x < -10000 or world_x > 10000 or world_z < -10000 or world_z > 10000:
		push_error("[ProceduralGeneration] generate_column_with_context: Невалідні координати: (" + str(world_x) + ", " + str(world_z) + ")")
		return

	var chunk_start: Vector2i = context.get("chunk_start", Vector2i.ZERO)
	var chunk_size: Vector2i = context.get("chunk_size", Vector2i.ZERO)
	var neighbor_heights: Dictionary = context.get("neighbor_heights", {})

	if not context.has("height_cache"):
		context["height_cache"] = {}

	var height := _clamp_height(int(noise.get_noise_2d(world_x, world_z) * height_amplitude) + base_height)

	if neighbor_heights.size() > 0 and _is_boundary_block(world_x, world_z, chunk_start, chunk_size):
		height = _get_height_with_boundary_smoothing(world_x, world_z, neighbor_heights)

	_set_blocks_at_position(gridmap, world_x, world_z, height)
	context["height_cache"][_column_cache_key(world_x, world_z)] = height

func carve_caves_column_with_context(gridmap: GridMap, context: Dictionary, world_x: int, world_z: int):
	if not enable_caves or not gridmap or context.is_empty():
		return

	var cave_noise: FastNoiseLite = context.get("cave_noise", null)
	if not cave_noise:
		return

	var column_key = _column_cache_key(world_x, world_z)
	var surface_height = context["height_cache"].get(column_key, get_height_at(world_x, world_z))
	context["height_cache"][column_key] = surface_height

	var max_cave_height = max(cave_min_height, surface_height + cave_max_height_offset)
	for y in range(cave_min_height, max_cave_height):
		var cave_value = cave_noise.get_noise_3d(world_x, y, world_z)
		var height_factor = 1.0 - (float(y) / max(1, max_cave_height))
		var adjusted_threshold = cave_density - (height_factor * 0.2)

		if cave_value > adjusted_threshold:
			gridmap.set_cell_item(Vector3i(world_x, y, world_z), -1)

func _carve_caves_full_with_context(gridmap: GridMap, context: Dictionary):
	if not enable_caves:
		return

	var chunk_start: Vector2i = context["chunk_start"]
	var chunk_size: Vector2i = context["chunk_size"]
	for x in range(chunk_start.x, chunk_start.x + chunk_size.x):
		for z in range(chunk_start.y, chunk_start.y + chunk_size.y):
			carve_caves_column_with_context(gridmap, context, x, z)

func _column_cache_key(x: int, z: int) -> String:
	return str(x) + "_" + str(z)

func _create_cave_noise() -> FastNoiseLite:
	var cave_noise = FastNoiseLite.new()
	cave_noise.seed = (noise.seed if noise else randi()) + 1000
	cave_noise.frequency = cave_noise_scale
	cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cave_noise.fractal_octaves = 2
	return cave_noise

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

	# ВИПРАВЛЕНО: використовуємо noise замість GridMap (детермінований результат)
	var neighbor_chunk_start = neighbor_chunk_pos * chunk_size

	# Збираємо висоти з краю сусіднього чанка (перші кілька блоків)
	for i in range(min(3, chunk_size.x)):  # Беремо перші 3 блоки для smoothing
		var world_x = neighbor_chunk_start.x + i
		var world_z = neighbor_chunk_start.y + i
		# Використовуємо noise для визначення висоти (той самий алгоритм що й для генерації)
		var height = _clamp_height(int(noise.get_noise_2d(world_x, world_z) * height_amplitude) + base_height)
		heights.append(height)

	return heights

func _sample_height_from_existing_terrain(gridmap: GridMap, x: int, z: int) -> int:
	"""Визначає висоту з існуючих блоків у GridMap (ЗАСТАРІЛИЙ - використовувати тільки для fallback)"""
	# ВИПРАВЛЕНО: використовуємо noise для детермінованого результату
	# GridMap може ще не мати згенерованих блоків
	return _clamp_height(int(noise.get_noise_2d(x, z) * height_amplitude) + base_height)

func _is_boundary_block(x: int, z: int, chunk_start: Vector2i, chunk_size: Vector2i) -> bool:
	"""Перевіряє чи блок знаходиться на границі чанка або в зоні smoothing"""
	var local_x = x - chunk_start.x
	var local_z = z - chunk_start.y

	# ВИПРАВЛЕНО: розширена зона smoothing (3 блоки від краю для кращого blending)
	var smoothing_width = 3
	return (local_x < smoothing_width or local_x >= chunk_size.x - smoothing_width or 
			local_z < smoothing_width or local_z >= chunk_size.y - smoothing_width)

func _get_height_with_boundary_smoothing(x: int, z: int, neighbor_heights: Dictionary) -> int:
	"""Обчислює висоту з smoothing для граничних блоків"""
	var base_height_val = _clamp_height(int(noise.get_noise_2d(x, z) * height_amplitude) + self.base_height)

	# ВИПРАВЛЕНО: покращений smoothing алгоритм
	# Використовуємо noise з сусідніх позицій для плавного переходу
	if neighbor_heights.size() > 0:
		var neighbor_avg = _calculate_neighbor_average_height(neighbor_heights)
		# Додатково беремо середнє з 4 сусідніх блоків через noise
		var nearby_heights = []
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var nearby_height = _clamp_height(int(noise.get_noise_2d(x + dx, z + dz) * height_amplitude) + self.base_height)
				nearby_heights.append(nearby_height)
		
		var nearby_avg = 0.0
		for h in nearby_heights:
			nearby_avg += h
		nearby_avg /= nearby_heights.size()
		
		# Змішуємо: 50% власна висота, 25% сусідні чанки, 25% сусідні блоки
		base_height_val = int(base_height_val * 0.5 + neighbor_avg * 0.25 + nearby_avg * 0.25)

	return _clamp_height(base_height_val)

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
	"""Встановлює блоки в позиції (x, z) від min_height до заданої висоти поверхні з врахуванням біомів"""
	if not gridmap:
		push_error("[ProceduralGeneration] _set_blocks_at_position: GridMap is null для координат (" + str(x) + ", " + str(z) + ")")
		return
	
	if not is_instance_valid(gridmap):
		push_error("[ProceduralGeneration] _set_blocks_at_position: GridMap не валідний для координат (" + str(x) + ", " + str(z) + ")")
		return
	
	# Перевірка валідності координат
	if x < -10000 or x > 10000 or z < -10000 or z > 10000:
		push_error("[ProceduralGeneration] _set_blocks_at_position: Невалідні координати: (" + str(x) + ", " + str(z) + ")")
		return
	
	# Отримуємо біом та його характеристики
	var biome_data = get_biome_at_position(x, z)
	if biome_data.is_empty():
		push_error("[ProceduralGeneration] _set_blocks_at_position: Не вдалося отримати біом для координат (" + str(x) + ", " + str(z) + ")")
		return
	
	var clamped_height = _clamp_height(surface_height)
	var min_y = _get_min_height()
	
	# Оптимізація: генеруємо тільки до розумної глибини під землею
	# Якщо поверхня висока, не заповнюємо весь простір до min_height
	var underground_depth = 32  # Максимальна глибина підземних шарів для генерації
	var start_y = max(min_y, clamped_height - underground_depth)

	# Перевірка валідності діапазону висот
	if start_y > clamped_height:
		# Немає блоків для генерації
		return

	# Генеруємо блоки від start_y до поверхні
	for y in range(start_y, clamped_height + 1):
		# Перевірка валідності координати Y
		if y < min_y or y >= _get_max_height():
			push_error("[ProceduralGeneration] _set_blocks_at_position: Невалідна координата Y: " + str(y) + " для позиції (" + str(x) + ", " + str(z) + ")")
			continue
		
		var block_id: String

		# Визначення типу блоку залежно від висоти та біому
		if y < clamped_height - 2:
			block_id = biome_data.get("stone_block", "stone")
		elif y < clamped_height - 1:
			block_id = biome_data.get("dirt_block", "dirt")
		else:
			block_id = biome_data.get("surface_block", "grass")

		var mesh_index = get_mesh_index_for_block(gridmap, block_id)
		if mesh_index >= 0:
			# Перевірка валідності перед встановленням
			if not is_instance_valid(gridmap):
				push_error("[ProceduralGeneration] _set_blocks_at_position: GridMap став невалідним під час встановлення блоку")
				break
			gridmap.set_cell_item(Vector3i(x, y, z), mesh_index)

func _clamp_height(value: int) -> int:
	return clamp(value, _get_min_height(), _get_max_height())

func _get_max_height() -> int:
	if get_parent() and get_parent().has_method("get_max_height"):
		return max(get_parent().get_max_height(), 1)
	return max_height

func _get_min_height() -> int:
	if get_parent() and get_parent().has_method("get_min_height"):
		return min(get_parent().get_min_height(), -1)
	return min_height

func _sync_with_parent():
	"""Синхронізувати параметри з батьківським TerrainGenerator
	
	ВИПРАВЛЕНО: Синхронізує height_amplitude та base_height з TerrainGenerator.
	Це виправляє проблему з висотою завжди 5 замість 32/16.
	"""
	if not get_parent():
		return
	
	# ВИПРАВЛЕНО: Синхронізуємо height_amplitude та base_height
	if "height_amplitude" in get_parent():
		height_amplitude = get_parent().height_amplitude
	if "base_height" in get_parent():
		base_height = get_parent().base_height
	
	# Синхронізуємо min_height та max_height
	if get_parent().has_method("get_max_height"):
		var parent_max_height = get_parent().get_max_height()
		if parent_max_height != max_height:
			max_height = parent_max_height

	if get_parent().has_method("get_min_height"):
		var parent_min_height = get_parent().get_min_height()
		if parent_min_height != min_height:
			min_height = parent_min_height
	
	# Синхронізуємо chunk_size якщо потрібно
	if get_parent().has_method("get_chunk_size"):
		var parent_chunk_size = get_parent().get_chunk_size()
		# Синхронізуємо якщо потрібно (поки що не використовується)

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
	if not biome_noise and not noise:
		return "plains"

	var scale = max(0.001, biome_scale)
	if biome_noise:
		biome_noise.frequency = 1.0 / scale

	var source_noise = biome_noise if biome_noise else noise

	# Використовуємо окремий шум для визначення біому
	var biome_value = source_noise.get_noise_2d(point.x / scale, point.y / scale)

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
	"""Генерація печер в чанку через 3D шум"""
	if not enable_caves:
		return

	var context = prepare_chunk_context(gridmap, chunk_pos, chunk_size)
	_carve_caves_full_with_context(gridmap, context)

func carve_cave_tunnel(gridmap: GridMap, start_pos: Vector3i, length: int, radius: float):
	"""Заготовка для генерації тунелів печер"""
	# В майбутньому: генерувати звивисті тунелі
	pass

func add_cave_features(gridmap: GridMap, cave_pos: Vector3i):
	"""Заготовка для додавання фіч печер (руд, сталактитів тощо)"""
	# В майбутньому: додавати руду, кристали, воду в печерах
	pass
