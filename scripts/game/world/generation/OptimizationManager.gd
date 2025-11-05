extends Node
class_name OptimizationManager

# Модуль для оптимізації генерації терейну

@export_group("Performance Settings")
@export var max_generation_time_per_frame := 100.0  # ms (збільшено для початкової генерації)
@export var max_initial_generation_time := 500.0  # ms для початкової генерації
@export var target_fps := 60
@export var max_active_chunks := 50
@export var lod_distances := [25.0, 50.0, 100.0, 200.0]
@export var lod_resolutions := [1.0, 0.8, 0.6, 0.4]
@export var enable_initial_generation_override := true  # Дозволити тривалу генерацію на старті
@export var log_performance_warnings := false  # Вимкнути зайві логи

var generation_start_time: int
var frame_start_time: int
var performance_stats: Dictionary = {}
var is_initial_generation := true
var initial_generation_complete := false

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
		var chunk_world_pos = Vector2(chunk_pos.x * 50, chunk_pos.y * 50)  # Припускаємо chunk_size
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
	return report

func get_active_chunk_count() -> int:
	"""Отримати кількість активних чанків"""
	if get_parent() and get_parent().chunk_module:
		return get_parent().chunk_module.active_chunks.size()
	return 0

# Кеш для зберігання даних терейну
var terrain_cache: Dictionary = {}
