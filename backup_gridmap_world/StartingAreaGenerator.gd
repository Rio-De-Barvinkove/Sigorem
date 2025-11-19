extends Node
class_name StartingAreaGenerator

# Starting Area - безпечна зона для нових гравців
# Створює комфортну зону для початку гри

@export_group("Starting Area Settings")
@export var enable_starting_area := true
@export var starting_area_size := 15  # ВИПРАВЛЕНО: Збільшено з 5 до 15 блоків (15×15 м замість 5×5 м)
@export var clear_trees_in_area := true
@export var add_tutorial_structures := false  # Заготовка

@export_group("Terrain Modifications")
@export var flatten_starting_area := true
@export var starting_area_height := 16  # Синхронізовано з base_height
@export var create_paths := false  # Заготовка

@export_group("Safety Features")
@export var remove_hostile_mobs := true
@export var add_basic_resources := false  # Заготовка
@export var always_spawn_on_starting_area := true  # Завжди спавнити гравця на стартовій зоні

var starting_area_chunks = []  # Список чанків що належать до starting area

func generate_starting_area(gridmap: GridMap, center_chunk: Vector2i, chunk_size: Vector2i):
	"""Згенерувати starting area навколо центру"""
	if not enable_starting_area:
		return
	
	if not gridmap or not is_instance_valid(gridmap):
		push_error("[StartingAreaGenerator] generate_starting_area: GridMap не валідний")
		return

	starting_area_chunks.clear()

	# Генеруємо плоску зону 5x5 блоків навколо центру (0, 0)
	var center_world_x = center_chunk.x * chunk_size.x + chunk_size.x / 2
	var center_world_z = center_chunk.y * chunk_size.y + chunk_size.y / 2
	var half_size = starting_area_size / 2
	
	var start_x = int(center_world_x - half_size)
	var end_x = int(center_world_x + half_size)
	var start_z = int(center_world_z - half_size)
	var end_z = int(center_world_z + half_size)

	# Отримуємо min_height з батьківського вузла
	var min_y = _get_min_height()
	var max_y = _get_max_height()
	
	print("[StartingAreaGenerator] generate_starting_area: Генерація стартової зони (", start_x, ", ", start_z, ") - (", end_x, ", ", end_z, ")")
	print("[StartingAreaGenerator] generate_starting_area: Висота: ", min_y, " - ", starting_area_height, " - ", max_y)
	
	# Очищаємо всю область перед генерацією
	for x in range(start_x, end_x + 1):
		for z in range(start_z, end_z + 1):
			# Перевірка валідності GridMap перед кожною операцією
			if not is_instance_valid(gridmap):
				push_error("[StartingAreaGenerator] generate_starting_area: GridMap став невалідним під час генерації")
				return
			
			# Очищаємо всі блоки вище starting_area_height
			for y in range(starting_area_height, max_y):
				gridmap.set_cell_item(Vector3i(x, y, z), -1)
			
			# ВИПРАВЛЕНО: Створюємо плоску поверхню від min_height до starting_area_height
			# Додаємо маленьку платформу з трави на поверхні
			for y in range(min_y, starting_area_height + 1):  # +1 щоб включити starting_area_height
				# Перевірка валідності координати Y
				if y < min_y or y >= max_y:
					continue
				
				# ВИПРАВЛЕНО: Верхній шар (starting_area_height) - трава, решта - земля
				# Це створює маленьку платформу з трави на поверхні
				var block_type = "dirt" if y < starting_area_height else "grass"
				var mesh_index = _get_mesh_index_for_block(gridmap, block_type)
				if mesh_index >= 0:
					if not is_instance_valid(gridmap):
						push_error("[StartingAreaGenerator] generate_starting_area: GridMap став невалідним під час встановлення блоку")
						return
					gridmap.set_cell_item(Vector3i(x, y, z), mesh_index)
				else:
					push_warning("[StartingAreaGenerator] generate_starting_area: Не вдалося отримати mesh_index для блоку ", block_type)
	
	# Зберігаємо інформацію про starting area для подальшого використання
	var center_pos = Vector2i(center_world_x, center_world_z)
	starting_area_chunks.append(center_pos)
	print("[StartingAreaGenerator] generate_starting_area: Стартова зона успішно згенерована на позиції ", center_pos)

func modify_chunk_for_starting_area(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Модифікувати чанк для starting area (застаріло, використовується generate_starting_area)"""
	# Ця функція залишена для сумісності, але логіка перенесена в generate_starting_area
	pass

func add_tutorial_structures_to_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Додати навчальні структури до чанка (заготовка)"""
	# В майбутньому: додати таблички з підказками, базові будинки, тощо
	pass

func is_chunk_in_starting_area(chunk_pos: Vector2i) -> bool:
	"""Перевірити чи чанк знаходиться в starting area"""
	return chunk_pos in starting_area_chunks

func get_starting_area_center() -> Vector2i:
	"""Отримати центр starting area"""
	if starting_area_chunks.is_empty():
		return Vector2i.ZERO

	# Повернути перший елемент (центр starting area)
	return starting_area_chunks[0]

func get_safe_spawn_position(chunk_size_param: Vector2i) -> Vector3:
	"""Отримати безпечну позицію для спавну гравця"""
	if starting_area_chunks.is_empty():
		# Fallback на центр
		return Vector3(0, starting_area_height + 2, 0)
	
	var center_pos = starting_area_chunks[0]  # Vector2i з world координатами
	var world_y = starting_area_height + 2  # Трохи вище поверхні

	return Vector3(center_pos.x, world_y, center_pos.y)

func find_safe_spawn_with_collision_check(gridmap: GridMap, chunk_size_param: Vector2i, player_height: float = 2.0) -> Vector3:
	"""Знайти безпечну позицію з перевіркою колізій"""
	var base_pos = get_safe_spawn_position(chunk_size_param)
	var check_positions = [
		base_pos,
		base_pos + Vector3(0, 1, 0),
		base_pos + Vector3(1, 0, 0),
		base_pos + Vector3(-1, 0, 0),
		base_pos + Vector3(0, 0, 1),
		base_pos + Vector3(0, 0, -1),
	]
	
	for pos in check_positions:
		if _is_position_safe(gridmap, pos, player_height):
			return pos
	
	# Якщо не знайдено безпечної позиції, повертаємо базову
	print("StartingAreaGenerator: Не знайдено ідеальної позиції, використовуємо базову")
	return base_pos

func _is_position_safe(gridmap: GridMap, pos: Vector3, player_height: float) -> bool:
	"""Перевірити чи позиція безпечна для спавну"""
	# Конвертуємо світову позицію в координати GridMap
	var floor_cell = gridmap.local_to_map(gridmap.to_local(pos))
	var head_cell = gridmap.local_to_map(gridmap.to_local(pos + Vector3(0, player_height, 0)))
	var body_cell = gridmap.local_to_map(gridmap.to_local(pos + Vector3(0, player_height * 0.5, 0)))
	
	# Перевіряємо чи є блок під ногами (на рівні ніг або трохи нижче)
	var floor_block = gridmap.get_cell_item(floor_cell)
	var floor_below = gridmap.get_cell_item(Vector3i(floor_cell.x, floor_cell.y - 1, floor_cell.z))
	if floor_block == -1 and floor_below == -1:
		return false
	
	# Перевіряємо чи немає блоків у голові
	var head_block = gridmap.get_cell_item(head_cell)
	if head_block != -1:
		return false
	
	# Перевіряємо чи немає блоків на рівні тіла
	var body_block = gridmap.get_cell_item(body_cell)
	if body_block != -1:
		return false
	
	return true

func clear_hostile_mobs_in_area():
	"""Видалити ворожих мобів з starting area (заготовка)"""
	# В майбутньому: знайти та видалити всіх мобів в зоні
	pass

func add_basic_resources_to_area():
	"""Додати базові ресурси в starting area (заготовка)"""
	# В майбутньому: додати дерево, камінь, їжу поруч з гравцем
	pass

func _get_mesh_index_for_block(gridmap: GridMap, block_name: String) -> int:
	"""Отримати mesh index для блоку з BlockRegistry або fallback (використовує той самий метод що ProceduralGeneration)"""
	if not gridmap:
		return -1
	
	# Спробувати отримати з ProceduralGeneration (якщо доступний) - використовує той самий метод
	if get_parent() and get_parent().procedural_module:
		if get_parent().procedural_module.has_method("get_mesh_index_for_block"):
			return get_parent().procedural_module.get_mesh_index_for_block(gridmap, block_name)
	
	# Спроба 1: BlockRegistry
	if BlockRegistry and BlockRegistry.has_method("get_mesh_index"):
		var index = BlockRegistry.get_mesh_index(block_name)
		if index >= 0:
			return index
	
	# Спроба 2: Пошук у mesh_library за ім'ям
	if gridmap.mesh_library:
		var item_ids := gridmap.mesh_library.get_item_list()
		for item_id in item_ids:
			var item_name = gridmap.mesh_library.get_item_name(item_id)
			if item_name.to_lower().contains(block_name.to_lower()):
				return item_id
	
	# Спроба 3: Жорстка мапа як резерв
	push_warning("[StartingAreaGenerator] _get_mesh_index_for_block: Використовується fallback для блоку ", block_name)
	var fallback_map = {
		"grass": 0,
		"dirt": 1,
		"stone": 2
	}
	return fallback_map.get(block_name.to_lower(), -1)

# Future features - заготовки

func create_tutorial_path(start_pos: Vector3, end_pos: Vector3):
	"""Створити навчальний шлях"""
	# В майбутньому: проложити стежку з підказками
	pass

func add_welcome_sign(position: Vector3, message: String):
	"""Додати табличку з вітальним повідомленням"""
	# В майбутньому: створити 3D табличку з текстом
	pass

func create_basic_shelter(position: Vector3):
	"""Створити базовий прихисток"""
	# В майбутньому: згенерувати простий будиночок
	pass

func _get_min_height() -> int:
	"""Отримати мінімальну висоту з батьківського вузла"""
	if get_parent() and get_parent().has_method("get_min_height"):
		return get_parent().get_min_height()
	return -64  # Дефолтна мінімальна висота (оптимізовано)

func _get_max_height() -> int:
	"""Отримати максимальну висоту з батьківського вузла"""
	if get_parent() and get_parent().has_method("get_max_height"):
		return get_parent().get_max_height()
	return 192  # Дефолтна максимальна висота (оптимізовано)

func setup_tutorial_quests():
	"""Налаштувати навчальні завдання"""
	# В майбутньому: створити квестову систему для нових гравців
	pass
