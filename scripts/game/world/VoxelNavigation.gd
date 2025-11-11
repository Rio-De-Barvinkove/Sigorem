extends Node
class_name VoxelNavigation

# Voxel Navigation - pathfinding через воксельний світ
# Інтегрується з Godot NavigationServer3D або використовує власну логіку

@export_group("Navigation Settings")
@export var enable_navigation := false  # Вимкнено поки - заготовка
@export var use_godot_navigation_server := true  # Використовувати Godot NavigationServer3D
@export var navigation_mesh_resolution := 2.0  # Роздільна здатність навігаційної сітки
@export var max_path_length := 1000  # Максимальна довжина шляху
@export var agent_height := 2.0  # Висота агента
@export var agent_radius := 0.5  # Радіус агента

@export_group("Voxel Pathfinding")
@export var use_voxel_pathfinding := false  # Власна voxel-based навігація
@export var max_jump_height := 2  # Максимальна висота стрибка
@export var max_drop_height := 5  # Максимальна висота падіння

var navigation_mesh: NavigationMesh
var navigation_map_rid: RID

func _ready():
	if enable_navigation:
		initialize_navigation()

func initialize_navigation():
	"""Ініціалізація навігаційної системи"""
	if use_godot_navigation_server:
		setup_godot_navigation()
	else:
		setup_voxel_navigation()

func setup_godot_navigation():
	"""Налаштувати Godot NavigationServer3D"""
	navigation_map_rid = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(navigation_map_rid, true)

	# Створити базову навігаційну сітку
	navigation_mesh = NavigationMesh.new()
	navigation_mesh.agent_radius = agent_radius
	navigation_mesh.agent_height = agent_height

func setup_voxel_navigation():
	"""Налаштувати власну voxel навігацію"""
	# Заготовка для власної системи pathfinding
	pass

func find_path(start_pos: Vector3, end_pos: Vector3) -> PackedVector3Array:
	"""Знайти шлях між двома точками"""
	if not enable_navigation:
		return PackedVector3Array()

	if use_godot_navigation_server:
		return find_path_godot_navigation(start_pos, end_pos)
	else:
		return find_path_voxel_navigation(start_pos, end_pos)

func find_path_godot_navigation(start_pos: Vector3, end_pos: Vector3) -> PackedVector3Array:
	"""Шлях через Godot NavigationServer3D"""
	if navigation_map_rid == RID():
		return PackedVector3Array()

	var path = NavigationServer3D.map_get_path(
		navigation_map_rid,
		start_pos,
		end_pos,
		true  # optimize
	)

	# Обрізати шлях якщо він занадто довгий
	if path.size() > max_path_length:
		path = path.slice(0, max_path_length)

	return path

func find_path_voxel_navigation(start_pos: Vector3, end_pos: Vector3) -> PackedVector3Array:
	"""Шлях через власну voxel навігацію (заготовка)"""
	# Спрощена A* реалізація для воксельних світів
	var path = []

	# Перетворити в дискретні координати
	var start_grid = world_to_grid(start_pos)
	var end_grid = world_to_grid(end_pos)

	# Заготовка для A* алгоритму
	var a_star_path = a_star_search(start_grid, end_grid)

	# Перетворити назад у світові координати
	for grid_pos in a_star_path:
		path.append(grid_to_world(grid_pos))

	return PackedVector3Array(path)

func a_star_search(start: Vector3i, end: Vector3i) -> Array[Vector3i]:
	"""A* пошук для воксельних світів (спрощена версія)"""
	var open_set = []
	var closed_set = []
	var came_from = {}
	var g_score = {}  # Відстань від старту
	var f_score = {}  # g_score + евристика

	open_set.append(start)
	g_score[start] = 0
	f_score[start] = heuristic(start, end)

	while open_set.size() > 0:
		# Знайти вузол з найменшим f_score
		var current = get_lowest_f_score(open_set, f_score)

		if current == end:
			return reconstruct_path(came_from, current)

		open_set.erase(current)
		closed_set.append(current)

		# Перевірити сусідів
		for neighbor in get_neighbors(current):
			if neighbor in closed_set:
				continue

			var tentative_g_score = g_score[current] + 1  # Відстань між сусідами = 1

			if neighbor not in open_set:
				open_set.append(neighbor)
			elif tentative_g_score >= g_score.get(neighbor, INF):
				continue

			# Це кращий шлях
			came_from[neighbor] = current
			g_score[neighbor] = tentative_g_score
			f_score[neighbor] = g_score[neighbor] + heuristic(neighbor, end)

	return []  # Шлях не знайдено

func get_neighbors(pos: Vector3i) -> Array[Vector3i]:
	"""Отримати прохідних сусідів"""
	var neighbors = []

	# 6 основних напрямків (без діагоналей для спрощення)
	var directions = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]

	for dir in directions:
		var neighbor = pos + dir
		if is_walkable(neighbor):
			neighbors.append(neighbor)

	return neighbors

func is_walkable(pos: Vector3i) -> bool:
	"""Перевірити чи позиція прохідна"""
	# Спрощена перевірка - в реальності треба перевіряти GridMap
	var grid_map = get_parent().get_parent().get_node_or_null("GridMap")
	if grid_map:
		# Перевірити чи є тверда поверхня під ногами
		var below = pos + Vector3i(0, -1, 0)
		var block_below = grid_map.get_cell_item(below)
		var block_at = grid_map.get_cell_item(pos)

		# Прохідно якщо знизу є блок, а в позиції пусто
		return block_below >= 0 and block_at < 0

	return true  # Спрощено

func heuristic(a: Vector3i, b: Vector3i) -> float:
	"""Евристична функція для A*"""
	return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)

func get_lowest_f_score(open_set: Array, f_score: Dictionary) -> Vector3i:
	"""Знайти вузол з найменшим f_score"""
	var lowest = open_set[0]
	var lowest_score = f_score.get(lowest, INF)

	for node in open_set:
		var score = f_score.get(node, INF)
		if score < lowest_score:
			lowest_score = score
			lowest = node

	return lowest

func reconstruct_path(came_from: Dictionary, current: Vector3i) -> Array[Vector3i]:
	"""Реконструювати шлях від цілі до старту"""
	var path = [current]
	while came_from.has(current):
		current = came_from[current]
		path.insert(0, current)
	return path

func world_to_grid(world_pos: Vector3) -> Vector3i:
	"""Перетворити світові координати в сіткові"""
	return Vector3i(
		int(world_pos.x),
		int(world_pos.y),
		int(world_pos.z)
	)

func grid_to_world(grid_pos: Vector3i) -> Vector3:
	"""Перетворити сіткові координати в світові"""
	return Vector3(
		float(grid_pos.x),
		float(grid_pos.y),
		float(grid_pos.z)
	)

func update_navigation_mesh_for_chunk(chunk_pos: Vector2i, gridmap: GridMap):
	"""Оновити навігаційну сітку для чанка"""
	if not use_godot_navigation_server or navigation_map_rid == RID() or not navigation_mesh:
		return

	# Створити локальну навігаційну сітку для чанка
	var chunk_size = Vector2i(50, 50)  # Спрощено
	var chunk_world_pos = chunk_pos * chunk_size

	# Визначити область чанка
	var region_rid = NavigationServer3D.region_create()
	var region_transform = Transform3D.IDENTITY
	region_transform.origin = Vector3(chunk_world_pos.x, 0, chunk_world_pos.y)

	# Створити просту навігаційну сітку для області
	NavigationServer3D.region_set_transform(region_rid, region_transform)
	NavigationServer3D.region_set_navigation_mesh(region_rid, navigation_mesh)
	NavigationServer3D.region_set_map(region_rid, navigation_map_rid)

func bake_navigation_mesh():
	"""Запекти навігаційну сітку"""
	if use_godot_navigation_server and navigation_map_rid != RID():
		NavigationServer3D.map_force_update(navigation_map_rid)

func get_navigation_stats() -> Dictionary:
	"""Статистика навігаційної системи"""
	return {
		"use_godot_navigation": use_godot_navigation_server,
		"use_voxel_pathfinding": use_voxel_pathfinding,
		"navigation_enabled": enable_navigation
	}

# Future features - заготовки

func add_dynamic_obstacle(position: Vector3, size: Vector3):
	"""Додати динамічну перешкоду"""
	# В майбутньому: для рухомих об'єктів
	pass

func remove_dynamic_obstacle(position: Vector3):
	"""Видалити динамічну перешкоду"""
	pass

func find_cover_positions(from_pos: Vector3, enemy_pos: Vector3) -> Array:
	"""Знайти позиції укриття"""
	# В майбутньому: для AI
	return []

func is_line_of_sight_clear(start: Vector3, end: Vector3) -> bool:
	"""Перевірити лінію видимості"""
	# Спрощена raycast перевірка
	var grid_map = get_parent().get_parent().get_node_or_null("GridMap")
	if not grid_map:
		return true

	var direction = (end - start).normalized()
	var distance = start.distance_to(end)
	var steps = int(distance)  # Один крок на одиницю

	for i in range(steps):
		var check_pos = start + direction * i
		var grid_pos = world_to_grid(check_pos)

		if grid_map.get_cell_item(grid_pos) >= 0:
			return false  # Є перешкода

	return true
