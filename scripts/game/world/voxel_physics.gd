extends Node

# Воксельна фізика обвалів як у Lay of Land

@export var gravity_strength = 9.8
@export var collapse_delay = 0.1
@export var support_radius = 1
@export var max_unsupported_distance = 3

# Physics Optimization - налаштування
@export var enable_chunk_physics_optimization := true
@export var max_physics_updates_per_frame := 20
@export var physics_update_distance_limit := 50.0  # Відстань від гравця для фізики

var grid_map: GridMap
var falling_blocks = {}
var block_support_map = {}

signal block_collapsed(position: Vector3i)
signal collapse_chain_started(origin: Vector3i)

func _ready():
	pass

func get_gridmap():
	if not is_instance_valid(grid_map):
		var world_node = get_tree().get_root().get_node_or_null("World")
		if world_node:
			grid_map = world_node.get_node_or_null("GridMap")
	return grid_map

func _on_cell_changed(position: Vector3i):
	check_stability_around(position)

func check_stability_around(position: Vector3i):
	if not get_gridmap(): return
	var positions_to_check = []
	for x in range(-support_radius, support_radius + 1):
		for y in range(0, support_radius + 2):
			for z in range(-support_radius, support_radius + 1):
				var check_pos = position + Vector3i(x, y, z)
				if grid_map.get_cell_item(check_pos) != -1:
					positions_to_check.append(check_pos)
	for pos in positions_to_check:
		if not is_block_supported(pos):
			start_collapse(pos)

func is_block_supported(position: Vector3i) -> bool:
	if not get_gridmap(): return true
	if position.y == 0: return true
	var below = position + Vector3i(0, -1, 0)
	if grid_map.get_cell_item(below) != -1: return true
	var diagonal_supports = [
		Vector3i(-1, -1, 0), Vector3i(1, -1, 0),
		Vector3i(0, -1, -1), Vector3i(0, -1, 1),
		Vector3i(-1, -1, -1), Vector3i(1, -1, 1),
		Vector3i(-1, -1, 1), Vector3i(1, -1, -1)
	]
	var support_count = 0
	for offset in diagonal_supports:
		if grid_map.get_cell_item(position + offset) != -1:
			support_count += 1
	return support_count >= 2

func start_collapse(position: Vector3i):
	if position in falling_blocks: return
	if not get_gridmap(): return
	var block_id = grid_map.get_cell_item(position)
	if block_id == -1: return
	grid_map.set_cell_item(position, -1)
	var falling_block = create_falling_block(position, block_id)
	falling_blocks[position] = falling_block
	emit_signal("block_collapsed", position)
	await get_tree().create_timer(collapse_delay).timeout
	check_stability_around(position)

func create_falling_block(position: Vector3i, block_id: int) -> RigidBody3D:
	if not get_gridmap(): return null
	var falling_block = RigidBody3D.new()
	falling_block.position = grid_map.map_to_local(position)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = grid_map.mesh_library.get_item_mesh(block_id)
	falling_block.add_child(mesh_instance)
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3.ONE * grid_map.cell_size.x * 0.9
	collision.shape = box_shape
	falling_block.add_child(collision)
	falling_block.mass = 10.0
	falling_block.gravity_scale = 1.0
	falling_block.linear_damp = 0.5
	falling_block.angular_damp = 2.0
	var random_impulse = Vector3(
		randf_range(-0.5, 0.5),
		randf_range(0, 1),
		randf_range(-0.5, 0.5)
	)
	falling_block.apply_impulse(random_impulse * 2.0)
	get_node("/root/World").add_child(falling_block)
	return falling_block

func _process_falling_blocks(delta):
	if not get_gridmap(): return
	var to_remove = []
	for pos in falling_blocks:
		var block = falling_blocks[pos]
		if not is_instance_valid(block):
			to_remove.append(pos)
			continue
		if block.position.y < -10:
			block.queue_free()
			to_remove.append(pos)
		if block.linear_velocity.length() < 0.1:
			var new_pos = grid_map.local_to_map(block.position)
			if grid_map.get_cell_item(new_pos) == -1:
				pass
	for pos in to_remove:
		falling_blocks.erase(pos)

func excavate_area(center: Vector3i, radius: int):
	if not get_gridmap(): return
	emit_signal("collapse_chain_started", center)
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var pos = center + Vector3i(x, y, z)
				var distance = Vector3(x, y, z).length()
				if distance <= radius:
					if grid_map.get_cell_item(pos) != -1:
						grid_map.set_cell_item(pos, -1)
						await get_tree().create_timer(0.05).timeout
	check_stability_around(center)

# Physics Optimization - методи для оптимізації

var physics_updates_this_frame := 0
var player_position := Vector3.ZERO

func _physics_process(delta):
	_process_falling_blocks(delta)
	physics_updates_this_frame = 0  # Скидаємо лічильник на початку кадру

	# Оновлюємо позицію гравця для оптимізації
	update_player_position()

func update_player_position():
	"""Оновлення позиції гравця для оптимізації"""
	var player = get_tree().get_root().get_node_or_null("World/Player")
	if player:
		player_position = player.global_position

func can_process_physics_at_position(position: Vector3i) -> bool:
	"""Перевірка чи можна обробляти фізику в цій позиції"""
	if not enable_chunk_physics_optimization:
		return true

	# Перевіряємо відстань до гравця
	var distance = Vector3(position).distance_to(player_position)
	if distance > physics_update_distance_limit:
		return false

	# Перевіряємо ліміт оновлень на кадр
	if physics_updates_this_frame >= max_physics_updates_per_frame:
		return false

	physics_updates_this_frame += 1
	return true

func check_stability_around_optimized(position: Vector3i):
	"""Оптимізована перевірка стабільності з обмеженнями"""
	if not can_process_physics_at_position(position):
		return

	check_stability_around(position)

func is_block_supported_optimized(position: Vector3i) -> bool:
	"""Оптимізована перевірка підтримки блоку"""
	if not can_process_physics_at_position(position):
		return true  # Вважаємо підтриманим щоб уникнути зайвих перевірок

	return is_block_supported(position)

# Memory Pooling - заготовка для майбутнього

var physics_objects_pool = []
var max_pool_size = 100

func get_physics_object_from_pool() -> Dictionary:
	"""Отримати об'єкт фізики з пулу"""
	if physics_objects_pool.size() > 0:
		return physics_objects_pool.pop_back()
	return {}

func return_physics_object_to_pool(obj: Dictionary):
	"""Повернути об'єкт фізики в пул"""
	if physics_objects_pool.size() < max_pool_size:
		physics_objects_pool.append(obj)

# Future features - заготовки

func enable_physics_for_chunk(chunk_pos: Vector2i):
	"""Увімкнути фізику для чанка"""
	# В майбутньому: активувати фізику при завантаженні чанка
	pass

func disable_physics_for_chunk(chunk_pos: Vector2i):
	"""Вимкнути фізику для чанка"""
	# В майбутньому: деактивувати фізику при вивантаженні чанка
	pass

func preload_physics_data_for_chunk(chunk_pos: Vector2i):
	"""Попереднє завантаження даних фізики для чанка"""
	# В майбутньому: кешувати дані підтримки блоків
	pass


