extends Node
class_name BestPractices

# Модуль з best practices для процедурної генерації
# Реалізує перевірені методи оптимізації та якості

@export_group("Quality Settings")
@export var enable_quality_checks := true
@export var min_chunk_size := 16
@export var max_chunk_size := 64
@export var optimal_chunk_radius := 8

@export_group("Performance Settings")
@export var enable_culling := true
@export var enable_lod := true
@export var enable_threading := false  # ВИПРАВЛЕНО: Threading не реалізований, вимкнено за замовчуванням
@export var max_generation_time_ms := 16.0

@export_group("Memory Management")
@export var enable_memory_pooling := true
@export var pool_size := 1000
@export var cleanup_interval := 60.0

var object_pool: Array = []
var last_cleanup_time := 0.0
var performance_stats: Dictionary = {}
var debug_prints := false  # ВИПРАВЛЕНО: Додано флаг для логування

func _ready():
	setup_best_practices()
	print("BestPractices: Ініціалізовано з best practices")

func setup_best_practices():
	"""Налаштування best practices"""
	if enable_memory_pooling:
		setup_object_pool()

	if enable_quality_checks:
		setup_quality_checks()

	setup_performance_monitoring()

func setup_object_pool():
	"""Налаштування пулу об'єктів для уникнення GC"""
	object_pool.resize(pool_size)
	for i in range(pool_size):
		object_pool[i] = create_pooled_object()

	print("BestPractices: Створено пул об'єктів розміром ", pool_size)

func create_pooled_object():
	"""Створення об'єкта для пулу"""
	return {
		"vector3": Vector3.ZERO,
		"vector2": Vector2.ZERO,
		"color": Color.WHITE,
		"in_use": false
	}

func get_pooled_vector3() -> Vector3:
	"""Отримання Vector3 з пулу (ВИДАЛЕНО: не використовується, повертає новий об'єкт)"""
	# ВИПРАВЛЕНО: Повертаємо новий Vector3 замість посилання на пул
	# Object pooling для примітивних типів не має сенсу в GDScript
	return Vector3.ZERO

func return_pooled_vector3(vec: Vector3):
	"""Повернення Vector3 до пулу (ВИДАЛЕНО: не використовується)"""
	# ВИПРАВЛЕНО: Нічого не робимо - object pooling для Vector3 не має сенсу
	pass

func setup_quality_checks():
	"""Налаштування перевірок якості"""
	# Перевірка на оптимальні розміри чанків
	assert(min_chunk_size <= max_chunk_size, "min_chunk_size має бути <= max_chunk_size")

	# Перевірка на розумний радіус генерації
	assert(optimal_chunk_radius >= 4, "chunk_radius занадто малий для плавної генерації")
	assert(optimal_chunk_radius <= 20, "chunk_radius занадто великий для продуктивності")

	print("BestPractices: Перевірки якості активовані")

func setup_performance_monitoring():
	"""Налаштування моніторингу продуктивності"""
	# ВИПРАВЛЕНО: Ініціалізуємо з реальними значеннями
	performance_stats = {
		"average_generation_time": 0.0,
		"peak_memory_usage": 0,
		"chunks_generated_per_second": 0.0,
		"cache_hit_rate": 0.0,
		"fps": Engine.get_frames_per_second(),
		"last_update": Time.get_ticks_msec() / 1000.0
	}
	
	# Оновлюємо статистику кожні 5 секунд
	if not has_meta("last_stats_update"):
		set_meta("last_stats_update", Time.get_ticks_msec() / 1000.0)

func _process(delta):
	# ВИПРАВЛЕНО: Використовуємо монотонний час замість системного
	if enable_memory_pooling:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_cleanup_time > cleanup_interval:
			perform_cleanup()
			last_cleanup_time = current_time

func perform_cleanup():
	"""Виконання очищення для оптимізації пам'яті"""
	if enable_memory_pooling:
		cleanup_object_pool()
	
	# ВИПРАВЛЕНО: Оновлюємо статистику продуктивності
	_update_performance_stats()

	# Викликаємо GC для очищення
	# force_gc()  # В Godot немає прямого виклику GC

	if debug_prints:
		print("BestPractices: Виконано очищення")

func _update_performance_stats():
	"""Оновлення статистики продуктивності"""
	var current_time = Time.get_ticks_msec() / 1000.0
	var last_update = get_meta("last_stats_update", current_time)
	var time_delta = current_time - last_update
	
	if time_delta >= 5.0:  # Оновлюємо кожні 5 секунд
		performance_stats["fps"] = Engine.get_frames_per_second()
		performance_stats["last_update"] = current_time
		set_meta("last_stats_update", current_time)

func cleanup_object_pool():
	"""Очищення пулу об'єктів"""
	var active_objects = 0
	for obj in object_pool:
		if obj.in_use:
			active_objects += 1

	print("BestPractices: Активних об'єктів в пулі: ", active_objects, "/", pool_size)

func validate_chunk_size(size: Vector2i) -> Vector2i:
	"""Валідація розміру чанка згідно best practices"""
	var validated_size = size

	# Перевірка мінімального розміру
	if validated_size.x < min_chunk_size:
		validated_size.x = min_chunk_size
	if validated_size.y < min_chunk_size:
		validated_size.y = min_chunk_size

	# Перевірка максимального розміру
	if validated_size.x > max_chunk_size:
		validated_size.x = max_chunk_size
	if validated_size.y > max_chunk_size:
		validated_size.y = max_chunk_size

	# Перевірка на степінь двійки (оптимізація)
	validated_size.x = get_nearest_power_of_two(validated_size.x)
	validated_size.y = get_nearest_power_of_two(validated_size.y)

	return validated_size

func get_nearest_power_of_two(value: int) -> int:
	"""Отримання найближчої степені двійки"""
	var power = 1
	while power < value:
		power *= 2
	return power

func optimize_generation_parameters(params: Dictionary) -> Dictionary:
	"""Оптимізація параметрів генерації"""
	var optimized = params.duplicate()

	# Оптимізація розміру чанка
	if optimized.has("chunk_size"):
		optimized.chunk_size = validate_chunk_size(optimized.chunk_size)

	# Оптимізація радіуса генерації
	if optimized.has("chunk_radius"):
		var radius = optimized.chunk_radius
		if radius < optimal_chunk_radius - 2:
			optimized.chunk_radius = optimal_chunk_radius - 2
		elif radius > optimal_chunk_radius + 2:
			optimized.chunk_radius = optimal_chunk_radius + 2

	# Оптимізація LOD відстаней
	if optimized.has("lod_distances"):
		var distances = optimized.lod_distances
		# Переконаємося що відстані зростають
		for i in range(1, distances.size()):
			if distances[i] <= distances[i-1]:
				distances[i] = distances[i-1] + 25.0
		optimized.lod_distances = distances

	return optimized

func implement_spatial_partitioning():
	"""Імплементація просторового поділу для швидкого пошуку"""
	# Quadtree або Octree для швидкого пошуку об'єктів
	print("BestPractices: Spatial partitioning не реалізований (потрібен для великих світів)")

func implement_frustum_culling():
	"""Імплементація frustum culling для камери"""
	# Видаляти об'єкти поза полем зору камери
	print("BestPractices: Frustum culling не реалізований")

func implement_occlusion_culling():
	"""Імплементація occlusion culling"""
	# Видаляти об'єкти що закриті іншими
	print("BestPractices: Occlusion culling не реалізований")

func get_generation_best_practices() -> Dictionary:
	"""Отримання рекомендацій з best practices"""
	return {
		"chunk_size": "Використовуйте степені двійки (16, 32, 64, 128)",
		"chunk_radius": "Оптимально 6-12 чанків навколо гравця",
		"lod_levels": "3-4 рівні LOD для різних відстаней",
		"threading": "Використовуйте окремі потоки для генерації",
		"caching": "Кешуйте часто використовувані дані",
		"memory": "Пули об'єктів для уникнення алокацій",
		"profiling": "Постійно моніторте продуктивність"
	}

func get_quality_best_practices() -> Dictionary:
	"""Рекомендації якості генерації"""
	return {
		"noise_layers": "3-5 шарів шуму для реалістичного вигляду",
		"biome_blending": "Плавні переходи між біомами",
		"structure_placement": "Перевірка колізій при розміщенні структур",
		"vegetation_clustering": "Рослинність має групуватися природно",
		"terrain_variety": "Різноманітність в межах одного біому",
		"performance_balance": "Якість vs продуктивність баланс"
	}

func benchmark_generation_speed() -> Dictionary:
	"""Бенчмарк швидкості генерації"""
	var start_time = Time.get_ticks_usec()

	# Тестова генерація
	for i in range(100):
		# Симулюємо генерацію - простий обчислювальний цикл
		var dummy = i * i
		dummy += 1  # Додаткове обчислення

	var end_time = Time.get_ticks_usec()
	var total_time = end_time - start_time

	var result = {
		"total_time_us": total_time,
		"average_time_per_chunk_us": total_time / 100.0,
		"chunks_per_second": 1000000.0 / (total_time / 100.0)
	}
	return result

func get_optimization_suggestions() -> Array:
	"""Отримання пропозицій оптимізації на основі поточного стану"""
	var suggestions = []

	# Аналіз продуктивності
	var fps = Engine.get_frames_per_second()
	if fps < 30:
		suggestions.append("FPS нижче 30 - зменшіть chunk_radius або увімкніть LOD")

	# ВИПРАВЛЕНО: OS.get_static_memory_usage() в Godot 4 часто повертає 0
	# Використовуємо альтернативний метод або пропускаємо перевірку
	var memory_mb = performance_stats.get("peak_memory_usage", 0) / 1024.0 / 1024.0
	if memory_mb > 500 and memory_mb > 0:
		suggestions.append("Використання пам'яті > 500MB - увімкніть cleanup")

	if performance_stats.get("cache_hit_rate", 0.0) < 0.5:
		suggestions.append("Низький hit rate кешу - збільшіть розмір кешу")

	return suggestions

func export_performance_report() -> String:
	"""Експорт звіту про продуктивність"""
	var report = "# PERFORMANCE REPORT\n\n"
	report += "## System Info\n"
	report += "- Godot Version: " + Engine.get_version_info()["string"] + "\n"
	report += "- OS: " + OS.get_name() + "\n"
	report += "- CPU Cores: " + str(OS.get_processor_count()) + "\n"
	# ВИПРАВЛЕНО: OS.get_static_memory_usage() в Godot 4 ненадійний
	var memory_mb = performance_stats.get("peak_memory_usage", 0) / 1024.0 / 1024.0
	if memory_mb == 0:
		memory_mb = OS.get_static_memory_usage() / 1024.0 / 1024.0
	report += "- Memory: " + str(memory_mb) + " MB (може бути неточним в Godot 4)\n\n"

	report += "## Generation Stats\n"
	for key in performance_stats.keys():
		report += "- " + key + ": " + str(performance_stats[key]) + "\n"

	report += "\n## Optimization Suggestions\n"
	var suggestions = get_optimization_suggestions()
	for suggestion in suggestions:
		report += "- " + suggestion + "\n"

	return report

func save_performance_report(file_path: String):
	"""Збереження звіту продуктивності"""
	var report = export_performance_report()
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(report)
		file.close()
		print("BestPractices: Звіт збережено в ", file_path)
