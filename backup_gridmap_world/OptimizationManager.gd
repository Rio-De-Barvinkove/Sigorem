extends Node
class_name OptimizationManager

# Модуль для оптимізації генерації терейну
# 
# ВАЖЛИВО: Mesh-оптимізація ВИМКНЕНА через критичні проблеми:
# 1. optimize_chunk_mesh() сканує весь чанк 6 разів на блок → для 50×50×192 = 10+ млн ітерацій → FPS падає до 1
# 2. _has_neighbor_block_in_adjacent_chunk() завжди повертає false → оптимізація граней не працює між чанками
# 3. Mesh-оптимізація не працює правильно з GridMap (система використовує GridMap, а не Mesh)
# 4. is_chunk_occluded() вважає чанк occluded, якщо всі сусіди існують → навпаки логіки
# 
# Корисне, що залишено:
# - adaptive_optimization() і check_generation_time() — добре для обмеження бюджету
# - LOD distances (можна використати)
# 
# Рекомендація: вимкнути use_optimization за замовчуванням (вже зроблено)

@export_group("Performance Settings")
@export var max_generation_time_per_frame := 100.0  # ms (збільшено для початкової генерації)
@export var max_initial_generation_time := 500.0  # ms для початкової генерації
@export var target_fps := 60
@export var max_active_chunks := 50
@export var lod_distances := [25.0, 50.0, 100.0, 200.0]
@export var lod_resolutions := [1.0, 0.8, 0.6, 0.4]
@export var enable_initial_generation_override := true  # Дозволити тривалу генерацію на старті
@export var log_performance_warnings := false  # Вимкнути зайві логи
@export var enable_profiling := false  # Увімкнути профілювання для діагностики

var generation_start_time: int
var frame_start_time: int
var performance_stats: Dictionary = {}
var is_initial_generation := true
var initial_generation_complete := false

# Профілювання
var profiling_data: Dictionary = {
	"optimize_chunk_mesh_calls": 0,
	"optimize_chunk_mesh_time": 0.0,
	"collect_chunk_data_calls": 0,
	"collect_chunk_data_time": 0.0,
	"rebuild_chunk_calls": 0,
	"rebuild_chunk_time": 0.0
}

func _ready():
	frame_start_time = Time.get_ticks_msec()

func _process(delta):
	# Моніторинг продуктивності
	monitor_performance()

	# Адаптивна оптимізація
	adaptive_optimization()

func start_generation_timer():
	"""Початок таймера генерації"""
	generation_start_time = Time.get_ticks_msec()

func check_generation_time() -> bool:
	"""Перевірка, чи не перевищено час генерації на кадр"""
	var time_limit = max_initial_generation_time if (is_initial_generation and enable_initial_generation_override) else max_generation_time_per_frame
	if Time.get_ticks_msec() - generation_start_time > time_limit:
		return false  # Перевищено час
	return true  # Можна продовжувати

func monitor_performance():
	"""Моніторинг продуктивності"""
	var current_time = Time.get_ticks_msec()
	var frame_time = current_time - frame_start_time
	frame_start_time = current_time

	performance_stats["fps"] = Engine.get_frames_per_second()
	performance_stats["frame_time"] = frame_time
	performance_stats["memory"] = OS.get_static_memory_usage()

	# Логування проблем з продуктивністю (тільки якщо увімкнено)
	if log_performance_warnings and frame_time > 1000.0 / target_fps:
		print("OptimizationManager: Низький FPS - ", performance_stats["fps"])

func adaptive_optimization():
	"""Адаптивна оптимізація залежно від продуктивності"""
	var fps = performance_stats.get("fps", 60)

	if fps < 30:
		# Агресивна оптимізація
		reduce_quality_settings()
		if log_performance_warnings:
			print("OptimizationManager: Агресивна оптимізація активована")
	elif fps < 50:
		# Помірна оптимізація
		moderate_quality_reduction()
		if log_performance_warnings:
			print("OptimizationManager: Помірна оптимізація активована")

func reduce_quality_settings():
	"""Зменшення якості для покращення продуктивності"""
	if get_parent():
		# Зменшуємо радіус чанків
		if get_parent().chunk_module:
			get_parent().chunk_module.chunk_radius = max(3, get_parent().chunk_module.chunk_radius - 1)

		# Вимикаємо дорогі функції
		if get_parent().vegetation_module:
			get_parent().vegetation_module.multimesh_coverage *= 0.8

		# Зменшуємо LOD відстані
		if get_parent().lod_module:
			for i in range(lod_distances.size()):
				lod_distances[i] *= 0.9

func moderate_quality_reduction():
	"""Помірне зменшення якості"""
	if get_parent():
		# Зменшуємо радіус чанків
		if get_parent().chunk_module:
			get_parent().chunk_module.chunk_radius = max(5, get_parent().chunk_module.chunk_radius - 1)

		# Трохи зменшуємо рослинність
		if get_parent().vegetation_module:
			get_parent().vegetation_module.multimesh_coverage *= 0.9

func optimize_chunk_generation(chunk_pos: Vector2i, distance_to_player: float) -> Dictionary:
	"""Оптимізація генерації чанка залежно від відстані"""
	var optimization = {
		"resolution": 1.0,
		"vegetation_density": 1.0,
		"detail_level": 1.0
	}

	# Визначаємо LOD рівень
	var lod_level = get_lod_level_for_distance(distance_to_player)

	# Застосовуємо LOD
	optimization["resolution"] = lod_resolutions[lod_level] if lod_level < lod_resolutions.size() else 0.3
	optimization["vegetation_density"] = max(0.1, 1.0 - (lod_level * 0.2))
	optimization["detail_level"] = max(0.1, 1.0 - (lod_level * 0.3))

	return optimization

func get_lod_level_for_distance(distance: float) -> int:
	"""Отримати LOD рівень для відстані"""
	for i in range(lod_distances.size()):
		if distance <= lod_distances[i]:
			return i
	return lod_distances.size()

func cache_terrain_data(chunk_pos: Vector2i, data: Dictionary):
	"""Кешування даних терейну для швидшого завантаження"""
	# Спрощена версія кешування
	# В реальності можна використовувати файловий кеш або базу даних
	var cache_key = str(chunk_pos.x) + "_" + str(chunk_pos.y)
	terrain_cache[cache_key] = data

func get_cached_terrain_data(chunk_pos: Vector2i) -> Dictionary:
	"""Отримання кешованих даних терейну"""
	var cache_key = str(chunk_pos.x) + "_" + str(chunk_pos.y)
	return terrain_cache.get(cache_key, {})

func clear_old_cache(distance_threshold: float):
	"""Очищення старого кеша"""
	# Видаляємо кеш для далеких чанків
	var keys_to_remove = []
	for key in terrain_cache.keys():
		var coords = key.split("_")
		if coords.size() >= 2:
			var chunk_pos = Vector2i(int(coords[0]), int(coords[1]))
			var distance = get_distance_to_player(chunk_pos)
			if distance > distance_threshold:
				keys_to_remove.append(key)

	for key in keys_to_remove:
		terrain_cache.erase(key)

func get_distance_to_player(chunk_pos: Vector2i) -> float:
	"""Отримати відстань від чанка до гравця"""
	if get_parent() and get_parent().player:
		var player_pos = get_parent().player.global_position
		var chunk_dimensions := Vector2i(32, 32)
		if get_parent() and get_parent().chunk_size:
			chunk_dimensions = get_parent().chunk_size
		var chunk_world_pos = Vector2(chunk_pos.x * chunk_dimensions.x, chunk_pos.y * chunk_dimensions.y)
		return chunk_world_pos.distance_to(Vector2(player_pos.x, player_pos.z))
	return 0.0

func preload_neighbor_chunks(center_chunk: Vector2i, radius: int):
	"""Попереднє завантаження сусідніх чанків"""
	var preload_queue = []

	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			if abs(x) + abs(z) <= radius:  # Ромбовидна форма
				var chunk_pos = center_chunk + Vector2i(x, z)
				if not is_chunk_loaded(chunk_pos):
					preload_queue.append(chunk_pos)

	# Сортуємо за відстанню (ближчі першими)
	preload_queue.sort_custom(func(a, b): return get_distance_to_player(a) < get_distance_to_player(b))

	return preload_queue

func is_chunk_loaded(chunk_pos: Vector2i) -> bool:
	"""Перевірка, чи завантажений чанк"""
	if get_parent() and get_parent().chunk_module:
		return get_parent().chunk_module.active_chunks.has(chunk_pos)
	return false

func set_initial_generation_complete():
	"""Позначити, що початкова генерація завершена"""
	is_initial_generation = false
	initial_generation_complete = true

func get_performance_report() -> String:
	"""Отримати звіт про продуктивність"""
	var report = "=== PERFORMANCE REPORT ===\n"
	report += "FPS: " + str(performance_stats.get("fps", 0)) + "\n"
	report += "Frame Time: " + str(performance_stats.get("frame_time", 0)) + "ms\n"
	report += "Memory: " + str(performance_stats.get("memory", 0) / 1024.0 / 1024.0) + "MB\n"
	report += "Active Chunks: " + str(get_active_chunk_count()) + "\n"
	report += "Cache Size: " + str(terrain_cache.size()) + "\n"
	
	if enable_profiling:
		report += "\n=== PROFILING DATA ===\n"
		report += "optimize_chunk_mesh: " + str(profiling_data.get("optimize_chunk_mesh_calls", 0)) + " calls, "
		report += str(profiling_data.get("optimize_chunk_mesh_time", 0.0)) + "ms total\n"
		var avg_time = profiling_data.get("optimize_chunk_mesh_time", 0.0) / max(1, profiling_data.get("optimize_chunk_mesh_calls", 1))
		report += "Average optimize_chunk_mesh time: " + str(avg_time) + "ms\n"
		report += "collect_chunk_data: " + str(profiling_data.get("collect_chunk_data_calls", 0)) + " calls, "
		report += str(profiling_data.get("collect_chunk_data_time", 0.0)) + "ms total\n"
		var avg_collect = profiling_data.get("collect_chunk_data_time", 0.0) / max(1, profiling_data.get("collect_chunk_data_calls", 1))
		report += "Average collect_chunk_data time: " + str(avg_collect) + "ms\n"
	
	return report

func get_active_chunk_count() -> int:
	"""Отримати кількість активних чанків"""
	if get_parent() and get_parent().chunk_module:
		return get_parent().chunk_module.active_chunks.size()
	return 0

# Кеш для зберігання даних терейну
var terrain_cache: Dictionary = {}

# Mesh Optimization - Cull Hidden Faces
# ВИМКНЕНО: Mesh-оптимізація не працює правильно з GridMap
@export_group("Mesh Optimization")
@export var enable_cull_hidden_faces := false  # ВИПРАВЛЕНО: Вимкнено за замовчуванням
@export var enable_greedy_meshing := false  # Зарезервовано для майбутнього
@export var enable_occlusion_culling := false  # ВИПРАВЛЕНО: Вимкнено через неправильну логіку

# Статистика оптимізації
var optimization_stats: Dictionary = {
	"faces_culled": 0,
	"total_faces": 0,
	"optimization_ratio": 0.0
}

func optimize_chunk_mesh(chunk_pos: Vector2i, chunk_data: Dictionary) -> Dictionary:
	"""Оптимізація mesh чанка через cull hidden faces
	
	ВИМКНЕНО: Сканує весь чанк 6 разів на блок → для 50×50×192 = 10+ млн ітерацій → FPS падає до 1.
	Mesh-оптимізація не працює правильно з GridMap (система використовує GridMap, а не Mesh).
	"""
	if not enable_cull_hidden_faces:
		return chunk_data
	
	# ВИПРАВЛЕНО: Повертаємо дані без змін, оскільки mesh-оптимізація вимкнена
	push_warning("[OptimizationManager] optimize_chunk_mesh() ВИМКНЕНО через критичні проблеми з продуктивністю!")
	return chunk_data

func _get_visible_faces(x: int, y: int, z: int, chunk_data: Dictionary, chunk_size: Vector2i, chunk_start: Vector2i) -> Array:
	"""Визначення видимих граней для блоку"""
	var visible_faces = []
	var directions = [
		{"name": "north", "offset": Vector3i(0, 0, -1), "face": 0},
		{"name": "south", "offset": Vector3i(0, 0, 1), "face": 1},
		{"name": "east", "offset": Vector3i(1, 0, 0), "face": 2},
		{"name": "west", "offset": Vector3i(-1, 0, 0), "face": 3},
		{"name": "up", "offset": Vector3i(0, 1, 0), "face": 4},
		{"name": "down", "offset": Vector3i(0, -1, 0), "face": 5}
	]

	for direction in directions:
		var neighbor_pos = Vector3i(x, y, z) + direction["offset"]
		var neighbor_key = str(neighbor_pos.x) + "_" + str(neighbor_pos.y) + "_" + str(neighbor_pos.z)

		# Перевіряємо чи є сусідній блок у цьому чанку
		if chunk_data.has(neighbor_key):
			continue  # Грань прихована

		# Для границь чанка перевіряємо сусідні чанки (якщо вони завантажені)
		if _is_chunk_boundary(neighbor_pos, chunk_start, chunk_size):
			if _has_neighbor_block_in_adjacent_chunk(neighbor_pos, direction["offset"]):
				continue  # Грань прихована блоком з сусіднього чанка

		# Грань видима
		visible_faces.append(direction["face"])

	return visible_faces

func _is_chunk_boundary(pos: Vector3i, chunk_start: Vector2i, chunk_size: Vector2i) -> bool:
	"""Перевірка чи позиція знаходиться на границі чанка"""
	var local_x = pos.x - chunk_start.x
	var local_z = pos.z - chunk_start.y
	return local_x <= 0 or local_x >= chunk_size.x - 1 or local_z <= 0 or local_z >= chunk_size.y - 1

func _has_neighbor_block_in_adjacent_chunk(pos: Vector3i, offset: Vector3i) -> bool:
	"""Перевірка чи є блок у сусідньому чанку
	
	ВАЖЛИВО: Завжди повертає false → оптимізація граней не працює між чанками.
	ВИМКНЕНО: Не використовується, оскільки mesh-оптимізація вимкнена.
	"""
	# ВИПРАВЛЕНО: Завжди повертає false (не працює правильно)
	# Спрощена версія - перевіряємо тільки якщо сусідній чанк завантажений
	# В повній реалізації треба отримати дані з ChunkManager
	# if not get_parent() or not get_parent().chunk_module:
	# 	return false
	# 
	# var neighbor_chunk_pos = _get_chunk_pos_for_world_pos(pos + offset)
	# if get_parent().chunk_module.active_chunks.has(neighbor_chunk_pos):
	# 	# Тут можна додати перевірку конкретного блоку в сусідньому чанку
	# 	# Зараз повертаємо false для спрощення
	# 	return false
	# 
	# return false
	return false

func _get_chunk_pos_for_world_pos(world_pos: Vector3i) -> Vector2i:
	"""Отримати позицію чанка для світової позиції"""
	var chunk_size = get_parent().chunk_size if get_parent() and get_parent().chunk_size else Vector2i(50, 50)
	return Vector2i(world_pos.x / chunk_size.x, world_pos.z / chunk_size.y)

func get_mesh_optimization_stats() -> Dictionary:
	"""Отримати статистику mesh оптимізації"""
	return optimization_stats.duplicate()

func is_chunk_occluded(chunk_pos: Vector2i, active_chunks: Dictionary, chunk_size: Vector2i) -> bool:
	"""Перевіряє чи чанк повністю закритий (occlusion culling)
	
	ВИПРАВЛЕНО: Логіка була навпаки - вважала чанк occluded, якщо всі сусіди існують.
	Це visibility culling, а не occlusion. ВИМКНЕНО через неправильну логіку.
	"""
	if not enable_occlusion_culling:
		return false

	# ВИПРАВЛЕНО: Повертаємо false (не occluded), оскільки логіка була неправильною
	# Простий occlusion culling: перевіряємо чи є чанки зверху
	# В повній реалізації треба перевіряти чи всі сусідні чанки вище по висоті
	# 
	# Перевіряємо чи всі 8 сусідніх чанків існують і вище
	# var neighbors_above = [
	# 	chunk_pos + Vector2i(0, -1),   # Північ
	# 	chunk_pos + Vector2i(1, -1),   # Північний-схід
	# 	chunk_pos + Vector2i(1, 0),    # Схід
	# 	chunk_pos + Vector2i(1, 1),    # Південний-схід
	# 	chunk_pos + Vector2i(0, 1),    # Південь
	# 	chunk_pos + Vector2i(-1, 1),   # Південний-захід
	# 	chunk_pos + Vector2i(-1, 0),   # Захід
	# 	chunk_pos + Vector2i(-1, -1),  # Північний-захід
	# ]
	# 
	# var all_neighbors_exist = true
	# for neighbor_pos in neighbors_above:
	# 	if not active_chunks.has(neighbor_pos):
	# 		all_neighbors_exist = false
	# 		break
	# 
	# # ВИПРАВЛЕНО: Логіка була навпаки - якщо всі сусіди є, це означає що чанк видимий, а не occluded
	# return not all_neighbors_exist  # Якщо не всі сусіди є, можливо чанк occluded
	
	return false  # ВИМКНЕНО: Повертаємо false (не occluded)

func optimize_rendering_for_chunk(chunk_pos: Vector2i, active_chunks: Dictionary, chunk_size: Vector2i) -> bool:
	"""Загальна оптимізація рендерингу для чанка"""
	# Комбінуємо frustum culling та occlusion culling
	var is_occluded = is_chunk_occluded(chunk_pos, active_chunks, chunk_size)

	# Якщо чанк occluded, можна його не рендерити
	if is_occluded:
		return false  # Не рендерити

	return true  # Рендерити

func reset_mesh_optimization_stats():
	"""Скинути статистику оптимізації"""
	optimization_stats = {
		"faces_culled": 0,
		"total_faces": 0,
		"optimization_ratio": 0.0
	}