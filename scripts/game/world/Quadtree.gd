extends Node
class_name Quadtree

# Quadtree - spatial partitioning для швидкого пошуку чанків
# Оптимізує перевірку відстаней та видимості

class QuadtreeNode:
	var bounds: Rect2i
	var capacity: int
	var points: Array[Vector2i]  # Чанки в цьому вузлі
	var divided: bool = false

	# Дочірні вузли (якщо розділено)
	var northwest: QuadtreeNode = null
	var northeast: QuadtreeNode = null
	var southwest: QuadtreeNode = null
	var southeast: QuadtreeNode = null

	func _init(bounds: Rect2i, capacity: int = 4):
		self.bounds = bounds
		self.capacity = capacity

	func insert(point: Vector2i) -> bool:
		# Перевірити чи точка в межах цього вузла
		if not bounds.has_point(point):
			return false

		# Якщо ще не заповнено і не розділено - додати точку
		if points.size() < capacity and not divided:
			points.append(point)
			return true

		# Якщо потрібно розділити
		if not divided:
			subdivide()

		# Спробувати додати в дочірні вузли
		if northwest.insert(point): return true
		if northeast.insert(point): return true
		if southwest.insert(point): return true
		if southeast.insert(point): return true

		return false

	func subdivide():
		var half_width = bounds.size.x / 2
		var half_height = bounds.size.y / 2
		var center_x = bounds.position.x + half_width
		var center_y = bounds.position.y + half_height

		# Створити дочірні вузли
		northwest = QuadtreeNode.new(
			Rect2i(bounds.position.x, bounds.position.y, half_width, half_height), capacity)
		northeast = QuadtreeNode.new(
			Rect2i(center_x, bounds.position.y, half_width, half_height), capacity)
		southwest = QuadtreeNode.new(
			Rect2i(bounds.position.x, center_y, half_width, half_height), capacity)
		southeast = QuadtreeNode.new(
			Rect2i(center_x, center_y, half_width, half_height), capacity)

		divided = true

		# Перемістити існуючі точки в дочірні вузли
		var points_to_move = points.duplicate()
		points.clear()

		for point in points_to_move:
			if northwest.insert(point): continue
			if northeast.insert(point): continue
			if southwest.insert(point): continue
			if southeast.insert(point): continue

	func query_range(range_bounds: Rect2i) -> Array[Vector2i]:
		"""Знайти всі точки в заданому діапазоні"""
		var found: Array[Vector2i] = []

		if not bounds.intersects(range_bounds):
			return found

		# Додати точки цього вузла що в діапазоні
		for point in points:
			if range_bounds.has_point(point):
				found.append(point)

		# Рекурсивно перевірити дочірні вузли
		if divided:
			found.append_array(northwest.query_range(range_bounds))
			found.append_array(northeast.query_range(range_bounds))
			found.append_array(southwest.query_range(range_bounds))
			found.append_array(southeast.query_range(range_bounds))

		return found

	func find_nearest(point: Vector2i, max_distance: float = -1) -> Array:
		"""Знайти найближчу точку до заданої"""
		var nearest = null
		var min_distance = max_distance if max_distance > 0 else bounds.size.length()

		# Перевірити точки цього вузла
		for chunk_pos in points:
			var distance = point.distance_to(chunk_pos)
			if distance < min_distance:
				min_distance = distance
				nearest = chunk_pos

		# Рекурсивно перевірити дочірні вузли
		if divided:
			var candidates = [
				northwest.find_nearest(point, min_distance),
				northeast.find_nearest(point, min_distance),
				southwest.find_nearest(point, min_distance),
				southeast.find_nearest(point, min_distance)
			]

			for candidate in candidates:
				if candidate and candidate.size() >= 2:
					var dist = candidate[1]
					if dist < min_distance:
						min_distance = dist
						nearest = candidate[0]

		if nearest != null:
			return [nearest, min_distance]
		return []

# Основний клас Quadtree

@export var world_bounds := Rect2i(-1000, -1000, 2000, 2000)  # Великі межі світу
@export var node_capacity := 4  # Максимум точок на вузол

var root: QuadtreeNode

func _ready():
	root = QuadtreeNode.new(world_bounds, node_capacity)

func insert_chunk(chunk_pos: Vector2i):
	"""Додати чанк в quadtree"""
	root.insert(chunk_pos)

func remove_chunk(chunk_pos: Vector2i):
	"""Видалити чанк з quadtree"""
	# Спрощена версія - поки що не реалізовуємо видалення
	# В повній реалізації треба рекурсивно шукати та видаляти
	pass

func get_chunks_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	"""Отримати всі чанки в радіусі від центру"""
	var range_bounds = Rect2i(
		center.x - radius, center.y - radius,
		radius * 2, radius * 2
	)
	return root.query_range(range_bounds)

func get_chunks_in_rect(rect: Rect2i) -> Array[Vector2i]:
	"""Отримати всі чанки в прямокутнику"""
	return root.query_range(rect)

func find_nearest_chunk(point: Vector2i) -> Array:
	"""Знайти найближчий чанк до точки"""
	return root.find_nearest(point)

func get_stats() -> Dictionary:
	"""Отримати статистику quadtree"""
	return {
		"total_chunks": count_chunks(),
		"max_depth": get_max_depth(),
		"node_count": count_nodes()
	}

func count_chunks() -> int:
	"""Порахувати загальну кількість чанків"""
	return _count_chunks_recursive(root)

func _count_chunks_recursive(node: QuadtreeNode) -> int:
	if not node:
		return 0

	var count = node.points.size()
	if node.divided:
		count += _count_chunks_recursive(node.northwest)
		count += _count_chunks_recursive(node.northeast)
		count += _count_chunks_recursive(node.southwest)
		count += _count_chunks_recursive(node.southeast)

	return count

func get_max_depth() -> int:
	"""Отримати максимальну глибину дерева"""
	return _get_max_depth_recursive(root, 0)

func _get_max_depth_recursive(node: QuadtreeNode, current_depth: int) -> int:
	if not node:
		return current_depth

	if not node.divided:
		return current_depth + 1

	var depths = [
		_get_max_depth_recursive(node.northwest, current_depth + 1),
		_get_max_depth_recursive(node.northeast, current_depth + 1),
		_get_max_depth_recursive(node.southwest, current_depth + 1),
		_get_max_depth_recursive(node.southeast, current_depth + 1)
	]

	var max_d = 0
	for d in depths:
		if d > max_d:
			max_d = d
	return max_d

func count_nodes() -> int:
	"""Порахувати кількість вузлів"""
	return _count_nodes_recursive(root)

func _count_nodes_recursive(node: QuadtreeNode) -> int:
	if not node:
		return 0

	var count = 1
	if node.divided:
		count += _count_nodes_recursive(node.northwest)
		count += _count_nodes_recursive(node.northeast)
		count += _count_nodes_recursive(node.southwest)
		count += _count_nodes_recursive(node.southeast)

	return count

# Specialized queries

func get_chunks_in_view_frustum(camera_pos: Vector3, camera_forward: Vector3, view_distance: float) -> Array[Vector2i]:
	"""Отримати чанки в полі зору камери (спрощено)"""
	# Спрощена версія - повертає чанки в радіусі від позиції камери
	var camera_chunk = Vector2i(int(camera_pos.x / 50), int(camera_pos.z / 50))
	return get_chunks_in_radius(camera_chunk, int(view_distance / 50))

func optimize_for_player_position(player_pos: Vector2i, active_radius: int):
	"""Оптимізувати quadtree для позиції гравця"""
	# Можна додати логіку для перебудови дерева з урахуванням активної області
	pass
