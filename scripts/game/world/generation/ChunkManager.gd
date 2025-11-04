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
	"""Генерація окремого чанка"""
	if active_chunks.has(chunk_pos):
		return  # Чанк вже існує

	# Тут викликаємо процедурну генерацію для чанка
	if get_parent().procedural_module:
		get_parent().procedural_module.generate_chunk(gridmap, chunk_pos)

	active_chunks[chunk_pos] = true
	print("ChunkManager: Згенеровано чанк ", chunk_pos)

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
