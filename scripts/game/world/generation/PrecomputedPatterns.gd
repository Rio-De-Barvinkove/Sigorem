extends Node
class_name PrecomputedPatterns

# Модуль для попередньо обчислених патернів
# Best practice: зменшити CPU навантаження під час runtime

@export var pattern_resolution := 256
@export var num_patterns := 10
@export var pattern_scale := 0.1

var terrain_patterns: Array = []
var structure_patterns: Array = []
var biome_patterns: Array = []

func _ready():
	precompute_terrain_patterns()
	precompute_structure_patterns()
	precompute_biome_patterns()
	print("PrecomputedPatterns: Обчислено ", terrain_patterns.size() + structure_patterns.size() + biome_patterns.size(), " патернів")

func precompute_terrain_patterns():
	"""Попереднє обчислення патернів місцевості"""
	terrain_patterns.clear()

	for i in range(num_patterns):
		var pattern = create_terrain_pattern(i)
		terrain_patterns.append(pattern)

	print("PrecomputedPatterns: Створено ", terrain_patterns.size(), " патернів місцевості")

func create_terrain_pattern(seed_offset: int) -> Dictionary:
	"""Створення одного патерну місцевості"""
	var pattern = {
		"height_map": [],
		"steepness_map": [],
		"biome_map": [],
		"resolution": pattern_resolution,
		"seed": seed_offset
	}

	# Генеруємо height map
	pattern.height_map.resize(pattern_resolution * pattern_resolution)
	for x in range(pattern_resolution):
		for z in range(pattern_resolution):
			var index = x + z * pattern_resolution
			var noise_val = generate_pattern_noise(x, z, seed_offset, 0.01)
			pattern.height_map[index] = noise_val

	# Генеруємо steepness map
	pattern.steepness_map.resize(pattern_resolution * pattern_resolution)
	for x in range(pattern_resolution):
		for z in range(pattern_resolution):
			var index = x + z * pattern_resolution
			var steepness = calculate_pattern_steepness(pattern.height_map, x, z, pattern_resolution)
			pattern.steepness_map[index] = steepness

	# Генеруємо biome map
	pattern.biome_map.resize(pattern_resolution * pattern_resolution)
	for x in range(pattern_resolution):
		for z in range(pattern_resolution):
			var index = x + z * pattern_resolution
			var biome = determine_biome(pattern.height_map[index], pattern.steepness_map[index])
			pattern.biome_map[index] = biome

	return pattern

func generate_pattern_noise(x: int, z: int, seed_offset: int, scale: float) -> float:
	"""Генерація шуму для патерну"""
	# Використовуємо кілька октав для реалістичного вигляду
	var value = 0.0
	var amplitude = 1.0
	var frequency = scale

	for octave in range(4):
		value += sin((x + seed_offset * 100) * frequency) * cos((z + seed_offset * 150) * frequency) * amplitude
		amplitude *= 0.5
		frequency *= 2.0

	return (value + 1.0) * 0.5  # Нормалізуємо до 0-1

func calculate_pattern_steepness(height_map: Array, x: int, z: int, resolution: int) -> float:
	"""Розрахунок крутизни в патерні"""
	if x <= 0 or x >= resolution - 1 or z <= 0 or z >= resolution - 1:
		return 0.0

	var center = height_map[x + z * resolution]
	var left = height_map[(x - 1) + z * resolution]
	var right = height_map[(x + 1) + z * resolution]
	var up = height_map[x + (z - 1) * resolution]
	var down = height_map[x + (z + 1) * resolution]

	var grad_x = abs(right - left) / 2.0
	var grad_z = abs(down - up) / 2.0

	return sqrt(grad_x * grad_x + grad_z * grad_z)

func determine_biome(height: float, steepness: float) -> int:
	"""Визначення біому на основі висоти та крутизни"""
	if height < 0.3:
		return 0  # Вода/пляж
	elif height < 0.6:
		if steepness < 0.2:
			return 1  # Ліси/луки
		else:
			return 2  # Гори
	else:
		if steepness < 0.3:
			return 3  # Плато
		else:
			return 4  # Вершини гір

func precompute_structure_patterns():
	"""Попереднє обчислення патернів структур"""
	structure_patterns.clear()

	# Створюємо базові патерни для різних типів структур
	var structure_types = ["house", "cave", "tower", "bridge", "ruins"]

	for type_name in structure_types:
		var pattern = create_structure_pattern(type_name)
		structure_patterns.append(pattern)

	print("PrecomputedPatterns: Створено ", structure_patterns.size(), " патернів структур")

func create_structure_pattern(type_name: String) -> Dictionary:
	"""Створення патерну для структури"""
	var pattern = {
		"type": type_name,
		"layout": [],
		"size": Vector2i(8, 8),
		"probability": 0.1
	}

	# Генеруємо простий layout залежно від типу
	match type_name:
		"house":
			pattern.layout = generate_house_layout()
		"cave":
			pattern.layout = generate_cave_layout()
		"tower":
			pattern.layout = generate_tower_layout()
		"bridge":
			pattern.layout = generate_bridge_layout()
		"ruins":
			pattern.layout = generate_ruins_layout()

	return pattern

func generate_house_layout() -> Array:
	"""Генерація layout для будинку"""
	var layout = []
	var size = Vector2i(5, 5)

	for x in range(size.x):
		for z in range(size.y):
			var block_type = "air"  # За замовчуванням повітря

			# Стіни
			if x == 0 or x == size.x - 1 or z == 0 or z == size.z - 1:
				block_type = "stone"
			# Основа
			elif x >= 1 and x <= size.x - 2 and z >= 1 and z <= size.z - 2:
				block_type = "wood"  # Підлога з дерева

			layout.append(block_type)

	return layout

func generate_cave_layout() -> Array:
	"""Генерація layout для печери"""
	var layout = []
	var size = Vector2i(8, 8)

	for x in range(size.x):
		for z in range(size.y):
			var block_type = "air"

			# Стіни печери (органічний вигляд)
			var distance_from_center = Vector2(x - size.x/2, z - size.y/2).length()
			if distance_from_center > 3.0:
				block_type = "stone"
			elif randf() < 0.3:  # Деякі нерівності
				block_type = "stone"

			layout.append(block_type)

	return layout

func generate_tower_layout() -> Array:
	"""Генерація layout для вежі"""
	var layout = []
	var size = Vector2i(4, 4)

	for x in range(size.x):
		for z in range(size.y):
			var block_type = "stone"  # Вежа з каменю

			# Двері в центрі нижнього рівня
			if x == size.x/2 and z == 0:
				block_type = "air"

			layout.append(block_type)

	return layout

func generate_bridge_layout() -> Array:
	"""Генерація layout для мосту"""
	var layout = []
	var size = Vector2i(10, 3)

	for x in range(size.x):
		for z in range(size.y):
			var block_type = "air"

			# Опорні стовпи
			if (x == 0 or x == size.x - 1) and z < size.y - 1:
				block_type = "stone"
			# Доріжка мосту
			elif z == size.y - 1:
				block_type = "wood"

			layout.append(block_type)

	return layout

func generate_ruins_layout() -> Array:
	"""Генерація layout для руїн"""
	var layout = []
	var size = Vector2i(6, 6)

	for x in range(size.x):
		for z in range(size.y):
			var block_type = "stone"

			# Випадково руйнуємо структуру
			if randf() < 0.4:
				block_type = "air"
			elif randf() < 0.2:
				block_type = "cobblestone"  # Руйнований камінь

			layout.append(block_type)

	return layout

func precompute_biome_patterns():
	"""Попереднє обчислення біомних патернів"""
	biome_patterns.clear()

	var biomes = ["forest", "desert", "mountain", "plains", "swamp"]

	for biome_name in biomes:
		var pattern = create_biome_pattern(biome_name)
		biome_patterns.append(pattern)

	print("PrecomputedPatterns: Створено ", biome_patterns.size(), " біомних патернів")

func create_biome_pattern(biome_name: String) -> Dictionary:
	"""Створення патерну для біому"""
	var pattern = {
		"name": biome_name,
		"vegetation_density": 0.5,
		"vegetation_types": [],
		"ground_types": [],
		"color_scheme": Color.WHITE
	}

	# Налаштовуємо характеристики біому
	match biome_name:
		"forest":
			pattern.vegetation_density = 0.8
			pattern.vegetation_types = ["tree", "bush", "grass"]
			pattern.ground_types = ["grass", "dirt"]
			pattern.color_scheme = Color(0.2, 0.6, 0.2)
		"desert":
			pattern.vegetation_density = 0.1
			pattern.vegetation_types = ["cactus", "dry_grass"]
			pattern.ground_types = ["sand", "sandstone"]
			pattern.color_scheme = Color(0.9, 0.8, 0.5)
		"mountain":
			pattern.vegetation_density = 0.3
			pattern.vegetation_types = ["pine_tree", "rock"]
			pattern.ground_types = ["stone", "snow"]
			pattern.color_scheme = Color(0.7, 0.7, 0.8)
		"plains":
			pattern.vegetation_density = 0.6
			pattern.vegetation_types = ["grass", "flower", "wheat"]
			pattern.ground_types = ["grass", "dirt"]
			pattern.color_scheme = Color(0.4, 0.8, 0.3)
		"swamp":
			pattern.vegetation_density = 0.4
			pattern.vegetation_types = ["reed", "mushroom", "swamp_tree"]
			pattern.ground_types = ["mud", "water"]
			pattern.color_scheme = Color(0.3, 0.4, 0.2)

	return pattern

func get_terrain_pattern(index: int) -> Dictionary:
	"""Отримання патерну місцевості"""
	if index >= 0 and index < terrain_patterns.size():
		return terrain_patterns[index]
	return terrain_patterns[0] if terrain_patterns.size() > 0 else {}

func get_structure_pattern(type_name: String) -> Dictionary:
	"""Отримання патерну структури"""
	for pattern in structure_patterns:
		if pattern.type == type_name:
			return pattern
	return {}

func get_biome_pattern(biome_name: String) -> Dictionary:
	"""Отримання біомного патерну"""
	for pattern in biome_patterns:
		if pattern.name == biome_name:
			return pattern
	return {}

func get_random_terrain_pattern() -> Dictionary:
	"""Отримання випадкового патерну місцевості"""
	if terrain_patterns.size() > 0:
		return terrain_patterns[randi() % terrain_patterns.size()]
	return {}

func get_random_structure_pattern() -> Dictionary:
	"""Отримання випадкового патерну структури"""
	if structure_patterns.size() > 0:
		return structure_patterns[randi() % structure_patterns.size()]
	return {}

func get_random_biome_pattern() -> Dictionary:
	"""Отримання випадкового біомного патерну"""
	if biome_patterns.size() > 0:
		return biome_patterns[randi() % biome_patterns.size()]
	return {}

func interpolate_patterns(pattern1: Dictionary, pattern2: Dictionary, factor: float) -> Dictionary:
	"""Інтерполяція між двома патернами"""
	var result = pattern1.duplicate()

	# Інтерполюємо числові значення
	if pattern1.has("vegetation_density") and pattern2.has("vegetation_density"):
		result.vegetation_density = lerp(pattern1.vegetation_density, pattern2.vegetation_density, factor)

	# Інтерполюємо кольори
	if pattern1.has("color_scheme") and pattern2.has("color_scheme"):
		result.color_scheme = pattern1.color_scheme.lerp(pattern2.color_scheme, factor)

	return result

func save_patterns_to_file(file_path: String):
	"""Збереження всіх патернів у файл"""
	var data = {
		"terrain_patterns": terrain_patterns,
		"structure_patterns": structure_patterns,
		"biome_patterns": biome_patterns,
		"metadata": {
			"pattern_resolution": pattern_resolution,
			"num_patterns": num_patterns,
			"generation_time": Time.get_unix_time_from_system()
		}
	}

	var json_string = JSON.stringify(data)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("PrecomputedPatterns: Патерни збережено у ", file_path)

func load_patterns_from_file(file_path: String) -> bool:
	"""Завантаження патернів з файлу"""
	if not FileAccess.file_exists(file_path):
		return false

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error == OK:
		var data = json.data
		terrain_patterns = data.get("terrain_patterns", [])
		structure_patterns = data.get("structure_patterns", [])
		biome_patterns = data.get("biome_patterns", [])
		print("PrecomputedPatterns: Патерни завантажено з ", file_path)
		return true

	return false
