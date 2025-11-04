extends Node
class_name ChunkManager

# Модуль для управління чанками (адаптовано з infinite_heightmap_terrain)

var player: Node3D
var chunk_size := Vector2i(50, 50)
var chunk_radius := 5
var enable_culling := true
var max_distance := 100.0

var active_chunks: Dictionary = {}  # Vector2i -> GridMap chunk
var current_player_chunk: Vector2i

func _ready():
	if not player:
		push_warning("ChunkManager: Player не встановлений!")

func _process(delta):
	if player and enable_culling:
		update_chunk_culling()

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
		regenerate_chunks_around_player(gridmap)

func update_player_chunk_position():
	"""Оновлення позиції чанка гравця"""
	if player:
		current_player_chunk = get_player_chunk_position()

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
	var optimization = {}

	if get_parent().optimization_module and get_parent().use_optimization:
		optimization = get_parent().optimization_module.optimize_chunk_generation(chunk_pos, distance_to_player)

	# Перевіряємо ліміт часу генерації
	if get_parent().optimization_module and get_parent().use_optimization:
		get_parent().optimization_module.start_generation_timer()

	# Тут викликаємо процедурну генерацію для чанка
	if get_parent().procedural_module:
		get_parent().procedural_module.generate_chunk(gridmap, chunk_pos, optimization)

		# Перевіряємо, чи не перевищено час
		if get_parent().optimization_module and get_parent().use_optimization:
			if not get_parent().optimization_module.check_generation_time():
				print("ChunkManager: Генерація перервана через ліміт часу для чанка ", chunk_pos)
				return

	# Генеруємо рослинність для чанка
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
	var chunk_size = Vector2i(50, 50)
	var chunk_start = chunk_pos * chunk_size

	# Зберігаємо блоки чанка
	if get_parent().target_gridmap:
		for x in range(chunk_start.x, chunk_start.x + chunk_size.x):
			for z in range(chunk_start.y, chunk_start.y + chunk_size.y):
				for y in range(-10, 20):  # Діапазон висоти
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

	# Генеруємо нові чанки
	for x in range(-chunk_radius, chunk_radius + 1):
		for z in range(-chunk_radius, chunk_radius + 1):
			var chunk_pos = current_player_chunk + Vector2i(x, z)
			generate_chunk(gridmap, chunk_pos)

func cull_distant_chunks(gridmap: GridMap):
	"""Видалення далеких чанків"""
	var chunks_to_remove: Array[Vector2i] = []

	for chunk_pos in active_chunks.keys():
		var distance = get_chunk_distance(chunk_pos)
		if distance > chunk_radius:
			chunks_to_remove.append(chunk_pos)

	for chunk_pos in chunks_to_remove:
		remove_chunk(gridmap, chunk_pos)

	# Видаляємо рослинність для чанка
	if get_parent().vegetation_module and get_parent().use_vegetation:
		get_parent().vegetation_module.remove_multimesh_for_chunk(chunk_pos)

func remove_chunk(gridmap: GridMap, chunk_pos: Vector2i):
	"""Видалення чанка"""
	if not active_chunks.has(chunk_pos):
		return

	# Видаляємо всі блоки в чанку
	var chunk_start = chunk_pos * chunk_size
	var chunk_end = chunk_start + chunk_size

	for x in range(chunk_start.x, chunk_end.x):
		for z in range(chunk_start.y, chunk_end.y):
			for y in range(-50, 50):  # Діапазон висоти
				gridmap.set_cell_item(Vector3i(x, y, z), -1)

	active_chunks.erase(chunk_pos)
	print("ChunkManager: Видалено чанк ", chunk_pos)

func get_chunk_distance(chunk_pos: Vector2i) -> int:
	"""Отримати відстань чанка від гравця"""
	if not player:
		return 0

	var player_chunk = get_player_chunk_position()
	return max(abs(chunk_pos.x - player_chunk.x), abs(chunk_pos.y - player_chunk.y))

func get_active_chunk_count() -> int:
	"""Отримати кількість активних чанків"""
	return active_chunks.size()
