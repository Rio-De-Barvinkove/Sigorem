extends Node
class_name ChunkManager

# Модуль для управління чанками (адаптовано з infinite_heightmap_terrain)

@export var player: Node3D
var chunk_size := Vector2i(50, 50)
var chunk_radius := 5
var enable_culling := true
var max_distance := 100.0
var enable_frustum_culling := true
@export var enable_spatial_partitioning := true
@export var spatial_margin_chunks := 2
@export_range(0, 8, 1) var max_chunk_generations_per_frame := 1
@export var max_chunk_clear_ops_per_frame := 4000
# Видалено initial_sync_radius - не використовується
@export var chunk_generation_budget_per_frame := 64

var active_chunks: Dictionary = {}  # Vector2i -> metadata
var current_player_chunk: Vector2i

var spatial_index: Quadtree
# Видалено pending_chunk_generations - дублювання з chunk_generation_jobs
# Видалено pending_generation_lookup - дублювання, використовуємо is_chunk_loaded_or_pending()
var chunk_removal_jobs: Array = []
var chunk_generation_jobs: Array = []
var chunk_generation_job_lookup: Dictionary = {}

enum ChunkState {
	NONE,
	PRELOADED,
	GENERATING,
	ACTIVE,
	UNLOADING
}

# Захист від занадто частого видалення чанків
var last_cull_time: float = 0.0
var min_cull_interval: float = 0.5  # Мінімальний інтервал між видаленнями (секунди)
var max_chunks_to_remove_per_frame: int = 3  # Максимум чанків для видалення за кадр

# КРИТИЧНО: Обмеження на кількість активних чанків для запобігання крашам
@export var max_active_chunks: int = 80  # Максимальна кількість активних чанків
@export var warning_chunk_count: int = 70  # Кількість чанків при якій виводиться попередження

# Debug режим для логування
@export var debug_prints: bool = true  # Встановити true для детального логування (ВИМКНУТИ в релізі!)

# ВИДАЛЕНО: Preloading Buffer - система не використовується ефективно, видалена для спрощення коду

# Partial Mesh Updates - відстеження змінених блоків
var modified_blocks: Dictionary = {}  # Vector3i -> {"old_mesh": int, "new_mesh": int, "timestamp": float}
var max_modified_blocks_per_frame := 10  # Максимум оновлень за кадр
var block_modification_timeout := 1.0  # секунд, після яких зміни застарівають

func _ready():
	# Захист від ділення на 0
	if chunk_size.x <= 0 or chunk_size.y <= 0:
		push_error("[ChunkManager] _ready: chunk_size невалідний: " + str(chunk_size) + ", встановлюємо дефолт")
		chunk_size = Vector2i(32, 32)  # Дефолтний розмір
	
	_initialize_spatial_index()

func set_player(new_player: Node3D):
	"""Динамічне встановлення гравця"""
	player = new_player
	if player:
		update_player_chunk_position()

func _process(_delta):
	# Захист від крашів - обробка помилок
	if not is_inside_tree():
		return
	
	var gridmap: GridMap = null
	if get_parent():
		gridmap = get_parent().target_gridmap
	
	if not gridmap or not is_instance_valid(gridmap):
		# GridMap не валідний - пропускаємо обробку
		return

	# Логування статистики кожні 5 секунд
	if not has_meta("last_stats_log"):
		set_meta("last_stats_log", 0.0)
	var last_stats = get_meta("last_stats_log")
	if Time.get_ticks_msec() / 1000.0 - last_stats > 5.0:
		_log_chunk_statistics()
		set_meta("last_stats_log", Time.get_ticks_msec() / 1000.0)

	# ВИПРАВЛЕНО: update_chunk_culling() викликається всередині regenerate_chunks_around_player() з таймером
	# Перевіряємо тільки чи потрібно оновити чанки навколо гравця
	if player and is_instance_valid(player):
		var current_chunk = get_player_chunk_position()
		if current_chunk != current_player_chunk:
			if debug_prints:
				print("[ChunkManager] _process: Гравець перемістився з чанка ", current_player_chunk, " на ", current_chunk)
			current_player_chunk = current_chunk
			regenerate_chunks_around_player(gridmap)
	elif player and not is_instance_valid(player):
		push_error("[ChunkManager] _process: Гравець став невалідним!")
		player = null

	# Обробляємо partial mesh updates
	process_partial_updates(_delta)

	# ВИДАЛЕНО: Preload система не використовується ефективно
	# Обробка preload queue видалена - чанки генеруються через основну чергу
	
	# КРИТИЧНО: Перевірка ліміту активних чанків перед генерацією нових
	var current_active_count = active_chunks.size()
	if current_active_count >= max_active_chunks:
		push_error("[ChunkManager] _process: ДОСЯГНУТО ЛІМІТ АКТИВНИХ ЧАНКІВ! " + str(current_active_count) + " >= " + str(max_active_chunks) + ", примусове видалення найдальших чанків")
		_force_cull_excess_chunks(gridmap)
		return  # Пропускаємо генерацію нових чанків поки не звільнимо місце
	
	# ВИПРАВЛЕНО: process_generation_queue() видалена - jobs обробляються в _process_generation_jobs()
	_process_generation_jobs(gridmap)
	process_chunk_removals(gridmap)

func _log_chunk_statistics():
	"""Логування статистики чанків для діагностики"""
	var active_count = active_chunks.size()
	var pending_count = chunk_generation_jobs.size()
	var jobs_count = chunk_generation_jobs.size()
	var removal_jobs_count = chunk_removal_jobs.size()
	
	var player_chunk = get_player_chunk_position() if player else Vector2i.ZERO
	var player_pos = player.global_position if player else Vector3.ZERO
	
	# КРИТИЧНО: Попередження якщо кількість чанків наближається до ліміту
	if active_count >= warning_chunk_count:
		push_warning("[ChunkManager] _log_chunk_statistics: КРИТИЧНО! Кількість активних чанків: " + str(active_count) + " (ліміт: " + str(max_active_chunks) + ")")
	
	if active_count >= max_active_chunks:
		push_error("[ChunkManager] _log_chunk_statistics: ДОСЯГНУТО ЛІМІТ АКТИВНИХ ЧАНКІВ! " + str(active_count) + " >= " + str(max_active_chunks))
	
	if debug_prints:
		print("[ChunkManager] === СТАТИСТИКА ===")
		print("  Активних чанків: ", active_count, " / ", max_active_chunks, " (ліміт)")
		print("  В черзі генерації: ", pending_count)
		print("  Активних jobs генерації: ", jobs_count)
		print("  Jobs видалення: ", removal_jobs_count)
		print("  Позиція гравця: ", player_pos)
		print("  Чанк гравця: ", player_chunk)
		print("  GridMap валідний: ", is_instance_valid(get_parent().target_gridmap) if get_parent() else false)
		print("================================")

func generate_initial_chunks(gridmap: GridMap):
	"""Генерація початкових чанків навколо гравця з пріоритетом для чанка гравця"""
	if not player:
		# Якщо немає гравця, генеруємо чанки навколо центру
		current_player_chunk = Vector2i.ZERO
	else:
		update_player_chunk_position()

	# КРИТИЧНО: Спочатку генеруємо чанк гравця з найвищим пріоритетом
	# Це запобігає падінню гравця в порожнечу
	if not is_chunk_loaded_or_pending(current_player_chunk):
		_queue_chunk_generation_priority(current_player_chunk, gridmap, true)
		if debug_prints:
			print("[ChunkManager] generate_initial_chunks: Додано чанк гравця ", current_player_chunk, " з найвищим пріоритетом")
		
		# КРИТИЧНО: Блокуємо рух гравця до завершення генерації чанка під ним
		if player and is_instance_valid(player):
			# Встановлюємо гравця на безпечну висоту (вище за можливий терейн)
			var safe_height = _get_max_height() + 10
			if player.global_position.y < safe_height:
				player.global_position.y = safe_height
				if debug_prints:
					print("[ChunkManager] generate_initial_chunks: Встановлено гравця на безпечну висоту ", safe_height, " до завершення генерації чанка")

	# Збираємо всі чанки та сортуємо за відстанню від гравця
	var chunks_to_generate: Array[Dictionary] = []
	for x in range(-chunk_radius, chunk_radius + 1):
		for z in range(-chunk_radius, chunk_radius + 1):
			var chunk_pos = current_player_chunk + Vector2i(x, z)
			# Пропускаємо чанк гравця (вже додано)
			if chunk_pos == current_player_chunk:
				continue
			if not is_chunk_loaded_or_pending(chunk_pos):
				var distance = max(abs(x), abs(z))
				chunks_to_generate.append({"pos": chunk_pos, "distance": distance})
	
	# Сортуємо за відстанню (найближчі першими)
	chunks_to_generate.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Додаємо чанки в чергу з пріоритетом (найближчі - пріоритетні)
	for chunk_data in chunks_to_generate:
		var chunk_pos = chunk_data.pos
		var distance = chunk_data.distance
		# Чанки в радіусі 2 від гравця - високий пріоритет
		if distance <= 2:
			_queue_chunk_generation_priority(chunk_pos, gridmap, true)
		else:
			queue_chunk_generation(chunk_pos)

# Видалено update_chunks() - функція мертва, не викликається ніде

func update_player_chunk_position():
	"""Оновлення позиції чанка гравця"""
	if player:
		var old_chunk = current_player_chunk
		current_player_chunk = get_player_chunk_position()

		# ВИДАЛЕНО: Preload система не використовується

func get_player_chunk_position() -> Vector2i:
	"""Отримати позицію чанка гравця"""
	if not player:
		return Vector2i.ZERO

	# Захист від ділення на 0
	if chunk_size.x <= 0 or chunk_size.y <= 0:
		push_error("[ChunkManager] get_player_chunk_position: chunk_size невалідний: " + str(chunk_size))
		return Vector2i.ZERO

	var player_pos = player.global_position
	# Використовуємо floor для коректного обчислення чанка (включаючи від'ємні координати)
	return Vector2i(
		floori(player_pos.x / float(chunk_size.x)),
		floori(player_pos.z / float(chunk_size.y))
	)

func _queue_chunk_generation_priority(chunk_pos: Vector2i, gridmap: GridMap, is_priority: bool = false):
	"""Внутрішня функція для додавання чанка в чергу генерації з пріоритетом"""
	if not gridmap or not is_instance_valid(gridmap):
		if debug_prints:
			push_error("[ChunkManager] _queue_chunk_generation_priority: GridMap не валідний")
		return
	
	if is_chunk_loaded_or_pending(chunk_pos):
		if debug_prints:
			print("[ChunkManager] _queue_chunk_generation_priority: Чанк ", chunk_pos, " вже завантажений або в процесі")
		return
	
	var job = _create_chunk_generation_job(chunk_pos, gridmap, true)
	if not job:
		if debug_prints:
			push_error("[ChunkManager] _queue_chunk_generation_priority: Не вдалося створити job для чанка " + str(chunk_pos))
		return
	
	# Додаємо на початок черги якщо пріоритетний, інакше в кінець
	if is_priority:
		chunk_generation_jobs.insert(0, job)
		if debug_prints:
			print("[ChunkManager] _queue_chunk_generation_priority: Додано пріоритетний job для чанка ", chunk_pos)
	else:
		chunk_generation_jobs.append(job)

func collect_chunk_data(chunk_pos: Vector2i) -> Dictionary:
	"""Збір даних чанка для збереження (делегує до SaveLoadManager якщо доступний)"""
	# ВИПРАВЛЕНО: Використовуємо SaveLoadManager.collect_chunk_data() якщо доступний
	# щоб уникнути дублювання логіки
	if get_parent().save_load_module and is_instance_valid(get_parent().save_load_module):
		if get_parent().save_load_module.has_method("collect_chunk_data"):
			return get_parent().save_load_module.collect_chunk_data(chunk_pos)
	
	# Fallback якщо SaveLoadManager не доступний
	var chunk_data = {
		"blocks": {},
		"vegetation": {},
		"structures": []
	}
	var chunk_start = chunk_pos * chunk_size

	# Зберігаємо блоки чанка
	if get_parent().target_gridmap:
		for x in range(chunk_start.x, chunk_start.x + chunk_size.x):
			for z in range(chunk_start.y, chunk_start.y + chunk_size.y):
				for y in range(_get_min_height(), _get_max_height()):
					var cell_item = get_parent().target_gridmap.get_cell_item(Vector3i(x, y, z))
					if cell_item >= 0:
						var key = str(x) + "_" + str(y) + "_" + str(z)
						chunk_data["blocks"][key] = cell_item

	return chunk_data

func regenerate_chunks_around_player(gridmap: GridMap):
	"""Регенерація чанків навколо гравця з пріоритетом для чанків перед гравцем"""
	if not gridmap or not is_instance_valid(gridmap):
		push_error("[ChunkManager] regenerate_chunks_around_player: GridMap не валідний")
		return
	
	if not player:
		if debug_prints:
			print("[ChunkManager] regenerate_chunks_around_player: Немає гравця")
		return
	
	# ВИПРАВЛЕНО: Викликаємо cull тільки якщо пройшов мінімальний інтервал
	var current_time = Time.get_ticks_msec() / 1000.0
	if enable_culling and (current_time - last_cull_time >= min_cull_interval):
		if debug_prints:
			print("[ChunkManager] regenerate_chunks_around_player: Викликаємо cull_distant_chunks")
		cull_distant_chunks(gridmap)
		last_cull_time = current_time
	
	# КРИТИЧНО: Перевірка ліміту після додавання нових чанків в чергу
	var current_count = active_chunks.size()
	if current_count >= warning_chunk_count:
		push_warning("[ChunkManager] regenerate_chunks_around_player: Кількість активних чанків наближається до ліміту: " + str(current_count) + " / " + str(max_active_chunks))

	# Збираємо всі чанки та сортуємо за відстанню від гравця
	var chunks_to_generate: Array[Dictionary] = []
	for x in range(-chunk_radius, chunk_radius + 1):
		for z in range(-chunk_radius, chunk_radius + 1):
			var chunk_pos = current_player_chunk + Vector2i(x, z)
			if not is_chunk_loaded_or_pending(chunk_pos):
				var distance = max(abs(x), abs(z))
				chunks_to_generate.append({"pos": chunk_pos, "distance": distance})
	
	# Сортуємо за відстанню (найближчі першими)
	chunks_to_generate.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Додаємо чанки в чергу з пріоритетом (найближчі - пріоритетні)
	var priority_count = 0
	var normal_count = 0
	for chunk_data in chunks_to_generate:
		var chunk_pos = chunk_data.pos
		var distance = chunk_data.distance
		# Чанки в радіусі 2 від гравця - високий пріоритет
		if distance <= 2:
			_queue_chunk_generation_priority(chunk_pos, gridmap, true)
			priority_count += 1
		else:
			queue_chunk_generation(chunk_pos)
			normal_count += 1
	
	if debug_prints and (priority_count > 0 or normal_count > 0):
		print("[ChunkManager] regenerate_chunks_around_player: Додано в чергу - пріоритетних: ", priority_count, ", звичайних: ", normal_count)

func _force_cull_excess_chunks(gridmap: GridMap):
	"""КРИТИЧНО: Примусове видалення найдальших чанків коли досягнуто ліміту"""
	if not gridmap or not is_instance_valid(gridmap):
		return
	
	var current_count = active_chunks.size()
	if current_count < max_active_chunks:
		return  # Ліміт не досягнуто
	
	var target_count = max_active_chunks - 10  # Залишаємо місце для нових чанків
	var chunks_to_remove = current_count - target_count
	
	if chunks_to_remove <= 0:
		return
	
	push_error("[ChunkManager] _force_cull_excess_chunks: Примусове видалення " + str(chunks_to_remove) + " найдальших чанків (поточний ліміт: " + str(current_count) + " >= " + str(max_active_chunks) + ")")
	
	# Створюємо список чанків з відстанню до гравця
	var chunks_with_distance: Array[Dictionary] = []
	var player_chunk = get_player_chunk_position() if player else Vector2i.ZERO
	var safety_radius = 3
	
	for chunk_pos in active_chunks.keys():
		# НЕ видаляємо чанки поблизу гравця
		if player:
			if is_player_in_chunk(chunk_pos):
				continue
			var distance = get_chunk_distance(chunk_pos)
			if distance <= safety_radius:
				continue
		
		var distance = get_chunk_distance(chunk_pos)
		chunks_with_distance.append({"pos": chunk_pos, "distance": distance})
	
	# Сортуємо за відстанню (найдальші перші)
	chunks_with_distance.sort_custom(func(a, b): return a["distance"] > b["distance"])
	
	# Видаляємо найдальші чанки
	var removed_count = 0
	for i in range(min(chunks_to_remove, chunks_with_distance.size())):
		var chunk_data = chunks_with_distance[i]
		var chunk_pos = chunk_data["pos"]
		
		# Додаткова перевірка безпеки
		if player and is_player_in_chunk(chunk_pos):
			continue
		
		if debug_prints:
			print("[ChunkManager] _force_cull_excess_chunks: Примусове видалення чанка ", chunk_pos, " (відстань: ", chunk_data["distance"], ")")
		
		request_chunk_removal(gridmap, chunk_pos)
		removed_count += 1
	
	if removed_count > 0:
		var remaining_count = active_chunks.size()  # Поточна кількість (чанки видаляються асинхронно)
		push_warning("[ChunkManager] _force_cull_excess_chunks: Запитуємо видалення " + str(removed_count) + " чанків, поточний розмір: " + str(remaining_count))

func cull_distant_chunks(gridmap: GridMap):
	"""Видалення далеких чанків з урахуванням frustum та occlusion culling"""
	var chunks_to_remove: Array[Vector2i] = []

	# Отримуємо камеру для frustum culling
	var camera = get_viewport().get_camera_3d() if get_viewport() else null
	
	# Отримуємо позицію гравця для перевірки безпеки
	var player_chunk = get_player_chunk_position() if player else Vector2i.ZERO
	var safety_radius = 3  # ВИПРАВЛЕНО: Збільшено буфер безпеки навколо гравця (чанки)

	for chunk_pos in active_chunks.keys():
		var should_remove = false

		# КРИТИЧНО: Ніколи не видаляємо чанк, якщо гравець знаходиться в ньому або поблизу
		if player:
			var distance_to_player = get_chunk_distance(chunk_pos)
			
			# КРИТИЧНА ПЕРЕВІРКА: Буфер безпеки
			if distance_to_player <= safety_radius:
				if debug_prints:
					print("[ChunkManager] cull_distant_chunks: ПРОПУСКАЄМО чанк ", chunk_pos, " (відстань ", distance_to_player, " <= safety_radius ", safety_radius, ")")
				continue
			
			# КРИТИЧНА ПЕРЕВІРКА: Чи гравець фізично знаходиться в чанку
			if is_player_in_chunk(chunk_pos):
				push_error("[ChunkManager] cull_distant_chunks: КРИТИЧНО! Гравець в чанку " + str(chunk_pos) + " - НЕ ВИДАЛЯЄМО!")
				continue

		# Перевірка відстані (з додатковим буфером, щоб уникнути занадто частого видалення)
		var distance = get_chunk_distance(chunk_pos)
		var cull_threshold = chunk_radius + 3  # ВИПРАВЛЕНО: Збільшено буфер перед видаленням
		if distance > cull_threshold:
			should_remove = true
			if debug_prints:
				print("[ChunkManager] cull_distant_chunks: Чанк ", chunk_pos, " занадто далеко (відстань ", distance, " > threshold ", cull_threshold, ")")

		# Frustum culling (якщо відстань в межах)
		if not should_remove and enable_frustum_culling and camera:
			should_remove = not is_chunk_visible(camera, chunk_pos)

		# Occlusion culling (якщо відстань в межах і не frustum culled)
		if not should_remove and get_parent() and get_parent().optimization_module:
			var should_render = get_parent().optimization_module.optimize_rendering_for_chunk(chunk_pos, active_chunks, Vector2i(chunk_size.x, chunk_size.y))
			if not should_render:
				should_remove = true

		if should_remove:
			chunks_to_remove.append(chunk_pos)
			if debug_prints:
				# distance вже оголошена вище в рядку 273
				print("[ChunkManager] cull_distant_chunks: Позначено для видалення чанк ", chunk_pos, " (відстань: ", distance, ")")

	if chunks_to_remove.size() > 0 and debug_prints:
		print("[ChunkManager] cull_distant_chunks: Знайдено ", chunks_to_remove.size(), " чанків для видалення")

	# Обмежуємо кількість чанків для видалення за кадр
	var chunks_removed_this_frame = 0
	for chunk_pos in chunks_to_remove:
		if chunks_removed_this_frame >= max_chunks_to_remove_per_frame:
			if debug_prints:
				print("[ChunkManager] cull_distant_chunks: Досягнуто ліміт видалень за кадр (", max_chunks_to_remove_per_frame, ")")
			break
		
		# КРИТИЧНА ПЕРЕВІРКА: Додаткова перевірка безпеки перед видаленням
		if player:
			if is_player_in_chunk(chunk_pos):
				push_error("[ChunkManager] cull_distant_chunks: КРИТИЧНО! Спроба видалити чанк з гравцем всередині! " + str(chunk_pos))
				continue
			
			# Додаткова перевірка відстані перед видаленням
			var final_distance = get_chunk_distance(chunk_pos)
			if final_distance <= safety_radius:
				push_error("[ChunkManager] cull_distant_chunks: КРИТИЧНО! Чанк ", chunk_pos, " занадто близько до гравця (", final_distance, " <= ", safety_radius, ")")
				continue
		
		if debug_prints:
			print("[ChunkManager] cull_distant_chunks: Запитуємо видалення чанка ", chunk_pos)
		request_chunk_removal(gridmap, chunk_pos)
		chunks_removed_this_frame += 1

		# Видаляємо рослинність для чанка
		if get_parent().vegetation_module and get_parent().use_vegetation:
			if is_instance_valid(get_parent().vegetation_module):
				get_parent().vegetation_module.remove_multimesh_for_chunk(chunk_pos)
			else:
				push_warning("[ChunkManager] cull_distant_chunks: vegetation_module не валідний")

func _rebuild_chunk_with_optimized_mesh(gridmap: GridMap, chunk_pos: Vector2i, optimized_data: Dictionary):
	"""Перебудова чанка з оптимізованими даними mesh"""
	# Спрощена версія: поки що просто перестворюємо блоки з видимими гранями
	# В повній реалізації треба створювати MeshInstance3D замість GridMap

	# Спочатку очищаємо чанк
	var chunk_start = chunk_pos * chunk_size
	var chunk_end = chunk_start + chunk_size

	for x in range(chunk_start.x, chunk_end.x):
		for z in range(chunk_start.y, chunk_end.y):
			for y in range(_get_min_height(), _get_max_height()):
				gridmap.set_cell_item(Vector3i(x, y, z), -1)

	# Потім додаємо тільки оптимізовані блоки
	for block_key in optimized_data.keys():
		var coords = block_key.split("_")
		if coords.size() >= 3:
			var x = int(coords[0])
			var y = int(coords[1])
			var z = int(coords[2])

			var block_data = optimized_data[block_key]
			if block_data.has("mesh_index"):
				gridmap.set_cell_item(Vector3i(x, y, z), block_data["mesh_index"])

	if debug_prints:
		print("[ChunkManager] Перебудовано чанк ", chunk_pos, " з ", optimized_data.size(), " оптимізованими блоками")

func remove_chunk(gridmap: GridMap, chunk_pos: Vector2i):
	"""Видалення чанка"""
	# КРИТИЧНА ПЕРЕВІРКА: Не видаляємо чанк якщо гравець всередині
	if player and is_player_in_chunk(chunk_pos):
		push_error("[ChunkManager] remove_chunk: КРИТИЧНО! Спроба видалити чанк з гравцем всередині! " + str(chunk_pos))
		return
	
	if not active_chunks.has(chunk_pos):
		if debug_prints:
			print("[ChunkManager] remove_chunk: Чанк ", chunk_pos, " не існує в active_chunks")
		return

	if not gridmap or not is_instance_valid(gridmap):
		push_error("[ChunkManager] remove_chunk: GridMap не валідний для чанка " + str(chunk_pos))
		return

	var metadata = active_chunks.get(chunk_pos)

	# Видаляємо всі блоки в чанку
	var chunk_start = chunk_pos * chunk_size
	var chunk_end = chunk_start + chunk_size

	if debug_prints:
		print("[ChunkManager] remove_chunk: Початок видалення чанка ", chunk_pos, " (", chunk_start, " - ", chunk_end, ")")

	for x in range(chunk_start.x, chunk_end.x):
		for z in range(chunk_start.y, chunk_end.y):
			# Перевірка чи гравець не перемістився в чанк під час видалення
			if player and is_player_in_chunk(chunk_pos):
				push_error("[ChunkManager] remove_chunk: КРИТИЧНО! Гравець перемістився в чанк під час видалення! " + str(chunk_pos))
				return
			
			for y in range(_get_min_height(), _get_max_height()):
				if not is_instance_valid(gridmap):
					push_error("[ChunkManager] remove_chunk: GridMap став невалідним під час видалення")
					return
				gridmap.set_cell_item(Vector3i(x, y, z), -1)

	# ВИПРАВЛЕНО: Видаляємо detail layer (траву) для чанка
	if get_parent() and get_parent().detail_module and get_parent().use_detail_layers:
		if is_instance_valid(get_parent().detail_module):
			get_parent().detail_module.remove_detail_for_chunk(chunk_pos)
		else:
			push_warning("[ChunkManager] remove_chunk: detail_module не валідний для чанка " + str(chunk_pos))
	
	# ВИПРАВЛЕНО: Видаляємо POI для чанка (запобігає витокам пам'яті)
	if get_parent() and get_parent().has("poi_module") and get_parent().has("use_poi_generation"):
		if get_parent().poi_module and get_parent().use_poi_generation:
			if is_instance_valid(get_parent().poi_module):
				if get_parent().poi_module.has_method("remove_poi_for_chunk"):
					get_parent().poi_module.remove_poi_for_chunk(chunk_pos)
				else:
					push_warning("[ChunkManager] remove_chunk: poi_module не має методу remove_poi_for_chunk")
			else:
				push_warning("[ChunkManager] remove_chunk: poi_module не валідний для чанка " + str(chunk_pos))
	
	# ВИПРАВЛЕНО: Видаляємо multimesh для чанка при unload для запобігання витоку пам'яті
	if get_parent() and get_parent().vegetation_module and get_parent().use_vegetation:
		if is_instance_valid(get_parent().vegetation_module):
			get_parent().vegetation_module.remove_multimesh_for_chunk(chunk_pos)
		else:
			push_warning("[ChunkManager] remove_chunk: vegetation_module не валідний для чанка " + str(chunk_pos))

	_remove_chunk_from_spatial_index(chunk_pos, metadata)
	active_chunks.erase(chunk_pos)
	if debug_prints:
		print("[ChunkManager] remove_chunk: Успішно видалено чанк ", chunk_pos)

func clear_all_chunks(gridmap: GridMap):
	"""Повне очищення всіх чанків (використовувати перед перегенерацією світу)"""
	if not gridmap or not is_instance_valid(gridmap):
		push_error("[ChunkManager] clear_all_chunks: GridMap невалідний")
		return
	
	var chunk_positions := active_chunks.keys()
	for chunk_pos in chunk_positions:
		remove_chunk(gridmap, chunk_pos)
	
	active_chunks.clear()
	# pending_chunk_generations.clear() # ВИДАЛЕНО: змінна не використовується
	chunk_generation_jobs.clear()
	chunk_generation_job_lookup.clear()
	chunk_removal_jobs.clear()
	# ВИДАЛЕНО: preload система повністю видалена

func request_chunk_removal(gridmap: GridMap, chunk_pos: Vector2i):
	"""Заплановане (ліниве) видалення чанка з поетапним очищенням"""
	if not gridmap or not active_chunks.has(chunk_pos):
		return

	# КРИТИЧНО: Перевірка безпеки перед видаленням
	if player:
		# Не видаляємо чанк, якщо гравець знаходиться в ньому
		if is_player_in_chunk(chunk_pos):
			push_warning("[ChunkManager] request_chunk_removal: Спроба видалити чанк з гравцем всередині! Пропускаємо: " + str(chunk_pos))
			return
		
		# Не видаляємо чанки в буфері безпеки
		var distance = get_chunk_distance(chunk_pos)
		if distance <= 2:  # Буфер безпеки
			return

	# ВИПРАВЛЕНО: Не видаляємо з active_chunks до завершення job!
	# Тільки позначаємо як UNLOADING і додаємо в чергу видалення
	var metadata = active_chunks.get(chunk_pos)
	if metadata:
		metadata["state"] = ChunkState.UNLOADING  # Позначаємо як видаляється
		metadata["is_active"] = false
	
	_cancel_chunk_job(chunk_pos)
	_remove_chunk_from_spatial_index(chunk_pos, metadata)
	_enqueue_chunk_removal_job(chunk_pos)

func _enqueue_chunk_removal_job(chunk_pos: Vector2i):
	for job in chunk_removal_jobs:
		if job.get("chunk_pos") == chunk_pos:
			return
	var chunk_start = chunk_pos * chunk_size
	var job = {
		"chunk_pos": chunk_pos,
		"start_x": chunk_start.x,
		"end_x": chunk_start.x + chunk_size.x,
		"start_z": chunk_start.y,
		"end_z": chunk_start.y + chunk_size.y,
		"x": chunk_start.x,
		"y": _get_min_height(),
		"z": chunk_start.y,
		"y_min": _get_min_height(),
		"y_max": _get_max_height(),
		"done": false
	}
	chunk_removal_jobs.append(job)

func is_chunk_visible(camera: Camera3D, chunk_pos: Vector2i) -> bool:
	"""Перевірка чи видимий чанк у frustum камери"""
	if not camera:
		return true  # Якщо немає камери, вважаємо видимим

	# Захист від ділення на 0
	if chunk_size.x <= 0 or chunk_size.y <= 0:
		return false

	# Розраховуємо bounding box чанка
	var chunk_world_pos = chunk_pos * chunk_size
	var vertical_span = float(_get_max_height() - _get_min_height())
	var chunk_center = Vector3(chunk_world_pos.x + float(chunk_size.x) / 2.0, _get_min_height() + vertical_span / 2.0, chunk_world_pos.y + float(chunk_size.y) / 2.0)
	var chunk_size_3d = Vector3(chunk_size.x, max(vertical_span, 1.0), chunk_size.y)

	# Створюємо AABB для чанка
	var aabb = AABB(chunk_center - chunk_size_3d/2.0, chunk_size_3d)

	# Перевіряємо чи перетинається з frustum (спрощена версія)
	return camera.is_position_in_frustum(chunk_center)

func get_chunk_distance(chunk_pos: Vector2i) -> int:
	"""Отримати відстань чанка від гравця"""
	if not player:
		return 0

	var player_chunk = get_player_chunk_position()
	return max(abs(chunk_pos.x - player_chunk.x), abs(chunk_pos.y - player_chunk.y))

func is_player_in_chunk(chunk_pos: Vector2i) -> bool:
	"""Перевірка, чи гравець фізично знаходиться в чанку"""
	if not player:
		return false
	
	# Захист від ділення на 0
	if chunk_size.x <= 0 or chunk_size.y <= 0:
		return false
	
	var player_world_pos = player.global_position
	var chunk_world_start = chunk_pos * chunk_size
	var chunk_world_end = chunk_world_start + chunk_size
	
	# Використовуємо float для точного порівняння (не int())
	# Гравець на межі чанка (наприклад, x = 50.0) має потрапляти в чанк
	return (player_world_pos.x >= float(chunk_world_start.x) and player_world_pos.x < float(chunk_world_end.x) and
			player_world_pos.z >= float(chunk_world_start.y) and player_world_pos.z < float(chunk_world_end.y))

# Видалено update_chunk_culling() - логіка перенесена в regenerate_chunks_around_player() з таймером

func get_active_chunk_count() -> int:
	"""Отримати кількість активних чанків"""
	var count := 0
	for metadata in active_chunks.values():
		if metadata.get("is_active", false):
			count += 1
	return count

# Partial Mesh Updates - методи для інкрементальних оновлень

func register_block_change(world_pos: Vector3i, old_mesh_index: int, new_mesh_index: int):
	"""Реєструє зміну блоку для partial update"""
	var change_data = {
		"old_mesh": old_mesh_index,
		"new_mesh": new_mesh_index,
		"timestamp": Time.get_ticks_msec() / 1000.0  # ВИПРАВЛЕНО: Монотонний час замість системного
	}
	modified_blocks[world_pos] = change_data

func process_partial_updates(_delta: float):
	"""Обробляє partial mesh updates"""
	if modified_blocks.size() == 0:
		return

	# Очищаємо застарілі зміни
	cleanup_expired_changes()

	# Обробляємо обмежену кількість змін за кадр
	var processed_count = 0
	var changes_to_process = modified_blocks.keys().slice(0, max_modified_blocks_per_frame)

	for world_pos in changes_to_process:
		if processed_count >= max_modified_blocks_per_frame:
			break

		var change_data = modified_blocks[world_pos]
		update_single_block_mesh(world_pos, change_data["new_mesh"])
		modified_blocks.erase(world_pos)
		processed_count += 1

func cleanup_expired_changes():
	"""Видаляє застарілі зміни блоків"""
	# ВИПРАВЛЕНО: Використовуємо монотонний час (як в register_block_change)
	# для коректного порівняння з timestamp
	var current_time = Time.get_ticks_msec() / 1000.0
	var expired_keys = []

	for world_pos in modified_blocks.keys():
		var change_data = modified_blocks[world_pos]
		var timestamp = change_data.get("timestamp", 0.0)
		if current_time - timestamp > block_modification_timeout:
			expired_keys.append(world_pos)

	for key in expired_keys:
		modified_blocks.erase(key)

func update_single_block_mesh(world_pos: Vector3i, new_mesh_index: int):
	"""Оновлює mesh одного блоку"""
	if not get_parent() or not get_parent().target_gridmap:
		return

	var gridmap = get_parent().target_gridmap

	# Перевіряємо чи блок дійсно змінився
	var current_mesh = gridmap.get_cell_item(world_pos)
	if current_mesh == new_mesh_index:
		return  # Немає потреби оновлювати

	# Оновлюємо блок
	gridmap.set_cell_item(world_pos, new_mesh_index)

	# Якщо використовується mesh optimization, оновлюємо видимість граней
	if get_parent().optimization_module and get_parent().optimization_module.enable_cull_hidden_faces:
		# Позначаємо чанк для переоптимізації при наступній генерації
		var chunk_pos = _get_chunk_pos_for_world_pos(world_pos)
		var metadata = _ensure_chunk_metadata(chunk_pos, false)
		if metadata:
			metadata["needs_reoptimization"] = true
			active_chunks[chunk_pos] = metadata

func update_chunk_partial(chunk_pos: Vector2i):
	"""Повністю перебудовує чанк з урахуванням всіх змін"""
	if not active_chunks.has(chunk_pos):
		return

	# Очищаємо чанк
	remove_chunk(get_parent().target_gridmap, chunk_pos)

	# Перегенеровуємо чанк (через чергу з пріоритетом)
	_queue_chunk_generation_priority(chunk_pos, get_parent().target_gridmap, true)

	# Позначаємо як оновлений
	var metadata = _ensure_chunk_metadata(chunk_pos, false)
	if metadata:
		metadata["last_partial_update"] = _get_timestamp()
		active_chunks[chunk_pos] = metadata

func _get_chunk_pos_for_world_pos(world_pos: Vector3i) -> Vector2i:
	"""Отримати позицію чанка для світової позиції блоку"""
	# Захист від ділення на 0
	if chunk_size.x <= 0 or chunk_size.y <= 0:
		push_error("[ChunkManager] _get_chunk_pos_for_world_pos: chunk_size невалідний")
		return Vector2i.ZERO
	return Vector2i(
		floori(float(world_pos.x) / float(chunk_size.x)),
		floori(float(world_pos.z) / float(chunk_size.y))
	)

func get_modified_blocks_count() -> int:
	"""Отримати кількість змінених блоків в черзі"""
	return modified_blocks.size()

func get_modified_blocks_for_chunk(chunk_pos: Vector2i) -> Dictionary:
	"""Отримати модифіковані блоки для конкретного чанка
	
	ВИПРАВЛЕНО: Додано метод для отримання тільки модифікованих блоків чанка.
	Використовується SaveLoadManager для збереження тільки змінених блоків.
	"""
	var chunk_start = chunk_pos * chunk_size
	var chunk_end = chunk_start + chunk_size
	var modified_blocks_dict = {}
	
	for world_pos in modified_blocks.keys():
		# Перевіряємо чи блок належить до цього чанка
		if world_pos.x >= chunk_start.x and world_pos.x < chunk_end.x:
			if world_pos.z >= chunk_start.y and world_pos.z < chunk_end.y:
				var key = str(world_pos.x) + "_" + str(world_pos.y) + "_" + str(world_pos.z)
				var change_data = modified_blocks[world_pos]
				# Зберігаємо новий mesh_index (поточний стан блоку)
				modified_blocks_dict[key] = change_data.get("new_mesh", -1)
	
	return modified_blocks_dict

func _get_max_height() -> int:
	var height = 64
	if get_parent() and get_parent().has_method("get_max_height"):
		height = get_parent().get_max_height()
	return max(height, _get_min_height() + 1)

func _get_min_height() -> int:
	var height = -64  # Дефолтна мінімальна висота (оптимізовано)
	if get_parent() and get_parent().has_method("get_min_height"):
		height = get_parent().get_min_height()
	return min(height, -1)  # Завжди від'ємна або -1 мінімум

func _get_surface_height_at(gridmap: GridMap, world_x: int, world_z: int, chunk_start: Vector2i) -> int:
	"""Отримати висоту поверхні на позиції (world_x, world_z)"""
	if not gridmap or not is_instance_valid(gridmap):
		return 0
	
	# Шукаємо найвищий блок на позиції (x, z)
	var max_height = _get_max_height()
	var min_height = _get_min_height()
	
	# Шукаємо зверху вниз
	for y in range(max_height, min_height - 1, -1):
		var cell_item = gridmap.get_cell_item(Vector3i(world_x, y, world_z))
		if cell_item >= 0:  # Якщо є блок
			return y + 1  # Поверхня на один блок вище
	
	# Якщо не знайдено - повертаємо базову висоту
	return _get_base_height()

func _get_base_height() -> int:
	"""Отримати базову висоту"""
	if get_parent() and get_parent().has_method("get_base_height"):
		return get_parent().get_base_height()
	return 16  # Дефолт

# ВИДАЛЕНО: Preloading Buffer - вся система видалена, оскільки не використовується ефективно
# Чанки генеруються через основну чергу генерації (chunk_generation_jobs)

func queue_chunk_generation(chunk_pos: Vector2i) -> bool:
	"""Додати чанк в чергу генерації. Повертає true якщо успішно додано, false якщо не вдалося."""
	if is_chunk_loaded_or_pending(chunk_pos):
		return false

	# КРИТИЧНО: Перевірка ліміту перед додаванням в чергу
	var current_count = active_chunks.size()
	if current_count >= max_active_chunks:
		if debug_prints:
			print("[ChunkManager] queue_chunk_generation: ПРОПУСКАЄМО чанк ", chunk_pos, " - досягнуто ліміт активних чанків (", current_count, " >= ", max_active_chunks, ")")
		return false

	# Створюємо job безпосередньо замість додавання в pending
	var gridmap = get_parent().target_gridmap if get_parent() else null
	if not gridmap or not is_instance_valid(gridmap):
		push_error("[ChunkManager] queue_chunk_generation: GridMap не валідний або ChunkManager не прикріплено до TerrainGenerator")
		return false
	
	var job = _create_chunk_generation_job(chunk_pos, gridmap, true)
	if job:
		chunk_generation_jobs.append(job)
		if debug_prints:
			print("[ChunkManager] queue_chunk_generation: Створено job для чанка ", chunk_pos)
		return true
	
	push_error("[ChunkManager] queue_chunk_generation: Не вдалося створити job для чанка " + str(chunk_pos))
	return false

# ВИДАЛЕНО: process_generation_queue() - функція не використовується
# Jobs обробляються безпосередньо в _process_generation_jobs()

func process_chunk_removals(gridmap: GridMap):
	if not gridmap:
		return
	if chunk_removal_jobs.is_empty():
		return
	if max_chunk_clear_ops_per_frame <= 0:
		return

	if not is_instance_valid(gridmap):
		push_error("[ChunkManager] process_chunk_removals: GridMap не валідний")
		chunk_removal_jobs.clear()
		return

	var ops_left := max_chunk_clear_ops_per_frame
	var index := 0
	var processed_count = 0
	
	while index < chunk_removal_jobs.size() and ops_left > 0:
		var job = chunk_removal_jobs[index]
		if not job.has("chunk_pos"):
			push_error("[ChunkManager] process_chunk_removals: Job без chunk_pos, видаляємо")
			chunk_removal_jobs.remove_at(index)
			continue
		
		var chunk_pos = job.get("chunk_pos")
		
		# Перевірка безпеки перед видаленням
		if player and is_player_in_chunk(chunk_pos):
			push_warning("[ChunkManager] process_chunk_removals: Спроба видалити чанк з гравцем! Пропускаємо: " + str(chunk_pos))
			chunk_removal_jobs.remove_at(index)
			continue
		
		var consumed = _process_chunk_removal_job(job, gridmap, ops_left)
		ops_left -= consumed
		processed_count += consumed
		
		if job.get("done", false):
			if debug_prints:
				print("[ChunkManager] process_chunk_removals: Завершено видалення чанка ", chunk_pos)
			# ВИПРАВЛЕНО: Видаляємо з active_chunks тільки після завершення job
			if active_chunks.has(chunk_pos):
				active_chunks.erase(chunk_pos)
			chunk_removal_jobs.remove_at(index)
		else:
			index += 1
	
	if processed_count > 0 and debug_prints:
		print("[ChunkManager] process_chunk_removals: Оброблено ", processed_count, " операцій видалення")

func _process_chunk_removal_job(job: Dictionary, gridmap: GridMap, budget: int) -> int:
	if not is_instance_valid(gridmap):
		push_error("[ChunkManager] _process_chunk_removal_job: GridMap не валідний")
		job["done"] = true
		return 0
	
	# ВИПРАВЛЕНО: Захист від невалідних координат на початку
	if not job.has("x") or not job.has("y") or not job.has("z"):
		push_error("[ChunkManager] _process_chunk_removal_job: Job без координат")
		job["done"] = true
		return 0
	
	if chunk_size.x <= 0 or chunk_size.y <= 0:
		push_error("[ChunkManager] _process_chunk_removal_job: chunk_size невалідний")
		job["done"] = true
		return 0
	
	var consumed := 0
	var max_iterations = budget * 2  # Захист від зациклення
	var iterations = 0
	
	while consumed < budget and iterations < max_iterations:
		if job["x"] >= job["end_x"]:
			job["done"] = true
			break

		var cell = Vector3i(job["x"], job["y"], job["z"])
		
		# Перевірка валідності координат
		if job["y"] < job["y_min"] or job["y"] >= job["y_max"]:
			if debug_prints:
				push_error("[ChunkManager] _process_chunk_removal_job: Невалідна координата Y: " + str(job["y"]) + " для чанка " + str(job.get("chunk_pos", "unknown")))
			job["done"] = true
			break
		
		if not is_instance_valid(gridmap):
			push_error("[ChunkManager] _process_chunk_removal_job: GridMap став невалідним під час видалення")
			job["done"] = true
			break
		
		gridmap.set_cell_item(cell, -1)
		consumed += 1
		iterations += 1

		job["z"] += 1
		if job["z"] >= job["end_z"]:
			job["z"] = job["start_z"]
			job["y"] += 1
			if job["y"] >= job["y_max"]:
				job["y"] = job["y_min"]
				job["x"] += 1
	
	if iterations >= max_iterations:
		push_error("[ChunkManager] _process_chunk_removal_job: Досягнуто максимум ітерацій для чанка " + str(job.get("chunk_pos", "unknown")))

	return consumed

# --- Допоміжні методи ---

func _create_chunk_metadata(_chunk_pos: Vector2i) -> Dictionary:
	return {
		"state": ChunkState.PRELOADED,
		"preloaded": true,
		"is_active": false,
		"data_ready": false,
		"in_spatial_index": false,
		"needs_reoptimization": false,
		"last_partial_update": 0.0,
		"last_accessed": _get_timestamp()
	}

func _mark_chunk_preloaded(chunk_pos: Vector2i):
	var metadata = _create_chunk_metadata(chunk_pos)
	if enable_spatial_partitioning:
		_insert_chunk_into_spatial_index(chunk_pos)
		metadata["in_spatial_index"] = true
	active_chunks[chunk_pos] = metadata

func _mark_chunk_active(chunk_pos: Vector2i):
	var metadata = active_chunks.get(chunk_pos, _create_chunk_metadata(chunk_pos))
	metadata["state"] = ChunkState.ACTIVE
	metadata["preloaded"] = false
	metadata["is_active"] = true
	metadata["data_ready"] = true
	metadata["last_accessed"] = _get_timestamp()

	if enable_spatial_partitioning and not metadata.get("in_spatial_index", false):
		_insert_chunk_into_spatial_index(chunk_pos)
		metadata["in_spatial_index"] = true

	active_chunks[chunk_pos] = metadata

func _ensure_chunk_metadata(chunk_pos: Vector2i, create_if_missing: bool = true):
	if active_chunks.has(chunk_pos):
		return active_chunks[chunk_pos]
	if create_if_missing:
		var metadata = _create_chunk_metadata(chunk_pos)
		active_chunks[chunk_pos] = metadata
		return metadata
	return null

func _get_timestamp() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _initialize_spatial_index():
	if not enable_spatial_partitioning:
		return

	var bounds = _calculate_world_bounds()

	if not spatial_index:
		spatial_index = Quadtree.new()
		add_child(spatial_index)

	spatial_index.configure(bounds, spatial_index.node_capacity)

	# Повторно додати існуючі чанки в оновлене дерево
	for chunk_pos in active_chunks.keys():
		spatial_index.insert_chunk(chunk_pos)
		var metadata = active_chunks[chunk_pos]
		metadata["in_spatial_index"] = true
		active_chunks[chunk_pos] = metadata

func _calculate_world_bounds() -> Rect2i:
	# ВИПРАВЛЕНО: Видалено посилання на preload_radius та enable_preloading
	var effective_radius = max(chunk_radius + spatial_margin_chunks, 1)
	var width = effective_radius * chunk_size.x * 2
	var height = effective_radius * chunk_size.y * 2
	return Rect2i(-width / 2, -height / 2, width, height)

func _insert_chunk_into_spatial_index(chunk_pos: Vector2i):
	if not enable_spatial_partitioning:
		return

	if not spatial_index:
		_initialize_spatial_index()

	if spatial_index:
		spatial_index.insert_chunk(chunk_pos)

func _remove_chunk_from_spatial_index(chunk_pos: Vector2i, metadata = null):
	if not enable_spatial_partitioning or not spatial_index:
		return

	if metadata == null:
		metadata = active_chunks.get(chunk_pos, null)

	if metadata and not metadata.get("in_spatial_index", false):
		return

	spatial_index.remove_chunk(chunk_pos)
	if metadata:
		metadata["in_spatial_index"] = false

func _create_chunk_generation_job(chunk_pos: Vector2i, gridmap: GridMap, track_job := true):
	if not get_parent() or not get_parent().procedural_module:
		return null

	# КРИТИЧНО: Як в Minecraft - спочатку перевіряємо чи є збережений чанк
	# Якщо є - завантажуємо його замість процедурної генерації
	if get_parent().save_load_module and get_parent().use_save_load:
		if is_instance_valid(get_parent().save_load_module):
			var saved_data = get_parent().save_load_module.load_chunk_data(chunk_pos)
			if saved_data.size() > 0 and saved_data.has("blocks") and saved_data["blocks"].size() > 0:
				# Збережений чанк існує - завантажуємо його
				if debug_prints:
					print("[ChunkManager] _create_chunk_generation_job: Знайдено збережений чанк ", chunk_pos, ", завантажуємо замість генерації")
				
				# Створюємо job для завантаження (не генерації)
				var base_chunk_size: Vector2i = chunk_size
				if not active_chunks.has(chunk_pos):
					_mark_chunk_preloaded(chunk_pos)
				
				var job := {
					"chunk_pos": chunk_pos,
					"chunk_size": base_chunk_size,
					"chunk_start": chunk_pos * base_chunk_size,
					"phase": "load",  # Спеціальна фаза для завантаження
					"saved_data": saved_data,
					"done": false
				}
				
				if track_job:
					chunk_generation_job_lookup[chunk_pos] = job
				
				return job
			else:
				if debug_prints:
					print("[ChunkManager] _create_chunk_generation_job: Збереженого чанка немає, генеруємо процедурно для ", chunk_pos)

	var distance_to_player = get_chunk_distance(chunk_pos)
	var optimization := {}
	var use_optimization: bool = get_parent().optimization_module != null and get_parent().use_optimization
	if use_optimization:
		optimization = get_parent().optimization_module.optimize_chunk_generation(chunk_pos, distance_to_player)
	
	# ВИПРАВЛЕНО: Простий LOD якщо use_lod ввімкнено (замість нереалізованого LODManager)
	# Додаємо resolution в optimization для далеких чанків
	if get_parent() and get_parent().use_lod:
		var player_chunk = get_player_chunk_position()
		var dist = chunk_pos.distance_to(player_chunk)
		# Простий LOD: близькі чанки = повна резолюція, далекі = знижена
		var resolution = 1.0 if dist < 3 else 0.5 if dist < 6 else 0.25
		if not optimization.has("resolution"):
			optimization["resolution"] = resolution
		else:
			# Якщо optimization_module вже встановив resolution, використовуємо мінімальне значення
			optimization["resolution"] = min(optimization.get("resolution", 1.0), resolution)

	var base_chunk_size: Vector2i = chunk_size
	if not active_chunks.has(chunk_pos):
		_mark_chunk_preloaded(chunk_pos)

	var context = get_parent().procedural_module.prepare_chunk_context(gridmap, chunk_pos, base_chunk_size)

	var job := {
		"chunk_pos": chunk_pos,
		"chunk_size": base_chunk_size,
		"chunk_start": chunk_pos * base_chunk_size,
		"context": context,
		"phase": "surface",
		"current_x": 0,
		"current_z": 0,
		"caves_enabled": context.get("caves_enabled", false),
		"optimization": optimization,
		"done": false
	}

	if track_job:
		chunk_generation_job_lookup[chunk_pos] = job

	return job

func _process_generation_jobs(gridmap: GridMap):
	if not gridmap:
		return
	if chunk_generation_jobs.is_empty():
		return
	if chunk_generation_budget_per_frame <= 0:
		return

	if not is_instance_valid(gridmap):
		push_error("[ChunkManager] _process_generation_jobs: GridMap не валідний, очищаємо jobs")
		chunk_generation_jobs.clear()
		chunk_generation_job_lookup.clear()
		return

	var budget := chunk_generation_budget_per_frame
	var index := 0
	var processed_count = 0
	var max_iterations = chunk_generation_jobs.size() * 2  # Захист від зациклення
	var iterations = 0
	
	while index < chunk_generation_jobs.size() and budget > 0 and iterations < max_iterations:
		if not is_instance_valid(gridmap):
			push_error("[ChunkManager] _process_generation_jobs: GridMap став невалідним під час обробки")
			break
		
		var job = chunk_generation_jobs[index]
		if not job.has("chunk_pos"):
			push_error("[ChunkManager] _process_generation_jobs: Job без chunk_pos, видаляємо")
			chunk_generation_jobs.remove_at(index)
			continue
		
		var chunk_pos: Vector2i = job["chunk_pos"]
		
		# Перевірка безпеки перед генерацією (інформаційна, не критична)
		if player and is_player_in_chunk(chunk_pos):
			if debug_prints:
				print("[ChunkManager] _process_generation_jobs: Гравець в чанку під час генерації (нормально для стартового чанка): " + str(chunk_pos))
		
		var consumed = _process_chunk_job(job, gridmap, budget)
		budget -= consumed
		processed_count += consumed

		if job.get("done", false):
			if debug_prints:
				print("[ChunkManager] _process_generation_jobs: Завершено генерацію чанка ", chunk_pos)
			_finalize_chunk_job(job, gridmap)
			if chunk_generation_job_lookup.has(chunk_pos):
				chunk_generation_job_lookup.erase(chunk_pos)
			chunk_generation_jobs.remove_at(index)
		else:
			index += 1
		
		iterations += 1
	
	if processed_count > 0 and debug_prints:
		print("[ChunkManager] _process_generation_jobs: Оброблено ", processed_count, " операцій генерації, залишилось ", chunk_generation_jobs.size(), " jobs")

func _process_chunk_job(job: Dictionary, gridmap: GridMap, budget: int) -> int:
	if budget <= 0 or job.get("done", false):
		return 0

	if not is_instance_valid(gridmap):
		push_error("[ChunkManager] _process_chunk_job: GridMap не валідний")
		job["done"] = true
		return 0
	
	if not job.has("chunk_pos"):
		push_error("[ChunkManager] _process_chunk_job: Job без chunk_pos")
		job["done"] = true
		return 0
	
	if not get_parent() or not get_parent().procedural_module:
		push_error("[ChunkManager] _process_chunk_job: Немає procedural_module")
		job["done"] = true
		return 0

	var consumed := 0
	var max_iterations = budget * 2  # Захист від зациклення
	var iterations = 0
	
	while consumed < budget and not job.get("done", false) and iterations < max_iterations:
		if not is_instance_valid(gridmap):
			push_error("[ChunkManager] _process_chunk_job: GridMap став невалідним під час обробки")
			job["done"] = true
			break
		
		var chunk_pos: Vector2i = job["chunk_pos"]
		var phase = job.get("phase", "surface")
		
		# КРИТИЧНО: Обробка фази "load" - завантаження збереженого чанка (як в Minecraft)
		if phase == "load":
			if job.has("saved_data"):
				var saved_data = job["saved_data"]
				if get_parent().save_load_module and is_instance_valid(get_parent().save_load_module):
					if debug_prints:
						print("[ChunkManager] _process_chunk_job: Завантажуємо збережений чанк ", chunk_pos)
					get_parent().save_load_module.restore_chunk_data(chunk_pos, saved_data)
					job["done"] = true
					consumed += budget  # Використали весь бюджет на завантаження
					break
				else:
					push_error("[ChunkManager] _process_chunk_job: save_load_module не доступний для завантаження")
					job["done"] = true
					break
			else:
				push_error("[ChunkManager] _process_chunk_job: Job з фазою 'load' не має saved_data")
				job["done"] = true
				break
		
		# Обробка з обробкою помилок
		var error_occurred = false
		if phase == "surface":
			_process_surface_step(job, gridmap)
		elif phase == "caves":
			_process_cave_step(job, gridmap)
		else:
			push_error("[ChunkManager] _process_chunk_job: Невідома фаза: " + str(phase))
			job["done"] = true
			break
		
		consumed += 1
		iterations += 1
	
	if iterations >= max_iterations:
		push_error("[ChunkManager] _process_chunk_job: Досягнуто максимум ітерацій для чанка " + str(job.get("chunk_pos", "unknown")))

	return consumed

func _process_surface_step(job: Dictionary, gridmap: GridMap):
	if not is_instance_valid(gridmap):
		push_error("[ChunkManager] _process_surface_step: GridMap не валідний")
		job["done"] = true
		return
	
	if not get_parent() or not get_parent().procedural_module:
		push_error("[ChunkManager] _process_surface_step: Немає procedural_module")
		job["done"] = true
		return
	
	var chunk_size_local: Vector2i = job.get("chunk_size", Vector2i.ZERO)
	if chunk_size_local == Vector2i.ZERO:
		push_error("[ChunkManager] _process_surface_step: Невалідний chunk_size")
		job["done"] = true
		return
	
	var current_x: int = job.get("current_x", 0)
	var current_z: int = job.get("current_z", 0)

	if current_x >= chunk_size_local.x:
		if job.get("caves_enabled", false):
			job["phase"] = "caves"
			job["current_x"] = 0
			job["current_z"] = 0
		else:
			job["done"] = true
		return

	var chunk_start = job.get("chunk_start", Vector2i.ZERO)
	var world_x = chunk_start.x + current_x
	var world_z = chunk_start.y + current_z
	
	# ВИПРАВЛЕНО: Одна перевірка валідності координат - якщо невалідні, пропускаємо колонку і продовжуємо
	if world_x < -10000 or world_x > 10000 or world_z < -10000 or world_z > 10000:
		push_error("[ChunkManager] _process_surface_step: Невалідні координати: (" + str(world_x) + ", " + str(world_z) + ") для чанка " + str(job.get("chunk_pos", "unknown")) + ", пропускаємо колонку")
		# Пропускаємо цю колонку і переходимо до наступної
		current_z += 1
		if current_z >= chunk_size_local.y:
			current_z = 0
			current_x += 1
		job["current_x"] = current_x
		job["current_z"] = current_z
		if current_x >= chunk_size_local.x:
			if job.get("caves_enabled", false):
				job["phase"] = "caves"
				job["current_x"] = 0
				job["current_z"] = 0
			else:
				job["done"] = true
		return
	
	# КРИТИЧНА ПЕРЕВІРКА перед генерацією колонки
	if not is_instance_valid(gridmap):
		push_error("[ChunkManager] _process_surface_step: GridMap став невалідним перед generate_column_with_context")
		job["done"] = true
		return
	
	if not get_parent() or not get_parent().procedural_module:
		push_error("[ChunkManager] _process_surface_step: procedural_module не доступний")
		job["done"] = true
		return
	
	# Перевірка наявності context перед генерацією
	if not job.has("context"):
		push_error("[ChunkManager] _process_surface_step: Job без context")
		job["done"] = true
		return
	
	# ВИПРАВЛЕНО: Додано try-catch логіку через обробку помилок
	if get_parent().procedural_module.has_method("generate_column_with_context"):
		get_parent().procedural_module.generate_column_with_context(gridmap, job["context"], world_x, world_z)
	else:
		push_error("[ChunkManager] _process_surface_step: procedural_module не має методу generate_column_with_context")
		job["done"] = true
		return

	current_z += 1
	if current_z >= chunk_size_local.y:
		current_z = 0
		current_x += 1

	job["current_x"] = current_x
	job["current_z"] = current_z

	if current_x >= chunk_size_local.x:
		if job.get("caves_enabled", false):
			job["phase"] = "caves"
			job["current_x"] = 0
			job["current_z"] = 0
		else:
			job["done"] = true

func _process_cave_step(job: Dictionary, gridmap: GridMap):
	var chunk_size_local: Vector2i = job["chunk_size"]
	var current_x: int = job.get("current_x", 0)
	var current_z: int = job.get("current_z", 0)

	if current_x >= chunk_size_local.x:
		job["done"] = true
		return

	var world_x = job["chunk_start"].x + current_x
	var world_z = job["chunk_start"].y + current_z
	
	# КРИТИЧНА ПЕРЕВІРКА перед генерацією печер
	if not is_instance_valid(gridmap):
		push_error("[ChunkManager] _process_cave_step: GridMap став невалідним перед carve_caves_column_with_context")
		job["done"] = true
		return
	
	if not get_parent() or not get_parent().procedural_module:
		push_error("[ChunkManager] _process_cave_step: procedural_module не доступний")
		job["done"] = true
		return
	
	# Перевірка валідності координат
	if world_x < -10000 or world_x > 10000 or world_z < -10000 or world_z > 10000:
		push_error("[ChunkManager] _process_cave_step: Невалідні координати: (" + str(world_x) + ", " + str(world_z) + ")")
		current_z += 1
		if current_z >= chunk_size_local.y:
			current_z = 0
			current_x += 1
		job["current_x"] = current_x
		job["current_z"] = current_z
		if current_x >= chunk_size_local.x:
			job["done"] = true
		return
	
	if get_parent().procedural_module.has_method("carve_caves_column_with_context"):
		get_parent().procedural_module.carve_caves_column_with_context(gridmap, job["context"], world_x, world_z)
	else:
		push_error("[ChunkManager] _process_cave_step: procedural_module не має методу carve_caves_column_with_context")
		job["done"] = true
		return

	current_z += 1
	if current_z >= chunk_size_local.y:
		current_z = 0
		current_x += 1

	job["current_x"] = current_x
	job["current_z"] = current_z

	if current_x >= chunk_size_local.x:
		job["done"] = true

func _finalize_chunk_job(job: Dictionary, gridmap: GridMap):
	if not job.has("chunk_pos"):
		push_error("[ChunkManager] _finalize_chunk_job: Job без chunk_pos")
		return
	
	if not is_instance_valid(gridmap):
		push_error("[ChunkManager] _finalize_chunk_job: GridMap не валідний")
		return
	
	if not get_parent():
		push_error("[ChunkManager] _finalize_chunk_job: Немає батьківського вузла")
		return
	
	var chunk_pos: Vector2i = job["chunk_pos"]
	if debug_prints:
		print("[ChunkManager] _finalize_chunk_job: Фіналізація чанка ", chunk_pos)
	
	# ВИПРАВЛЕНО: Логіка збереження залежить від фази job
	var job_phase = job.get("phase", "surface")
	
	# Для завантажених чанків (phase == "load") - зміни вже відновлені при завантаженні
	# Для процедурно згенерованих чанків (phase == "surface"/"caves") - зберігаємо після генерації
	# В Minecraft збережені чанки мають пріоритет, тому для завантажених не потрібно відновлювати зміни поверх
	if job_phase == "load":
		# Чанк завантажений з диску - зміни вже відновлені, просто зберігаємо знову якщо були нові зміни
		if debug_prints:
			print("[ChunkManager] _finalize_chunk_job: Чанк ", chunk_pos, " завантажений з диску, зміни вже відновлені")
	else:
		# Процедурно згенерований чанк - зберігаємо після генерації
		# В Minecraft для нових чанків зміни відсутні, тому не потрібно відновлювати
		if debug_prints:
			print("[ChunkManager] _finalize_chunk_job: Чанк ", chunk_pos, " згенеровано процедурно")

	# Генеруємо рослинність і деталі після завершення
	if get_parent().vegetation_module and get_parent().use_vegetation:
		if is_instance_valid(get_parent().vegetation_module):
			get_parent().vegetation_module.generate_multimesh_for_chunk(chunk_pos, gridmap)
		else:
			push_warning("[ChunkManager] _finalize_chunk_job: vegetation_module не валідний")

	if get_parent().detail_module and get_parent().use_detail_layers:
		if is_instance_valid(get_parent().detail_module):
			get_parent().detail_module.update_detail_layer(chunk_pos, gridmap)
		else:
			push_warning("[ChunkManager] _finalize_chunk_job: detail_module не валідний")

	_mark_chunk_active(chunk_pos)
	
	# КРИТИЧНО: Якщо це чанк гравця - перевіряємо чи потрібно встановити безпечну позицію
	if player and is_instance_valid(player):
		var player_chunk = get_player_chunk_position()
		if chunk_pos == player_chunk:
			# Чанк гравця згенеровано - перевіряємо чи гравець не в повітрі
			var player_pos = player.global_position
			var chunk_world_start = chunk_pos * chunk_size
			var surface_height = _get_surface_height_at(gridmap, int(player_pos.x), int(player_pos.z), chunk_world_start)
			
			# Якщо гравець в повітрі або під землею - встановлюємо на поверхню
			if surface_height > 0 and (player_pos.y < surface_height - 2 or player_pos.y > surface_height + 20):
				player.global_position.y = surface_height + 2
				if debug_prints:
					print("[ChunkManager] _finalize_chunk_job: Встановлено гравця на поверхню чанка ", chunk_pos, " на висоті ", surface_height + 2)
	
	# ВИПРАВЛЕНО: Генеруємо структури тільки для чанків навколо гравця (в межах chunk_radius)
	if get_parent():
		var parent = get_parent()
		# Перевіряємо наявність structure_module та use_structures
		# Для TerrainGenerator ці властивості завжди існують (можуть бути null)
		if parent.structure_module != null and parent.use_structures:
			if is_instance_valid(parent.structure_module):
				# Перевіряємо, чи чанк знаходиться навколо гравця
				var player_chunk = get_player_chunk_position() if player else Vector2i.ZERO
				var chunk_distance = max(abs(chunk_pos.x - player_chunk.x), abs(chunk_pos.y - player_chunk.y))
				
				# Генеруємо структури тільки для чанків в межах chunk_radius від гравця
				if chunk_distance <= chunk_radius:
					if parent.structure_module.has_method("generate_structures_for_chunk"):
						# Викликаємо синхронно, щоб не блокувати генерацію інших чанків
						parent.structure_module.generate_structures_for_chunk(gridmap, chunk_pos, chunk_size)
					elif parent.structure_module.has_method("generate_structures"):
						# Якщо метод не підтримує chunk-based генерацію, викликаємо загальний метод тільки один раз
						if not parent.has_meta("structures_generated"):
							parent.set_meta("structures_generated", true)
							if debug_prints:
								print("[ChunkManager] _finalize_chunk_job: Генеруємо структури (один раз для всього світу)")
							# Викликаємо асинхронно в фоні, щоб не блокувати генерацію чанків
							parent.structure_module.generate_structures(gridmap)
				elif debug_prints:
					print("[ChunkManager] _finalize_chunk_job: Пропускаємо генерацію структур для далекого чанка ", chunk_pos, " (відстань: ", chunk_distance, ")")
			else:
				push_warning("[ChunkManager] _finalize_chunk_job: structure_module не валідний")
	
	# ВИПРАВЛЕНО: Генеруємо стартову зону після завершення генерації чанка (0, 0)
	if chunk_pos == Vector2i.ZERO and get_parent().starting_area_module and get_parent().use_starting_area:
		if is_instance_valid(get_parent().starting_area_module):
			if debug_prints:
				print("[ChunkManager] _finalize_chunk_job: Генеруємо стартову зону для чанка ", chunk_pos)
			get_parent().starting_area_module.generate_starting_area(gridmap, chunk_pos, chunk_size)
		else:
			push_warning("[ChunkManager] _finalize_chunk_job: starting_area_module не валідний")

	if get_parent().save_load_module and get_parent().use_save_load:
		if is_instance_valid(get_parent().save_load_module):
			var chunk_data = collect_chunk_data(chunk_pos)
			get_parent().save_load_module.save_chunk_data(chunk_pos, chunk_data)
		else:
			push_warning("[ChunkManager] _finalize_chunk_job: save_load_module не валідний")

	var optimization: Dictionary = job.get("optimization", {})
	if debug_prints:
		print("[ChunkManager] _finalize_chunk_job: Успішно завершено чанк ", chunk_pos, " з LOD рівнем ", optimization.get("resolution", 1.0))

func _cancel_chunk_job(chunk_pos: Vector2i):
	if not chunk_generation_job_lookup.has(chunk_pos):
		return

	var job = chunk_generation_job_lookup[chunk_pos]
	var index = chunk_generation_jobs.find(job)
	if index != -1:
		chunk_generation_jobs.remove_at(index)
	chunk_generation_job_lookup.erase(chunk_pos)

func is_chunk_loaded_or_pending(chunk_pos: Vector2i) -> bool:
	"""Об'єднана перевірка: чи чанк завантажений або в процесі генерації"""
	# Перевірка чи чанк вже активний
	if active_chunks.has(chunk_pos):
		var metadata = active_chunks[chunk_pos]
		var state = metadata.get("state", ChunkState.NONE)
		if metadata.get("is_active", false) or state == ChunkState.ACTIVE:
			return true
		# Не генеруємо якщо вже видаляється
		if state == ChunkState.UNLOADING:
			return true
	
	# ВИДАЛЕНО: pending_chunk_generations видалено, використовуємо chunk_generation_jobs
	
	# Перевірка чи є активний job генерації
	if chunk_generation_job_lookup.has(chunk_pos):
		return true
	
	# Перевірка чи є job в масиві
	for job in chunk_generation_jobs:
		if job.get("chunk_pos") == chunk_pos and not job.get("done", false):
			return true
	
	return false

func _is_chunk_job_in_progress(chunk_pos: Vector2i) -> bool:
	return chunk_generation_job_lookup.has(chunk_pos)
