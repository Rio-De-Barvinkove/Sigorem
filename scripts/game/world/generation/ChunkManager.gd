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
@export_range(0, 5, 1) var initial_sync_radius := 1
@export var chunk_generation_budget_per_frame := 64

var active_chunks: Dictionary = {}  # Vector2i -> metadata
var current_player_chunk: Vector2i

var spatial_index: Quadtree
var pending_chunk_generations: Array[Vector2i] = []
var pending_generation_lookup: Dictionary = {}
var chunk_removal_jobs: Array = []
var chunk_generation_jobs: Array = []
var chunk_generation_job_lookup: Dictionary = {}

enum ChunkState {
	PRELOADED,
	ACTIVE
}

# Захист від занадто частого видалення чанків
var last_cull_time: float = 0.0
var min_cull_interval: float = 0.5  # Мінімальний інтервал між видаленнями (секунди)
var max_chunks_to_remove_per_frame: int = 3  # Максимум чанків для видалення за кадр

# Preloading Buffer - завантаження чанків наперед
var enable_preloading := true
var preload_radius := 3  # Радіус попереднього завантаження (за основним радіусом)
var preload_queue: Array[Vector2i] = []
var max_preload_per_frame := 2  # Максимум чанків для попереднього завантаження за кадр

# Partial Mesh Updates - відстеження змінених блоків
var modified_blocks: Dictionary = {}  # Vector3i -> {"old_mesh": int, "new_mesh": int, "timestamp": float}
var max_modified_blocks_per_frame := 10  # Максимум оновлень за кадр
var block_modification_timeout := 1.0  # секунд, після яких зміни застарівають

func _ready():
	_initialize_spatial_index()

func set_player(new_player: Node3D):
	"""Динамічне встановлення гравця"""
	player = new_player
	if player:
		update_player_chunk_position()

func _process(_delta):
	var gridmap: GridMap = null
	if get_parent():
		gridmap = get_parent().target_gridmap

	if player and enable_culling:
		update_chunk_culling(gridmap)

	# Обробляємо partial mesh updates
	process_partial_updates(_delta)

	# Обробляємо preload queue
	process_preload_queue()
	process_generation_queue(gridmap)
	_process_generation_jobs(gridmap)
	process_chunk_removals(gridmap)

func generate_initial_chunks(gridmap: GridMap):
	"""Генерація початкових чанків навколо гравця"""
	if not player:
		# Якщо немає гравця, генеруємо чанки навколо центру
		current_player_chunk = Vector2i.ZERO
	else:
		update_player_chunk_position()

	# Генеруємо чанки в радіусі
	var sync_radius = clamp(initial_sync_radius, 0, chunk_radius)
	for x in range(-chunk_radius, chunk_radius + 1):
		for z in range(-chunk_radius, chunk_radius + 1):
			var chunk_pos = current_player_chunk + Vector2i(x, z)
			if max(abs(x), abs(z)) <= sync_radius:
				generate_chunk(gridmap, chunk_pos)
			else:
				queue_chunk_generation(chunk_pos)

func update_chunks(gridmap: GridMap):
	"""Оновлення чанків при русі гравця"""
	if not player:
		return

	var new_player_chunk = get_player_chunk_position()
	if new_player_chunk != current_player_chunk:
		current_player_chunk = new_player_chunk
		# Видаляємо далекі чанки (з обмеженням частоти)
		if enable_culling:
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_cull_time >= min_cull_interval:
				cull_distant_chunks(gridmap)
				last_cull_time = current_time
		
		# Генеруємо нові чанки (через чергу)
		for x in range(-chunk_radius, chunk_radius + 1):
			for z in range(-chunk_radius, chunk_radius + 1):
				var chunk_pos = current_player_chunk + Vector2i(x, z)
				if not active_chunks.has(chunk_pos):
					queue_chunk_generation(chunk_pos)

func update_player_chunk_position():
	"""Оновлення позиції чанка гравця"""
	if player:
		var old_chunk = current_player_chunk
		current_player_chunk = get_player_chunk_position()

		# Оновити preload queue якщо позиція змінилась
		if current_player_chunk != old_chunk:
			update_preload_queue()

func get_player_chunk_position() -> Vector2i:
	"""Отримати позицію чанка гравця"""
	if not player:
		return Vector2i.ZERO

	var player_pos = player.global_position
	return Vector2i(
		int(player_pos.x / chunk_size.x),
		int(player_pos.z / chunk_size.y)
	)

func generate_chunk(gridmap: GridMap, chunk_pos: Vector2i):
	"""Генерація окремого чанка з оптимізацією"""
	if not gridmap:
		return
	var existing_metadata = active_chunks.get(chunk_pos, null)
	if existing_metadata and existing_metadata.get("is_active", false):
		return  # Чанк вже існує і активний
	if _is_chunk_job_in_progress(chunk_pos):
		return

	var job = _create_chunk_generation_job(chunk_pos, gridmap, false)
	if not job:
		return

	var sync_budget = max(1, job["chunk_size"].x * job["chunk_size"].y * 2)
	while not job.get("done", false):
		_process_chunk_job(job, gridmap, sync_budget)

	_finalize_chunk_job(job, gridmap)
	if pending_generation_lookup.has(chunk_pos):
		pending_generation_lookup.erase(chunk_pos)

func collect_chunk_data(chunk_pos: Vector2i) -> Dictionary:
	"""Збір даних чанка для збереження"""
	var chunk_data = {}
	var chunk_start = chunk_pos * chunk_size

	# Зберігаємо блоки чанка
	if get_parent().target_gridmap:
		for x in range(chunk_start.x, chunk_start.x + chunk_size.x):
			for z in range(chunk_start.y, chunk_start.y + chunk_size.y):
				for y in range(_get_min_height(), _get_max_height()):
					var cell_item = get_parent().target_gridmap.get_cell_item(Vector3i(x, y, z))
					if cell_item >= 0:
						var key = str(x) + "_" + str(y) + "_" + str(z)
						chunk_data[key] = cell_item

	return chunk_data

func regenerate_chunks_around_player(gridmap: GridMap):
	"""Регенерація чанків навколо гравця"""
	# Видаляємо далекі чанки
	if enable_culling:
		cull_distant_chunks(gridmap)

	# Генеруємо нові чанки (тільки ті, що ще не існують)
	for x in range(-chunk_radius, chunk_radius + 1):
		for z in range(-chunk_radius, chunk_radius + 1):
			var chunk_pos = current_player_chunk + Vector2i(x, z)
			if not active_chunks.has(chunk_pos):
				queue_chunk_generation(chunk_pos)

func cull_distant_chunks(gridmap: GridMap):
	"""Видалення далеких чанків з урахуванням frustum та occlusion culling"""
	var chunks_to_remove: Array[Vector2i] = []

	# Отримуємо камеру для frustum culling
	var camera = get_viewport().get_camera_3d() if get_viewport() else null

	for chunk_pos in active_chunks.keys():
		var should_remove = false

		# Перевірка відстані (з додатковим буфером, щоб уникнути занадто частого видалення)
		var distance = get_chunk_distance(chunk_pos)
		var cull_threshold = chunk_radius + 1  # Додатковий буфер перед видаленням
		if distance > cull_threshold:
			should_remove = true

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

	# Обмежуємо кількість чанків для видалення за кадр
	var chunks_removed_this_frame = 0
	for chunk_pos in chunks_to_remove:
		if chunks_removed_this_frame >= max_chunks_to_remove_per_frame:
			break
		
		request_chunk_removal(gridmap, chunk_pos)
		chunks_removed_this_frame += 1

		# Видаляємо рослинність для чанка
		if get_parent().vegetation_module and get_parent().use_vegetation:
			get_parent().vegetation_module.remove_multimesh_for_chunk(chunk_pos)

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

	print("ChunkManager: Перебудовано чанк ", chunk_pos, " з ", optimized_data.size(), " оптимізованими блоками")

func remove_chunk(gridmap: GridMap, chunk_pos: Vector2i):
	"""Видалення чанка"""
	if not active_chunks.has(chunk_pos):
		return

	var metadata = active_chunks.get(chunk_pos)

	# Видаляємо всі блоки в чанку
	var chunk_start = chunk_pos * chunk_size
	var chunk_end = chunk_start + chunk_size

	for x in range(chunk_start.x, chunk_end.x):
		for z in range(chunk_start.y, chunk_end.y):
			for y in range(_get_min_height(), _get_max_height()):
				gridmap.set_cell_item(Vector3i(x, y, z), -1)

	_remove_chunk_from_spatial_index(chunk_pos, metadata)
	active_chunks.erase(chunk_pos)
	print("ChunkManager: Видалено чанк ", chunk_pos)

func request_chunk_removal(gridmap: GridMap, chunk_pos: Vector2i):
	"""Заплановане (ліниве) видалення чанка з поетапним очищенням"""
	if not gridmap or not active_chunks.has(chunk_pos):
		return

	_cancel_chunk_job(chunk_pos)
	var metadata = active_chunks.get(chunk_pos)
	_remove_chunk_from_spatial_index(chunk_pos, metadata)
	active_chunks.erase(chunk_pos)
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

	# Розраховуємо bounding box чанка
	var chunk_world_pos = chunk_pos * chunk_size
	var vertical_span = float(_get_max_height() - _get_min_height())
	var chunk_center = Vector3(chunk_world_pos.x + chunk_size.x/2.0, _get_min_height() + vertical_span / 2.0, chunk_world_pos.y + chunk_size.y/2.0)
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

func update_chunk_culling(gridmap: GridMap):
	"""Оновлення culling чанків"""
	if not gridmap:
		return

	# Перевіряємо, чи потрібно перегенерувати чанки навколо гравця
	var current_chunk = get_player_chunk_position()
	if current_chunk != current_player_chunk:
		current_player_chunk = current_chunk
		regenerate_chunks_around_player(gridmap)

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
		"timestamp": Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
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
	var current_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
	var expired_keys = []

	for world_pos in modified_blocks.keys():
		var change_data = modified_blocks[world_pos]
		if current_time - change_data["timestamp"] > block_modification_timeout:
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

	# Перегенеровуємо чанк
	generate_chunk(get_parent().target_gridmap, chunk_pos)

	# Позначаємо як оновлений
	var metadata = _ensure_chunk_metadata(chunk_pos, false)
	if metadata:
		metadata["last_partial_update"] = _get_timestamp()
		active_chunks[chunk_pos] = metadata

func _get_chunk_pos_for_world_pos(world_pos: Vector3i) -> Vector2i:
	"""Отримати позицію чанка для світової позиції блоку"""
	return Vector2i(world_pos.x / chunk_size.x, world_pos.z / chunk_size.y)

func get_modified_blocks_count() -> int:
	"""Отримати кількість змінених блоків в черзі"""
	return modified_blocks.size()

func _get_max_height() -> int:
	var height = 64
	if get_parent() and get_parent().has_method("get_max_height"):
		height = get_parent().get_max_height()
	return max(height, _get_min_height() + 1)

func _get_min_height() -> int:
	return 0

# Preloading Buffer - методи для попереднього завантаження

func update_preload_queue():
	"""Оновити чергу попереднього завантаження"""
	if not enable_preloading or not player:
		return

	var player_chunk = get_player_chunk_position()
	preload_queue.clear()

	# Додати чанки в preload радіусі (за межами основного радіуса)
	var extended_radius = chunk_radius + preload_radius
	for x in range(-extended_radius, extended_radius + 1):
		for z in range(-extended_radius, extended_radius + 1):
			if abs(x) + abs(z) <= extended_radius:  # Ромбовидна форма
				var chunk_pos = player_chunk + Vector2i(x, z)

				# Пропустити якщо вже завантажений або в основному радіусі
				if active_chunks.has(chunk_pos) or get_chunk_distance(chunk_pos) <= chunk_radius:
					continue

				preload_queue.append(chunk_pos)

	# Сортувати за відстанню (ближчі першими)
	preload_queue.sort_custom(func(a, b): return get_chunk_distance(a) < get_chunk_distance(b))

func process_preload_queue():
	"""Обробити чергу попереднього завантаження"""
	if preload_queue.is_empty():
		return

	var processed = 0
	while processed < max_preload_per_frame and not preload_queue.is_empty():
		var chunk_pos = preload_queue.pop_front()

		# Перевірити чи чанк ще потрібен (мав бути завантажений основною логікою)
		if not active_chunks.has(chunk_pos) and get_chunk_distance(chunk_pos) <= chunk_radius + preload_radius:
			# Попередньо завантажити дані чанка (без рендерингу)
			preload_chunk_data(chunk_pos)

		processed += 1

func preload_chunk_data(chunk_pos: Vector2i):
	"""Попередньо завантажити дані чанка (без рендерингу)"""
	if not active_chunks.has(chunk_pos):
		_mark_chunk_preloaded(chunk_pos)

func promote_preloaded_chunk(chunk_pos: Vector2i, gridmap: GridMap):
	"""Перетворити preloaded чанк на повноцінний"""
	var metadata = active_chunks.get(chunk_pos, null)
	if not metadata or not metadata.get("preloaded", false):
		return

	# Згенерувати чанк
	generate_chunk(gridmap, chunk_pos)

func get_preload_queue_size() -> int:
	"""Отримати розмір черги попереднього завантаження"""
	return preload_queue.size()

func force_preload_chunks(count: int):
	"""Примусово попередньо завантажити задану кількість чанків"""
	var preloaded = 0
	while preloaded < count and not preload_queue.is_empty():
		var chunk_pos = preload_queue.pop_front()
		preload_chunk_data(chunk_pos)
		preloaded += 1

# Future features - заготовки

func preload_chunks_around_player(radius: int = 2):
	"""Попередньо завантажити чанки навколо гравця"""
	if not player:
		return

	var player_chunk = get_player_chunk_position()
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			var chunk_pos = player_chunk + Vector2i(x, z)
			if not active_chunks.has(chunk_pos):
				preload_chunk_data(chunk_pos)

func unload_preloaded_chunks_outside_radius(max_distance: int):
	"""Видалити preloaded чанки за межами радіуса"""
	var to_remove = []
	for chunk_pos in active_chunks.keys():
		var metadata = active_chunks[chunk_pos]
		if metadata.get("preloaded", false) and get_chunk_distance(chunk_pos) > max_distance:
			to_remove.append(chunk_pos)

	for chunk_pos in to_remove:
		var metadata = active_chunks.get(chunk_pos, null)
		_remove_chunk_from_spatial_index(chunk_pos, metadata)
		active_chunks.erase(chunk_pos)

func queue_chunk_generation(chunk_pos: Vector2i):
	if active_chunks.has(chunk_pos):
		return
	if pending_generation_lookup.has(chunk_pos):
		return
	if _is_chunk_job_in_progress(chunk_pos):
		return
	pending_chunk_generations.append(chunk_pos)
	pending_generation_lookup[chunk_pos] = true

func process_generation_queue(gridmap: GridMap):
	if not gridmap:
		return
	if pending_chunk_generations.is_empty():
		return
	if max_chunk_generations_per_frame <= 0:
		return

	var processed := 0
	while processed < max_chunk_generations_per_frame and not pending_chunk_generations.is_empty():
		var chunk_pos: Vector2i = pending_chunk_generations.pop_front()
		if pending_generation_lookup.has(chunk_pos):
			pending_generation_lookup.erase(chunk_pos)
		if active_chunks.has(chunk_pos) or _is_chunk_job_in_progress(chunk_pos):
			continue
		var job = _create_chunk_generation_job(chunk_pos, gridmap, true)
		if job:
			chunk_generation_jobs.append(job)
			processed += 1

func process_chunk_removals(gridmap: GridMap):
	if not gridmap or chunk_removal_jobs.is_empty():
		return
	if max_chunk_clear_ops_per_frame <= 0:
		return

	var ops_left := max_chunk_clear_ops_per_frame
	var index := 0
	while index < chunk_removal_jobs.size() and ops_left > 0:
		var job = chunk_removal_jobs[index]
		ops_left -= _process_chunk_removal_job(job, gridmap, ops_left)
		if job.get("done", false):
			chunk_removal_jobs.remove_at(index)
		else:
			index += 1

func _process_chunk_removal_job(job: Dictionary, gridmap: GridMap, budget: int) -> int:
	var consumed := 0
	while consumed < budget:
		if job["x"] >= job["end_x"]:
			job["done"] = true
			break

		var cell = Vector3i(job["x"], job["y"], job["z"])
		gridmap.set_cell_item(cell, -1)
		consumed += 1

		job["z"] += 1
		if job["z"] >= job["end_z"]:
			job["z"] = job["start_z"]
			job["y"] += 1
			if job["y"] >= job["y_max"]:
				job["y"] = job["y_min"]
				job["x"] += 1

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
	var preload_extra = preload_radius if enable_preloading else 0
	var effective_radius = max(chunk_radius + preload_extra + spatial_margin_chunks, 1)
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

	var distance_to_player = get_chunk_distance(chunk_pos)
	var optimization := {}
	var use_optimization: bool = get_parent().optimization_module != null and get_parent().use_optimization
	if use_optimization:
		optimization = get_parent().optimization_module.optimize_chunk_generation(chunk_pos, distance_to_player)

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
	if not gridmap or chunk_generation_jobs.is_empty():
		return
	if chunk_generation_budget_per_frame <= 0:
		return

	var budget := chunk_generation_budget_per_frame
	var index := 0
	while index < chunk_generation_jobs.size() and budget > 0:
		var job = chunk_generation_jobs[index]
		var consumed = _process_chunk_job(job, gridmap, budget)
		budget -= consumed

		if job.get("done", false):
			_finalize_chunk_job(job, gridmap)
			var chunk_pos: Vector2i = job["chunk_pos"]
			if chunk_generation_job_lookup.has(chunk_pos):
				chunk_generation_job_lookup.erase(chunk_pos)
			chunk_generation_jobs.remove_at(index)
		else:
			index += 1

func _process_chunk_job(job: Dictionary, gridmap: GridMap, budget: int) -> int:
	if budget <= 0 or job.get("done", false):
		return 0

	var consumed := 0
	while consumed < budget and not job.get("done", false):
		if job.get("phase", "surface") == "surface":
			_process_surface_step(job, gridmap)
		else:
			_process_cave_step(job, gridmap)
		consumed += 1

	return consumed

func _process_surface_step(job: Dictionary, gridmap: GridMap):
	var chunk_size_local: Vector2i = job["chunk_size"]
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

	var world_x = job["chunk_start"].x + current_x
	var world_z = job["chunk_start"].y + current_z
	get_parent().procedural_module.generate_column_with_context(gridmap, job["context"], world_x, world_z)

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
	get_parent().procedural_module.carve_caves_column_with_context(gridmap, job["context"], world_x, world_z)

	current_z += 1
	if current_z >= chunk_size_local.y:
		current_z = 0
		current_x += 1

	job["current_x"] = current_x
	job["current_z"] = current_z

	if current_x >= chunk_size_local.x:
		job["done"] = true

func _finalize_chunk_job(job: Dictionary, gridmap: GridMap):
	var chunk_pos: Vector2i = job["chunk_pos"]

	# Генеруємо рослинність і деталі після завершення
	if get_parent().vegetation_module and get_parent().use_vegetation:
		get_parent().vegetation_module.generate_multimesh_for_chunk(chunk_pos, gridmap)

	if get_parent().detail_module and get_parent().use_detail_layers:
		get_parent().detail_module.update_detail_layer(chunk_pos, gridmap)

	_mark_chunk_active(chunk_pos)

	if get_parent().save_load_module and get_parent().use_save_load:
		var chunk_data = collect_chunk_data(chunk_pos)
		get_parent().save_load_module.save_chunk_data(chunk_pos, chunk_data)

	var optimization: Dictionary = job.get("optimization", {})
	print("ChunkManager: Згенеровано чанк ", chunk_pos, " з LOD рівнем ", optimization.get("resolution", 1.0))

func _cancel_chunk_job(chunk_pos: Vector2i):
	if not chunk_generation_job_lookup.has(chunk_pos):
		return

	var job = chunk_generation_job_lookup[chunk_pos]
	var index = chunk_generation_jobs.find(job)
	if index != -1:
		chunk_generation_jobs.remove_at(index)
	chunk_generation_job_lookup.erase(chunk_pos)

func _is_chunk_job_in_progress(chunk_pos: Vector2i) -> bool:
	return chunk_generation_job_lookup.has(chunk_pos)
