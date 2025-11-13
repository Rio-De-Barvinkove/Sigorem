extends Node
class_name ChunkManager

# Модуль для управління чанками (адаптовано з infinite_heightmap_terrain)

@export var player: Node3D
var chunk_size := Vector2i(50, 50)
var chunk_radius := 5
var enable_culling := true
var max_distance := 100.0
var enable_frustum_culling := true

var active_chunks: Dictionary = {}  # Vector2i -> GridMap chunk
var current_player_chunk: Vector2i

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
	pass  # Гравець може бути встановлений через @export або динамічно

func set_player(new_player: Node3D):
	"""Динамічне встановлення гравця"""
	player = new_player
	if player:
		update_player_chunk_position()

func _process(_delta):
	if player and enable_culling:
		update_chunk_culling(get_parent().target_gridmap)

	# Обробляємо partial mesh updates
	process_partial_updates(_delta)

	# Обробляємо preload queue
	process_preload_queue()

func generate_initial_chunks(gridmap: GridMap):
	"""Генерація початкових чанків навколо гравця"""
	if not player:
		# Якщо немає гравця, генеруємо чанки навколо центру
		current_player_chunk = Vector2i.ZERO
	else:
		update_player_chunk_position()

	# Генеруємо чанки в радіусі
	for x in range(-chunk_radius, chunk_radius + 1):
		for z in range(-chunk_radius, chunk_radius + 1):
			var chunk_pos = current_player_chunk + Vector2i(x, z)
			generate_chunk(gridmap, chunk_pos)

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
		
		# Генеруємо нові чанки (тільки ті, що ще не існують)
		for x in range(-chunk_radius, chunk_radius + 1):
			for z in range(-chunk_radius, chunk_radius + 1):
				var chunk_pos = current_player_chunk + Vector2i(x, z)
				if not active_chunks.has(chunk_pos):
					generate_chunk(gridmap, chunk_pos)

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
	if active_chunks.has(chunk_pos):
		return  # Чанк вже існує

	# Розраховуємо оптимізацію для цього чанка
	var distance_to_player = get_chunk_distance(chunk_pos)
	var optimization := {}
	var use_optimization: bool = get_parent().optimization_module != null and get_parent().use_optimization

	if use_optimization:
		optimization = get_parent().optimization_module.optimize_chunk_generation(chunk_pos, distance_to_player)
		get_parent().optimization_module.start_generation_timer()

	# Генеруємо блоки (з оптимізацією або без)
	if get_parent().procedural_module:
		get_parent().procedural_module.generate_chunk(gridmap, chunk_pos, optimization)

	# Якщо активна оптимізація, перевіряємо ліміт часу та виконуємо додаткові кроки
	if use_optimization:
		if not get_parent().optimization_module.check_generation_time():
			if not get_parent().optimization_module.is_initial_generation:
				print("ChunkManager: Генерація перервана через ліміт часу для чанка ", chunk_pos)
			return

		if get_parent().optimization_module.enable_cull_hidden_faces:
			# УВАГА: Ця оптимізація може гальмувати через подвійну роботу (збір + перебудова)
			# Рекомендація: вимкнути enable_cull_hidden_faces якщо продуктивність падає
			var collect_start = Time.get_ticks_msec() if get_parent().optimization_module.enable_profiling else 0
			var chunk_data = collect_chunk_data(chunk_pos)
			if get_parent().optimization_module.enable_profiling:
				var collect_time = Time.get_ticks_msec() - collect_start
				get_parent().optimization_module.profiling_data["collect_chunk_data_calls"] += 1
				get_parent().optimization_module.profiling_data["collect_chunk_data_time"] += collect_time
			
			var rebuild_start = Time.get_ticks_msec() if get_parent().optimization_module.enable_profiling else 0
			var optimized_data = get_parent().optimization_module.optimize_chunk_mesh(chunk_pos, chunk_data)
			_rebuild_chunk_with_optimized_mesh(gridmap, chunk_pos, optimized_data)
			if get_parent().optimization_module.enable_profiling:
				var rebuild_time = Time.get_ticks_msec() - rebuild_start
				get_parent().optimization_module.profiling_data["rebuild_chunk_calls"] += 1
				get_parent().optimization_module.profiling_data["rebuild_chunk_time"] += rebuild_time

	# Генеруємо рослинність тільки якщо дозволено
	if get_parent().vegetation_module and get_parent().use_vegetation:
		get_parent().vegetation_module.generate_multimesh_for_chunk(chunk_pos, gridmap)

	# Генеруємо detail layers
	if get_parent().detail_module and get_parent().use_detail_layers:
		get_parent().detail_module.update_detail_layer(chunk_pos, gridmap)

	active_chunks[chunk_pos] = true

	# Зберігаємо дані чанка для швидкого завантаження
	if get_parent().save_load_module and get_parent().use_save_load:
		var chunk_data = collect_chunk_data(chunk_pos)
		get_parent().save_load_module.save_chunk_data(chunk_pos, chunk_data)

	print("ChunkManager: Згенеровано чанк ", chunk_pos, " з LOD рівнем ", optimization.get("resolution", 1.0))

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
				generate_chunk(gridmap, chunk_pos)

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
		
		remove_chunk(gridmap, chunk_pos)
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

	# Видаляємо всі блоки в чанку
	var chunk_start = chunk_pos * chunk_size
	var chunk_end = chunk_start + chunk_size

	for x in range(chunk_start.x, chunk_end.x):
		for z in range(chunk_start.y, chunk_end.y):
			for y in range(_get_min_height(), _get_max_height()):
				gridmap.set_cell_item(Vector3i(x, y, z), -1)

	active_chunks.erase(chunk_pos)
	print("ChunkManager: Видалено чанк ", chunk_pos)

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
	return active_chunks.size()

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
		if active_chunks.has(chunk_pos):
			active_chunks[chunk_pos]["needs_reoptimization"] = true

func update_chunk_partial(chunk_pos: Vector2i):
	"""Повністю перебудовує чанк з урахуванням всіх змін"""
	if not active_chunks.has(chunk_pos):
		return

	# Очищаємо чанк
	remove_chunk(get_parent().target_gridmap, chunk_pos)

	# Перегенеровуємо чанк
	generate_chunk(get_parent().target_gridmap, chunk_pos)

	# Позначаємо як оновлений
	active_chunks[chunk_pos]["last_partial_update"] = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]

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
	# Створити запис в active_chunks без фактичного рендерингу
	if not active_chunks.has(chunk_pos):
		active_chunks[chunk_pos] = {
			"preloaded": true,
			"data_ready": false
		}

	# Можна почати асинхронну генерацію даних тут
	# Зараз просто позначаємо як preloaded

func promote_preloaded_chunk(chunk_pos: Vector2i, gridmap: GridMap):
	"""Перетворити preloaded чанк на повноцінний"""
	if not active_chunks.has(chunk_pos) or not active_chunks[chunk_pos].get("preloaded", false):
		return

	# Згенерувати чанк
	generate_chunk(gridmap, chunk_pos)

	# Позначити як завантажений
	active_chunks[chunk_pos] = {"preloaded": false, "data_ready": true}

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
		if active_chunks[chunk_pos].get("preloaded", false) and get_chunk_distance(chunk_pos) > max_distance:
			to_remove.append(chunk_pos)

	for chunk_pos in to_remove:
		active_chunks.erase(chunk_pos)
