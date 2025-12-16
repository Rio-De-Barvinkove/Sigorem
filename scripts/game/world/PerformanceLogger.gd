extends Node
class_name PerformanceLogger
## Логер продуктивності для моніторингу та профілювання гри
##
## Збирає метрики:
## - Час генерації чанків
## - Використання пам'яті
## - Статистика рендерингу (objects, memory)
## - FPS та frame time
## - Кількість активних об'єктів
##
## Використання:
## PerformanceLogger.log_chunk_generation_time(15000)  # 15ms
## PerformanceLogger.log_memory_usage(50000000)       # 50MB
## var avg_fps = PerformanceLogger.get_average_fps()

# Налаштування
const MAX_SAMPLES = 100  # Максимальна кількість зразків для усереднення
const LOG_INTERVAL = 5.0  # Інтервал логування в секундах

# Метрики генерації чанків
var chunk_generation_times: Array[float] = []
var total_chunks_generated: int = 0
var average_chunk_generation_time: float = 0.0

# Метрики пам'яті
var memory_usage_history: Array[int] = []
var peak_memory_usage: int = 0
var current_memory_usage: int = 0

# Метрики рендерингу
var draw_calls_history: Array = []  # тимчасово без типізації через проблеми сумісності
var vertices_history: Array = []   # тимчасово без типізації через проблеми сумісності
var average_draw_calls: int = 0
var average_vertices: int = 0

# FPS метрики
var fps_history: Array[float] = []
var average_fps: float = 0.0
var min_fps: float = INF
var max_fps: float = 0.0

# Загальні метрики
var frame_times: Array[float] = []
var active_chunks_history: Array[int] = []
var last_log_time: float = 0.0

# Прапорці для діагностики
var enable_detailed_logging: bool = true
var enable_memory_tracking: bool = true
var enable_render_tracking: bool = true


func _ready() -> void:
	## Ініціалізація логера
	last_log_time = Time.get_ticks_msec() / 1000.0
	print("PerformanceLogger: Initialized")


func _process(delta: float) -> void:
	# Temporarily disabled to reduce console spam during persistence testing
	return
	## Оновлення метрик кожного кадру
	update_fps_metrics()
	update_render_metrics()
	update_memory_metrics()

	# Періодичне логування
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_log_time >= LOG_INTERVAL:
		log_periodic_report()
		last_log_time = current_time


func update_fps_metrics() -> void:
	## Оновлення FPS метрик
	var current_fps = Performance.get_monitor(Performance.TIME_FPS)
	var current_frame_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0  # в ms

	fps_history.append(current_fps)
	frame_times.append(current_frame_time)

	# Обмеження історії
	if fps_history.size() > MAX_SAMPLES:
		fps_history.remove_at(0)
	if frame_times.size() > MAX_SAMPLES:
		frame_times.remove_at(0)

	# Розрахунок середніх значень
	average_fps = calculate_average(fps_history)
	min_fps = min(min_fps, current_fps)
	max_fps = max(max_fps, current_fps)


func update_memory_metrics() -> void:
	## Оновлення метрик пам'яті
	var current_mem = OS.get_static_memory_usage()
	current_memory_usage = current_mem
	if current_mem > peak_memory_usage:
		peak_memory_usage = current_mem


func update_render_metrics() -> void:
	## Оновлення метрик рендерингу
	if not enable_render_tracking:
		return

	# Використовуємо доступні метрики рендерингу для цієї версії Godot
	var total_objects_variant = Performance.get_monitor(Performance.OBJECT_COUNT)
	var memory_usage_variant = Performance.get_monitor(Performance.MEMORY_STATIC)

	# Конвертуємо Variant в int з перевірками
	var total_objects = 0
	var memory_usage = 0

	if total_objects_variant is int:
		total_objects = total_objects_variant
	elif total_objects_variant is float:
		total_objects = int(total_objects_variant)
	else:
		total_objects = 0

	if memory_usage_variant is int:
		memory_usage = memory_usage_variant
	elif memory_usage_variant is float:
		memory_usage = int(memory_usage_variant)
	else:
		memory_usage = 0

	# Зберігаємо як draw_calls і vertices для сумісності з API
	# draw_calls = кількість об'єктів у сцені
	# vertices = використання статичної пам'яті в KB
	var draw_calls = total_objects
	var vertices = int(memory_usage / 1000)  # в кілобайтах, конвертуємо в int

	draw_calls_history.append(draw_calls)
	vertices_history.append(vertices)

	# Обмеження історії
	if draw_calls_history.size() > MAX_SAMPLES:
		draw_calls_history.remove_at(0)
	if vertices_history.size() > MAX_SAMPLES:
		vertices_history.remove_at(0)

	# Розрахунок середніх значень
	average_draw_calls = calculate_average_int(draw_calls_history)
	average_vertices = calculate_average_int(vertices_history)


func calculate_average(values: Array) -> float:
	## Розрахунок середнього значення масиву
	if values.is_empty():
		return 0.0

	var sum = 0.0
	for value in values:
		sum += value
	return sum / values.size()


func calculate_average_int(values: Array) -> int:
	## Розрахунок середнього цілочисельного значення
	if values.is_empty():
		return 0

	var sum = 0
	for value in values:
		sum += value
	return int(sum / values.size())


# === API МЕТОДИ ДЛЯ ЛОГУВАННЯ ===

static func log_chunk_generation_time(time_usec: int) -> void:
	## Логування часу генерації одного чанка
	var instance = get_instance()
	if not instance:
		return

	var time_ms = time_usec / 1000.0
	instance.chunk_generation_times.append(time_ms)
	instance.total_chunks_generated += 1

	# Обмеження історії
	if instance.chunk_generation_times.size() > MAX_SAMPLES:
		instance.chunk_generation_times.remove_at(0)

	# Оновлення середнього часу
	instance.average_chunk_generation_time = instance.calculate_average(instance.chunk_generation_times)

	if instance.enable_detailed_logging:
		print("PerformanceLogger: Chunk generated in %.2f ms" % time_ms)


static func log_memory_usage(bytes: int) -> void:
	## Логування використання пам'яті
	var instance = get_instance()
	if not instance:
		return

	if not instance.enable_memory_tracking:
		return

	instance.memory_usage_history.append(bytes)
	instance.current_memory_usage = bytes
	instance.peak_memory_usage = max(instance.peak_memory_usage, bytes)

	# Обмеження історії
	if instance.memory_usage_history.size() > MAX_SAMPLES:
		instance.memory_usage_history.remove_at(0)

	if instance.enable_detailed_logging:
		var mb = bytes / 1000000.0
		print("PerformanceLogger: Memory usage: %.2f MB" % mb)


static func log_active_chunks(count: int) -> void:
	## Логування кількості активних чанків
	var instance = get_instance()
	if not instance:
		return

	instance.active_chunks_history.append(count)

	# Обмеження історії
	if instance.active_chunks_history.size() > MAX_SAMPLES:
		instance.active_chunks_history.remove_at(0)

	if instance.enable_detailed_logging:
		print("PerformanceLogger: Active chunks: ", count)


static func log_custom_metric(name: String, value: float, unit: String = "") -> void:
	## Логування кастомної метрики
	var instance = get_instance()
	if not instance or not instance.enable_detailed_logging:
		return

	if unit.is_empty():
		print("PerformanceLogger: %s = %.2f" % [name, value])
	else:
		print("PerformanceLogger: %s = %.2f %s" % [name, value, unit])


# === GETTER МЕТОДИ ===

static func get_average_chunk_generation_time() -> float:
	## Отримання середнього часу генерації чанка
	var instance = get_instance()
	if not instance:
		return 0.0
	return instance.average_chunk_generation_time


static func get_average_fps() -> float:
	## Отримання середнього FPS
	var instance = get_instance()
	if not instance:
		return 0.0
	return instance.average_fps


static func get_min_fps() -> float:
	## Отримання мінімального FPS
	var instance = get_instance()
	if not instance:
		return 0.0
	return instance.min_fps


static func get_max_fps() -> float:
	## Отримання максимального FPS
	var instance = get_instance()
	if not instance:
		return 0.0
	return instance.max_fps


static func get_average_frame_time() -> float:
	## Отримання середнього часу кадру в ms
	var instance = get_instance()
	if not instance:
		return 0.0
	return instance.calculate_average(instance.frame_times)


static func get_current_memory_usage() -> int:
	## Отримання поточного використання пам'яті
	var instance = get_instance()
	if not instance:
		return 0
	return instance.current_memory_usage


static func get_peak_memory_usage() -> int:
	## Отримання пікового використання пам'яті
	var instance = get_instance()
	if not instance:
		return 0
	return instance.peak_memory_usage


static func get_average_draw_calls() -> int:
	## Отримання середньої кількості draw calls
	var instance = get_instance()
	if not instance:
		return 0
	return instance.average_draw_calls


static func get_average_vertices() -> int:
	## Отримання середньої кількості вершин
	var instance = get_instance()
	if not instance:
		return 0
	return instance.average_vertices


static func get_total_chunks_generated() -> int:
	## Отримання загальної кількості згенерованих чанків
	var instance = get_instance()
	if not instance:
		return 0
	return instance.total_chunks_generated


# === ДІАГНОСТИЧНІ МЕТОДИ ===

static func log_periodic_report() -> void:
	## Періодичний звіт про продуктивність
	var instance = get_instance()
	if not instance:
		return

	print("\n=== PERFORMANCE REPORT ===")
	print("FPS: avg=%.1f, min=%.1f, max=%.1f" % [instance.average_fps, instance.min_fps, instance.max_fps])
	print("Frame Time: avg=%.2f ms" % instance.get_average_frame_time())
	print("Chunks: generated=%d, avg_time=%.2f ms" % [instance.total_chunks_generated, instance.average_chunk_generation_time])
	print("Memory: current=%d MB, peak=%d MB" % [instance.current_memory_usage / 1000000, instance.peak_memory_usage / 1000000])
	print("Rendering: objects=%d, memory=%d KB" % [instance.average_draw_calls, instance.average_vertices])
	print("========================\n")


static func reset_metrics() -> void:
	## Скидання всіх метрик
	var instance = get_instance()
	if not instance:
		return

	instance.chunk_generation_times.clear()
	instance.memory_usage_history.clear()
	instance.draw_calls_history.clear()
	instance.vertices_history.clear()
	instance.fps_history.clear()
	instance.frame_times.clear()
	instance.active_chunks_history.clear()

	instance.total_chunks_generated = 0
	instance.average_chunk_generation_time = 0.0
	instance.peak_memory_usage = 0
	instance.current_memory_usage = 0
	instance.average_draw_calls = 0
	instance.average_vertices = 0
	instance.average_fps = 0.0
	instance.min_fps = INF
	instance.max_fps = 0.0

	print("PerformanceLogger: All metrics reset")


static func get_instance() -> PerformanceLogger:
	## Отримання єдиного екземпляра PerformanceLogger
	var tree = Engine.get_main_loop()
	if not tree:
		return null

	# Шукаємо PerformanceLogger в сцені
	return tree.root.find_child("PerformanceLogger", true, false) as PerformanceLogger


# === НАЛАШТУВАННЯ ===

static func set_detailed_logging(enabled: bool) -> void:
	## Увімкнення/вимкнення детального логування
	var instance = get_instance()
	if instance:
		instance.enable_detailed_logging = enabled
		print("PerformanceLogger: Detailed logging ", "enabled" if enabled else "disabled")


static func set_memory_tracking(enabled: bool) -> void:
	## Увімкнення/вимкнення відстеження пам'яті
	var instance = get_instance()
	if instance:
		instance.enable_memory_tracking = enabled
		print("PerformanceLogger: Memory tracking ", "enabled" if enabled else "disabled")


static func set_render_tracking(enabled: bool) -> void:
	## Увімкнення/вимкнення відстеження рендерингу
	var instance = get_instance()
	if instance:
		instance.enable_render_tracking = enabled
		print("PerformanceLogger: Render tracking ", "enabled" if enabled else "disabled")
