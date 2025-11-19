extends Node
class_name StructureGenerator

# Модуль для генерації структур з використанням WFC
#
# ВАЖЛИВО: Цей модуль має критичні баги:
# - generate_simple_houses() використовує get_terrain_height_at() → якщо procedural_module не готовий → помилка
# - set_block_at() використовує BlockRegistry, якого може не бути → краш
# - generate_wfc_structures() створює Node з скриптом WFCIntegrator.gd, якого може не бути → помилка
# - generate_structures() викликається один раз → структури тільки в одному місці
#
# РЕКОМЕНДАЦІЯ: Залишити use_structures = false назавжди, поки не перепишеш.
# Або зробити простий генератор дерев/каміння без WFC.

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
	# ВИПРАВЛЕНО: Не ініціалізуємо WFC компоненти автоматично через критичні баги
	# setup_wfc_components()  # ВИМКНЕНО через помилки з WFCIntegrator.gd
	push_warning("[StructureGenerator] Модуль має критичні баги. Рекомендується use_structures = false.")

func setup_wfc_components():
	"""Налаштування WFC генератора
	
	КРИТИЧНА ПРОБЛЕМА: Створює Node з скриптом WFCIntegrator.gd, якого може не бути → помилка.
	"""
	# ВИПРАВЛЕНО: Перевірка наявності скрипту перед завантаженням
	var wfc_script_path = "res://scripts/game/world/generation/WFCIntegrator.gd"
	if not ResourceLoader.exists(wfc_script_path):
		push_error("[StructureGenerator] setup_wfc_components: WFCIntegrator.gd не знайдено! Модуль не працюватиме.")
		return false
	
	var wfc_script = load(wfc_script_path)
	if not wfc_script:
		push_error("[StructureGenerator] setup_wfc_components: Не вдалося завантажити WFCIntegrator.gd!")
		return false
	
	var wfc_node = Node.new()
	wfc_node.set_script(wfc_script)
	wfc_integrator = wfc_node
	add_child(wfc_integrator)

	print("StructureGenerator: WFC компоненти ініціалізовані")
	return true

func generate_structures_for_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація структур для конкретного чанка
	
	ВИПРАВЛЕНО: Тепер працює з chunk-based системою.
	Генерує структури тільки для чанків навколо гравця.
	"""
	if not gridmap:
		gridmap = target_gridmap
	if not gridmap:
		push_error("StructureGenerator: GridMap не встановлений!")
		return
	
	if not is_instance_valid(gridmap):
		push_error("[StructureGenerator] generate_structures_for_chunk: GridMap не валідний!")
		return

	# Генеруємо прості будинки для чанка
	generate_simple_houses_for_chunk(gridmap, chunk_pos, chunk_size)

func generate_simple_houses_for_chunk(gridmap: GridMap, chunk_pos: Vector2i, chunk_size: Vector2i):
	"""Генерація простих будинків для конкретного чанка
	
	ВИПРАВЛЕНО: Генерує будинки тільки в межах чанка, використовуючи координати чанка.
	"""
	if not gridmap or not is_instance_valid(gridmap):
		push_error("[StructureGenerator] generate_simple_houses_for_chunk: GridMap не валідний!")
		return
	
	# ВИПРАВЛЕНО: Перевірка наявності procedural_module
	if not get_parent() or not get_parent().procedural_module:
		push_error("[StructureGenerator] generate_simple_houses_for_chunk: procedural_module не доступний! Не можу отримати висоту терейну.")
		return
	
	# Генеруємо 1-2 будинки на чанк
	var houses_per_chunk = randi_range(1, 2)
	
	for i in range(houses_per_chunk):
		# Генеруємо позицію в межах чанка
		var house_pos = Vector2i(
			chunk_pos.x * chunk_size.x + randi_range(5, chunk_size.x - 5),
			chunk_pos.y * chunk_size.y + randi_range(5, chunk_size.y - 5)
		)

		# Перевіряємо, чи не занадто близько до інших структур
		if is_position_valid_for_structure(house_pos):
			# Генеруємо простий будинок
			generate_house(gridmap, house_pos)

func generate_structures(gridmap: GridMap):
	"""Генерація структур на існуючому терейні
	
	КРИТИЧНА ПРОБЛЕМА: Викликається один раз → структури тільки в одному місці.
	Не працює з chunk-based системою.
	ВИКОРИСТОВУЙТЕ generate_structures_for_chunk() замість цього методу.
	"""
	if not gridmap:
		gridmap = target_gridmap
	if not gridmap:
		push_error("StructureGenerator: GridMap не встановлений!")
		return
	
	if not is_instance_valid(gridmap):
		push_error("[StructureGenerator] generate_structures: GridMap не валідний!")
		return

	print("StructureGenerator: Генерація структур...")
	push_warning("[StructureGenerator] generate_structures() викликано - структури генеруються тільки один раз, не працює з chunk-based системою!")

	# ВИПРАВЛЕНО: Перевірка наявності WFC перед викликом
	var wfc_success = false
	if wfc_integrator:
		wfc_success = await generate_wfc_structures(gridmap)

	# Якщо WFC не працює, використовуємо простий генератор
	if not wfc_success:
		await generate_simple_houses(gridmap)

func generate_wfc_structures(gridmap: GridMap) -> bool:
	"""Генерація структур з використанням WFC
	
	КРИТИЧНА ПРОБЛЕМА: Створює Node з скриптом WFCIntegrator.gd, якого може не бути → помилка.
	"""
	if not wfc_integrator:
		push_warning("[StructureGenerator] generate_wfc_structures: wfc_integrator не ініціалізований!")
		return false
	
	if not wfc_integrator.has_method("generate_dungeon"):
		push_error("[StructureGenerator] generate_wfc_structures: wfc_integrator не має методу generate_dungeon()!")
		return false

	# Генеруємо підземелля
	var dungeon_center = Vector2i(50, 50)  # Приклад центру карти
	var success = await wfc_integrator.generate_dungeon(gridmap, dungeon_center, Vector2i(20, 20))

	if success:
		generated_structures.append({"type": "dungeon", "position": dungeon_center, "size": Vector2i(20, 20)})
		print("StructureGenerator: Згенеровано dungeon з WFC")

	return success

func generate_simple_houses(gridmap: GridMap):
	"""Генерація простих будинків
	
	КРИТИЧНА ПРОБЛЕМА: Використовує get_terrain_height_at() → якщо procedural_module не готовий → помилка.
	"""
	if not gridmap or not is_instance_valid(gridmap):
		push_error("[StructureGenerator] generate_simple_houses: GridMap не валідний!")
		return
	
	# ВИПРАВЛЕНО: Перевірка наявності procedural_module
	if not get_parent() or not get_parent().procedural_module:
		push_error("[StructureGenerator] generate_simple_houses: procedural_module не доступний! Не можу отримати висоту терейну.")
		return
	
	var map_size = Vector2i(100, 100)  # Приклад розміру карти

	for i in range(10):  # Генеруємо 10 будинків
		var house_pos = Vector2i(
			randi_range(-map_size.x/2, map_size.x/2),
			randi_range(-map_size.y/2, map_size.y/2)
		)

		# Перевіряємо, чи не занадто близько до інших структур
		if is_position_valid_for_structure(house_pos):
			# ВИПРАВЛЕНО: Перевірка наявності wfc_integrator перед викликом
			var wfc_success = false
			if wfc_integrator and wfc_integrator.has_method("generate_building"):
				wfc_success = await wfc_integrator.generate_building(gridmap, house_pos, "house")

			if not wfc_success:
				# Якщо WFC не працює, використовуємо простий генератор
				generate_house(gridmap, house_pos)

			generated_structures.append({"type": "house", "position": house_pos})

func generate_house(gridmap: GridMap, position: Vector2i):
	"""Генерація окремого будинку
	
	КРИТИЧНА ПРОБЛЕМА: Використовує get_terrain_height_at() → якщо procedural_module не готовий → помилка.
	"""
	if not gridmap or not is_instance_valid(gridmap):
		push_error("[StructureGenerator] generate_house: GridMap не валідний!")
		return
	
	# ВИПРАВЛЕНО: Перевірка наявності procedural_module
	if not get_parent() or not get_parent().procedural_module:
		push_error("[StructureGenerator] generate_house: procedural_module не доступний! Не можу отримати висоту терейну.")
		return
	
	var house_height = 4
	var house_size = Vector2i(5, 5)

	# Основа будинку (камінь)
	for x in range(house_size.x):
		for z in range(house_size.y):
			# ВИПРАВЛЕНО: Перевірка валідності перед викликом get_terrain_height_at()
			var terrain_height = get_terrain_height_at(position.x + x, position.y + z)
			if terrain_height < 0:
				push_warning("[StructureGenerator] generate_house: Не вдалося отримати висоту терейну для позиції (", position.x + x, ", ", position.y + z, ")")
				continue
			
			for y in range(2):  # 2 шари основи
				var block_pos = Vector3i(position.x + x, terrain_height + y, position.y + z)
				set_block_at(gridmap, block_pos, "stone")

	# Стіни (дерево або камінь)
	for x in range(house_size.x):
		for z in range(house_size.y):
			if x == 0 or x == house_size.x - 1 or z == 0 or z == house_size.y - 1:  # Тільки зовнішні стіни
				# ВИПРАВЛЕНО: Перевірка валідності перед викликом get_terrain_height_at()
				var terrain_height = get_terrain_height_at(position.x + x, position.y + z)
				if terrain_height < 0:
					continue
				
				for y in range(2, house_height):
					var block_pos = Vector3i(position.x + x, terrain_height + y, position.y + z)
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
	"""Отримати висоту терейну в точці (адаптувати до вашої системи)
	
	КРИТИЧНА ПРОБЛЕМА: Використовує procedural_module.get_height_at() → якщо procedural_module не готовий → помилка.
	"""
	# ВИПРАВЛЕНО: Перевірка наявності procedural_module перед викликом
	if not get_parent():
		push_warning("[StructureGenerator] get_terrain_height_at: parent не доступний!")
		return -1
	
	if not get_parent().procedural_module:
		push_warning("[StructureGenerator] get_terrain_height_at: procedural_module не доступний!")
		return -1
	
	if not get_parent().procedural_module.has_method("get_height_at"):
		push_warning("[StructureGenerator] get_terrain_height_at: procedural_module не має методу get_height_at()!")
		return -1
	
	return get_parent().procedural_module.get_height_at(x, z)

func set_block_at(gridmap: GridMap, position: Vector3i, block_id: String):
	"""Встановити блок в позиції
	
	КРИТИЧНА ПРОБЛЕМА: Використовує BlockRegistry, якого може не бути → краш.
	"""
	if not gridmap or not is_instance_valid(gridmap):
		push_error("[StructureGenerator] set_block_at: GridMap не валідний!")
		return
	
	# ВИПРАВЛЕНО: Перевірка наявності BlockRegistry перед викликом
	if not BlockRegistry:
		push_error("[StructureGenerator] set_block_at: BlockRegistry не доступний! Не можу встановити блок ", block_id)
		return
	
	if not BlockRegistry.has_method("get_mesh_index"):
		push_error("[StructureGenerator] set_block_at: BlockRegistry не має методу get_mesh_index()!")
		return
	
	var mesh_index = BlockRegistry.get_mesh_index(block_id)
	if mesh_index >= 0:
		gridmap.set_cell_item(position, mesh_index)
	else:
		push_warning("[StructureGenerator] set_block_at: Не вдалося отримати mesh_index для блоку ", block_id)

func clear_structures(gridmap: GridMap):
	"""Видалити всі згенеровані структури"""
	generated_structures.clear()
	print("StructureGenerator: Структури видалені")
