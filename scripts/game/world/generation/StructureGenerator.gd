extends Node
class_name StructureGenerator

# Модуль для генерації структур з використанням WFC

var target_gridmap: GridMap

# WFC компоненти (якщо підключені)
var wfc_generator: Node
var rules: Resource

@export_group("Налаштування структур")
@export var structure_density := 0.1  # Щільність структур (0.0 - 1.0)
@export var min_structure_distance := 20  # Мінімальна відстань між структурами
@export var structure_types: Array[String] = ["house", "cave", "ruins"]

var generated_structures: Array = []
var wfc_integrator

func _ready():
	# Ініціалізація WFC компонентів
	setup_wfc_components()

func setup_wfc_components():
	"""Налаштування WFC генератора"""
	var wfc_node = Node.new()
	wfc_node.set_script(load("res://scripts/game/world/generation/WFCIntegrator.gd"))
	wfc_integrator = wfc_node
	add_child(wfc_integrator)

	print("StructureGenerator: WFC компоненти ініціалізовані")

func generate_structures(gridmap: GridMap):
	"""Генерація структур на існуючому терейні"""
	if not gridmap:
		gridmap = target_gridmap
	if not gridmap:
		push_error("StructureGenerator: GridMap не встановлений!")
		return

	print("StructureGenerator: Генерація структур...")

	# Спробуємо використати WFC для складних структур
	var wfc_success = generate_wfc_structures(gridmap)

	# Якщо WFC не працює, використовуємо простий генератор
	if not wfc_success:
		generate_simple_houses(gridmap)

func generate_wfc_structures(gridmap: GridMap) -> bool:
	"""Генерація структур з використанням WFC"""
	if not wfc_integrator:
		return false

	# Генеруємо підземелля
	var dungeon_center = Vector2i(50, 50)  # Приклад центру карти
	var success = wfc_integrator.generate_dungeon(gridmap, dungeon_center, Vector2i(20, 20))

	if success:
		generated_structures.append({"type": "dungeon", "position": dungeon_center, "size": Vector2i(20, 20)})
		print("StructureGenerator: Згенеровано dungeon з WFC")

	return success

func generate_simple_houses(gridmap: GridMap):
	"""Генерація простих будинків"""
	var map_size = Vector2i(100, 100)  # Приклад розміру карти

	for i in range(10):  # Генеруємо 10 будинків
		var house_pos = Vector2i(
			randi_range(-map_size.x/2, map_size.x/2),
			randi_range(-map_size.y/2, map_size.y/2)
		)

		# Перевіряємо, чи не занадто близько до інших структур
		if is_position_valid_for_structure(house_pos):
			# Спробуємо використати WFC для будинку
			var wfc_success = wfc_integrator and wfc_integrator.generate_building(gridmap, house_pos, "house")

			if not wfc_success:
				# Якщо WFC не працює, використовуємо простий генератор
				generate_house(gridmap, house_pos)

			generated_structures.append({"type": "house", "position": house_pos})

func generate_house(gridmap: GridMap, position: Vector2i):
	"""Генерація окремого будинку"""
	var house_height = 4
	var house_size = Vector2i(5, 5)

	# Основа будинку (камінь)
	for x in range(house_size.x):
		for z in range(house_size.y):
			for y in range(2):  # 2 шари основи
				var block_pos = Vector3i(position.x + x, get_terrain_height_at(position.x + x, position.y + z) + y, position.y + z)
				set_block_at(gridmap, block_pos, "stone")

	# Стіни (дерево або камінь)
	for x in range(house_size.x):
		for z in range(house_size.y):
			if x == 0 or x == house_size.x - 1 or z == 0 or z == house_size.y - 1:  # Тільки зовнішні стіни
				for y in range(2, house_height):
					var block_pos = Vector3i(position.x + x, get_terrain_height_at(position.x + x, position.y + z) + y, position.y + z)
					set_block_at(gridmap, block_pos, "stone")

	# Дах (якщо потрібно)
	# ...

	print("StructureGenerator: Згенеровано будинок на позиції ", position)

func is_position_valid_for_structure(position: Vector2i) -> bool:
	"""Перевірка, чи можна розмістити структуру на цій позиції"""
	for structure in generated_structures:
		var distance = (structure.position - position).length()
		if distance < min_structure_distance:
			return false
	return true

func get_terrain_height_at(x: int, z: int) -> int:
	"""Отримати висоту терейну в точці (адаптувати до вашої системи)"""
	# Це заглушка - треба інтегрувати з ProceduralGeneration
	if get_parent().procedural_module:
		return get_parent().procedural_module.get_height_at(x, z)
	return 5  # Базова висота

func set_block_at(gridmap: GridMap, position: Vector3i, block_id: String):
	"""Встановити блок в позиції"""
	var mesh_index = BlockRegistry.get_mesh_index(block_id)
	if mesh_index >= 0:
		gridmap.set_cell_item(position, mesh_index)

func clear_structures(gridmap: GridMap):
	"""Видалити всі згенеровані структури"""
	generated_structures.clear()
	print("StructureGenerator: Структури видалені")
