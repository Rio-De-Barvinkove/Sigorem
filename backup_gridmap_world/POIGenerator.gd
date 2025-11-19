extends Node
class_name POIGenerator

# Points of Interest Generator
# Створює цікаві локації: печери, руїни, особливі біоми, схованки

@export_group("POI Settings")
@export var enable_poi_generation := false  # Вимкнено поки - заготовка
@export var poi_density := 0.05  # Ймовірність POI в чанку
@export var min_distance_between_pois := 5  # Мінімальна відстань між POI (в чанках)

@export_group("POI Types")
@export var generate_caves := true
@export var generate_ruins := false  # Заготовка
@export var generate_shrines := false  # Заготовка
@export var generate_treasure_sites := false  # Заготовка

@export_group("Cave Settings")
@export var cave_min_size := 10
@export var cave_max_size := 50
@export var cave_entrance_probability := 0.3

@export_group("Biome POI")
@export var generate_special_biomes := false  # Заготовка
@export var special_biome_size := 3  # Радіус в чанках

var generated_pois = {}  # Vector2i -> {"type": String, "data": Dictionary}
var poi_noise: FastNoiseLite

func _ready():
	initialize_noise()

func initialize_noise():
	"""Ініціалізація шуму для генерації POI"""
	poi_noise = FastNoiseLite.new()
	poi_noise.seed = 99999  # Фіксований seed для консистентності
	poi_noise.frequency = 0.01

func generate_pois_for_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація POI для чанка"""
	if not enable_poi_generation:
		return

	# Перевірити чи вже є POI в цьому чанку
	if generated_pois.has(chunk_pos):
		return

	# Перевірити чи немає POI занадто близько
	if is_too_close_to_existing_poi(chunk_pos):
		return

	# Визначити тип POI
	var poi_type = determine_poi_type(chunk_pos)

	if poi_type:
		generate_poi_of_type(gridmap, chunk_pos, chunk_size, poi_type)

func determine_poi_type(chunk_pos: Vector2i) -> String:
	"""Визначити тип POI для чанка"""
	if not poi_noise:
		return ""

	var noise_value = poi_noise.get_noise_2d(chunk_pos.x, chunk_pos.y)

	# Простий розподіл типів POI
	if generate_caves and noise_value < -0.7:
		return "cave"
	elif generate_ruins and noise_value < -0.3:
		return "ruins"
	elif generate_shrines and noise_value < 0.0:
		return "shrine"
	elif generate_treasure_sites and noise_value < 0.3:
		return "treasure"
	elif generate_special_biomes and noise_value < 0.7:
		return "special_biome"

	return ""

func generate_poi_of_type(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i, poi_type: String):
	"""Згенерувати POI заданого типу"""
	match poi_type:
		"cave":
			generate_cave_poi(gridmap, chunk_pos, chunk_size)
		"ruins":
			generate_ruins_poi(gridmap, chunk_pos, chunk_size)
		"shrine":
			generate_shrine_poi(gridmap, chunk_pos, chunk_size)
		"treasure":
			generate_treasure_poi(gridmap, chunk_pos, chunk_size)
		"special_biome":
			generate_special_biome_poi(gridmap, chunk_pos, chunk_size)

	# Зареєструвати POI
	generated_pois[chunk_pos] = {
		"type": poi_type,
		"chunk_pos": chunk_pos,
		"generated_at": Time.get_time_dict_from_system()
	}

func generate_cave_poi(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація печери як POI
	
	ВИПРАВЛЕНО: Видалено дублювання з procedural_module.generate_caves_in_chunk().
	Тепер тільки створює вхід до печери на поверхні, а не генерує всю печеру.
	"""
	var cave_size = cave_min_size + randi() % (cave_max_size - cave_min_size)
	var cave_center = Vector2i(
		chunk_pos.x * chunk_size.x + chunk_size.x / 2,
		chunk_pos.y * chunk_size.y + chunk_size.y / 2
	)

	# ВИПРАВЛЕНО: Тільки створюємо вхід до печери на поверхні
	# Сама печера генерується через procedural_module.generate_caves_in_chunk()
	var entrance_pos = find_surface_position_near(gridmap, cave_center, 5)
	if entrance_pos:
		# Створити вертикальний вхід
		var min_height = -64
		if get_parent() and get_parent().has_method("get_min_height"):
			min_height = get_parent().get_min_height()
		
		var entrance_depth = min(5, entrance_pos.y - min_height)
		for y in range(entrance_pos.y, entrance_pos.y - entrance_depth, -1):
			gridmap.set_cell_item(Vector3i(entrance_pos.x, y, entrance_pos.z), -1)

		# Додати факел біля входу (заготовка)
		# add_torch_at_position(gridmap, entrance_pos + Vector3i(1, entrance_pos.y - 4, 0))

	# Познака що це POI печери
	print("POIGenerator: Згенеровано вхід до печери в чанку ", chunk_pos)

func generate_ruins_poi(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація руїн (заготовка)"""
	# В майбутньому: згенерувати старі стіни, колони, скарби
	print("POIGenerator: Заготовка для руїн в чанку ", chunk_pos)

func generate_shrine_poi(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація святилища (заготовка)"""
	# В майбутньому: згенерувати altar, декоративні елементи
	print("POIGenerator: Заготовка для святилища в чанку ", chunk_pos)

func generate_treasure_poi(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація схованки зі скарбом (заготовка)"""
	# В майбутньому: заховати скарб під землею або в печері
	print("POIGenerator: Заготовка для скарбу в чанку ", chunk_pos)

func generate_special_biome_poi(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація особливого біому (заготовка)"""
	# В майбутньому: створити унікальний біом в радіусі кількох чанків
	print("POIGenerator: Заготовка для особливого біому в чанку ", chunk_pos)

func is_too_close_to_existing_poi(chunk_pos: Vector2i) -> bool:
	"""Перевірити чи POI не занадто близько до існуючих"""
	for existing_pos in generated_pois.keys():
		var distance = chunk_pos.distance_to(existing_pos)
		if distance < min_distance_between_pois:
			return true
	return false

func find_surface_position_near(gridmap: GridMap, center: Vector2i, search_radius: int) -> Vector3i:
	"""Знайти позицію поверхні біля центру
	
	ВИПРАВЛЕНО: Тепер використовує procedural_module.get_height_at() замість пошуку від y=20.
	Це працює для високих чанків (100+).
	"""
	# ВИПРАВЛЕНО: Отримуємо min_height та max_height
	var min_height = -64  # Дефолт
	var max_height = 192  # Дефолт
	
	if get_parent() and get_parent().has_method("get_min_height"):
		min_height = get_parent().get_min_height()
	if get_parent() and get_parent().has_method("get_max_height"):
		max_height = get_parent().get_max_height()
	
	# ВИПРАВЛЕНО: Використовуємо procedural_module.get_height_at() для отримання висоти
	var procedural = null
	if get_parent() and get_parent().procedural_module:
		procedural = get_parent().procedural_module
	
	for x in range(center.x - search_radius, center.x + search_radius):
		for z in range(center.y - search_radius, center.y + search_radius):
			var surface_y = 0
			
			# ВИПРАВЛЕНО: Отримуємо висоту через procedural_module або GridMap
			if procedural and procedural.has_method("get_height_at"):
				surface_y = procedural.get_height_at(x, z)
			else:
				# Fallback: шукаємо найвищий блок від max_height вниз
				for y in range(max_height - 1, min_height - 1, -1):
					if gridmap.get_cell_item(Vector3i(x, y, z)) >= 0:
						surface_y = y + 1
						break
			
			if surface_y > 0:
				return Vector3i(x, surface_y, z)  # Поверхня

	return Vector3i()  # Не знайдено

func get_poi_at_position(chunk_pos: Vector2i) -> Dictionary:
	"""Отримати інформацію про POI в чанку"""
	return generated_pois.get(chunk_pos, {})

func get_all_pois() -> Dictionary:
	"""Отримати всі згенеровані POI"""
	return generated_pois.duplicate()

func get_pois_in_radius(center: Vector2i, radius: int) -> Array:
	"""Отримати POI в радіусі"""
	var result = []
	for poi_pos in generated_pois.keys():
		if center.distance_to(poi_pos) <= radius:
			result.append({
				"position": poi_pos,
				"data": generated_pois[poi_pos]
			})
	return result

func get_poi_stats() -> Dictionary:
	"""Статистика POI"""
	var stats = {}
	for poi_pos in generated_pois.keys():
		var poi_type = generated_pois[poi_pos]["type"]
		if not stats.has(poi_type):
			stats[poi_type] = 0
		stats[poi_type] += 1

	return {
		"total_pois": generated_pois.size(),
		"by_type": stats
	}

func remove_poi_for_chunk(chunk_pos: Vector2i):
	"""Видалити POI для чанка при unload
	
	ВИПРАВЛЕНО: Додано очищення старих POI при unload чанка.
	Це запобігає витокам пам'яті при довгій грі.
	"""
	if generated_pois.has(chunk_pos):
		generated_pois.erase(chunk_pos)
		if enable_poi_generation:
			print("POIGenerator: Видалено POI для чанка ", chunk_pos)

func clear_old_pois(max_distance: float):
	"""Очистити старі POI за межами радіуса
	
	ВИПРАВЛЕНО: Додано метод для очищення старих POI за межами радіуса.
	Використовується для запобігання витокам пам'яті.
	"""
	if not get_parent() or not get_parent().player:
		return
	
	var player_pos = get_parent().player.global_position
	var player_chunk = Vector2i(int(player_pos.x / 50), int(player_pos.z / 50))  # Припускаємо chunk_size = 50
	
	var pois_to_remove = []
	for poi_pos in generated_pois.keys():
		var distance = player_chunk.distance_to(poi_pos)
		if distance > max_distance:
			pois_to_remove.append(poi_pos)
	
	for poi_pos in pois_to_remove:
		generated_pois.erase(poi_pos)
	
	if pois_to_remove.size() > 0 and enable_poi_generation:
		print("POIGenerator: Очищено ", pois_to_remove.size(), " старих POI за межами радіуса ", max_distance)

# Future features - заготовки

func add_poi_marker(position: Vector3, poi_type: String, label: String):
	"""Додати маркер POI на мінімапу (заготовка)"""
	pass

func create_poi_quest(poi_pos: Vector2i, poi_type: String) -> Dictionary:
	"""Створити квест пов'язаний з POI"""
	# В майбутньому: повернути структуру квесту
	return {}

func get_poi_difficulty(poi_type: String) -> int:
	"""Отримати складність POI"""
	var difficulties = {
		"cave": 2,
		"ruins": 3,
		"shrine": 4,
		"treasure": 1,
		"special_biome": 5
	}
	return difficulties.get(poi_type, 1)

func spawn_poi_guardians(poi_pos: Vector2i, poi_type: String):
	"""Створити охоронців для POI (заготовка)"""
	pass
