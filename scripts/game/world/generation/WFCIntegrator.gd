extends Node
class_name WFCIntegrator

# Модуль для інтеграції WFC (Wave Function Collapse) з ассета

var wfc_generator: Node
var rules: Resource
var mapper: Node

@export var wfc_scene: PackedScene  # Сцена з WFC генератором
@export var rules_resource: Resource  # WFC правила

# Ймовірності блоків для WFC генерації
@export var tile_probabilities: Dictionary = {
	"0": 0.6, # Air
	"1": 0.3, # Dirt
	"2": 0.1  # Stone
}

func _ready():
	setup_wfc()

func setup_wfc():
	"""Налаштування WFC компонентів"""
	if wfc_scene:
		wfc_generator = wfc_scene.instantiate()
		add_child(wfc_generator)

	if rules_resource:
		rules = rules_resource

	print("WFCIntegrator: WFC компоненти ініціалізовані")

func generate_structure_with_wfc(gridmap: GridMap, rect: Rect2i, rules_override: Resource = null) -> bool:
	"""Генерація структури з використанням WFC з ймовірностями"""
	if not wfc_generator or not gridmap:
		push_error("WFCIntegrator: WFC генератор або GridMap не ініціалізовані!")
		return false

	# Створюємо правила з ймовірностями якщо потрібно
	var final_rules = rules_override if rules_override else rules
	if final_rules and tile_probabilities.size() > 0:
		final_rules = create_rules_with_probabilities(final_rules, rect)

	wfc_generator.rules = final_rules

	# Налаштовуємо mapper для GridMap
	setup_gridmap_mapper(gridmap, rect)

	# Запускаємо генерацію
	wfc_generator.start_generation()

	print("WFCIntegrator: Запущено WFC генерацію для області ", rect, " з ймовірностями")
	return true

func create_rules_with_probabilities(base_rules: Resource, rect: Rect2i) -> Resource:
	"""Створює правила з урахуванням ймовірностей блоків"""
	if not base_rules:
		return null
	var enhanced_rules = base_rules.duplicate()

	# Розраховуємо початковий стан з ймовірностями
	var initial_state = create_initial_state_with_probabilities(rect)

	# Застосовуємо ймовірності до правил
	apply_probabilities_to_rules(enhanced_rules, initial_state)

	return enhanced_rules

func create_initial_state_with_probabilities(rect: Rect2i) -> Array:
	"""Створює початковий стан з урахуванням ймовірностей"""
	var initial_state = []

	# Для кожної позиції в області
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var possible_tiles = []

			# Збираємо всі тайли з їх ймовірностями
			for tile_key in tile_probabilities.keys():
				var probability = tile_probabilities[tile_key]
				var tile_id = int(tile_key)

				# Додаємо тайл стільки разів, скільки відповідає його ймовірності
				var count = max(1, int(probability * 100))  # Масштабуємо для дискретності
				for i in range(count):
					possible_tiles.append(tile_id)

			initial_state.append(possible_tiles)

	return initial_state

func apply_probabilities_to_rules(rules: Resource, initial_state: Array):
	"""Застосовує ймовірності до правил генерації"""
	if not rules:
		return
	# Розширюємо правила додатковою інформацією про ймовірності
	if not rules.has_meta("tile_probabilities"):
		rules.set_meta("tile_probabilities", tile_probabilities.duplicate())

	# Створюємо розширену версію правил з урахуванням ймовірностей
	var enhanced_rules = create_enhanced_rules_with_probabilities(rules)

	# Замінюємо оригінальні правила
	if enhanced_rules:
		for property in enhanced_rules.keys():
			if rules.has("get") and rules.has("set"):
				if rules.get(property) != null:
					rules.set(property, enhanced_rules[property])

func create_enhanced_rules_with_probabilities(base_rules: Resource) -> Dictionary:
	"""Створює розширені правила з ймовірностями"""
	var enhanced = {}
	if not base_rules:
		return enhanced

	# Копіюємо існуючі правила (якщо вони є)
	if base_rules.has("axis_matrices"):
		enhanced["axis_matrices"] = base_rules.axis_matrices.duplicate()

	# Додаємо інформацію про ймовірності
	enhanced["tile_probabilities"] = tile_probabilities.duplicate()

	# Створюємо ймовірнісні матриці сумісності
	if base_rules.has("axis_matrices"):
		enhanced["probability_matrices"] = create_probability_matrices(base_rules.axis_matrices)

	return enhanced

func create_probability_matrices(axis_matrices: Array) -> Array:
	"""Створює матриці з урахуванням ймовірностей"""
	var probability_matrices = []

	for axis_matrix in axis_matrices:
		# Спрощена версія - в реальності треба більш складна логіка
		probability_matrices.append(axis_matrix)

	return probability_matrices

func select_tile_with_probability(possible_tiles: Array) -> int:
	"""Вибір тайла з урахуванням ймовірностей (статичний метод)"""
	if possible_tiles.size() == 0:
		return -1

	if possible_tiles.size() == 1:
		return possible_tiles[0]

	# Створюємо зважені ймовірності для можливих тайлів
	var weighted_options = []
	var total_weight = 0.0

	for tile_id in possible_tiles:
		var tile_key = str(tile_id)
		var weight = tile_probabilities.get(tile_key, 1.0)
		weighted_options.append({"tile": tile_id, "weight": weight})
		total_weight += weight

	# Нормалізуємо ймовірності
	for i in range(weighted_options.size()):
		weighted_options[i]["normalized_weight"] = weighted_options[i]["weight"] / total_weight

	# Випадковий вибір на основі ймовірностей
	var random_value = randf()
	var cumulative_weight = 0.0

	for option in weighted_options:
		cumulative_weight += option["normalized_weight"]
		if random_value <= cumulative_weight:
			return option["tile"]

	# Fallback
	return possible_tiles[randi() % possible_tiles.size()]

func _on_tile_selected_with_probability(position: Vector2i, possible_tiles: Array) -> int:
	"""Вибір тайла на основі ймовірностей"""
	if possible_tiles.size() == 0:
		return -1

	# Створюємо зважені ймовірності
	var weighted_tiles = []
	for tile_id in possible_tiles:
		var tile_key = str(tile_id)
		var weight = tile_probabilities.get(tile_key, 1.0)
		for i in range(int(weight * 10)):  # Масштабуємо ваги
			weighted_tiles.append(tile_id)

	# Випадково вибираємо з урахуванням ваги
	if weighted_tiles.size() > 0:
		return weighted_tiles[randi() % weighted_tiles.size()]
	else:
		return possible_tiles[randi() % possible_tiles.size()]

func setup_gridmap_mapper(gridmap: GridMap, rect: Rect2i):
	"""Налаштування mapper'а для GridMap"""
	if not wfc_generator:
		return

	# Створюємо GridMap mapper (якщо клас доступний)
	var gridmap_mapper
	if ClassDB.class_exists("WFCGridMapMapper2D"):
		gridmap_mapper = ClassDB.instantiate("WFCGridMapMapper2D")
		if gridmap_mapper:
			gridmap_mapper.mesh_library = get_mesh_library_from_gridmap(gridmap)
			if gridmap_mapper.has("base_point"):
				gridmap_mapper.base_point = Vector3i(rect.position.x, 0, rect.position.y)

			# Налаштовуємо правила для роботи з GridMap
			if wfc_generator.has("rules") and wfc_generator.rules:
				if wfc_generator.rules.has("mapper"):
					wfc_generator.rules.mapper = gridmap_mapper

func get_mesh_library_from_gridmap(gridmap: GridMap) -> MeshLibrary:
	"""Отримати MeshLibrary з GridMap"""
	if gridmap.mesh_library:
		return gridmap.mesh_library

	# Створюємо базову MeshLibrary якщо немає
	var library = MeshLibrary.new()
	gridmap.mesh_library = library
	return library

func learn_patterns_from_sample(sample_gridmap: GridMap, sample_rect: Rect2i) -> Resource:
	"""Навчити правила з прикладу карти"""
	if not wfc_generator:
		push_error("WFCIntegrator: WFC генератор не ініціалізований!")
		return null

	print("WFCIntegrator: Навчання патернів з прикладу...")

	# Тут буде логіка навчання з прикладу
	# Зараз заглушка
	var new_rules
	if ClassDB.class_exists("WFCRules2D"):
		new_rules = ClassDB.instantiate("WFCRules2D")
	else:
		new_rules = Resource.new()

	# Створюємо простий mapper для навчання (якщо клас доступний)
	if ClassDB.class_exists("WFCGridMapMapper2D"):
		var sample_mapper = ClassDB.instantiate("WFCGridMapMapper2D")
		if sample_mapper:
			sample_mapper.mesh_library = get_mesh_library_from_gridmap(sample_gridmap)
			if sample_mapper.has("base_point"):
				sample_mapper.base_point = Vector3i(sample_rect.position.x, 0, sample_rect.position.y)
			if new_rules and new_rules.has("mapper"):
				new_rules.mapper = sample_mapper

	# Навчаємо правила (спрощена версія)
	learn_simple_rules(new_rules, sample_gridmap, sample_rect)

	print("WFCIntegrator: Правила навчено")
	return new_rules

func learn_simple_rules(rules: Resource, sample_gridmap: GridMap, sample_rect: Rect2i):
	"""Простий алгоритм навчання правил"""
	if not rules:
		return
	# Це спрощена заглушка - в реальності треба аналізувати сусідні блоки

	# Створюємо базові правила для простих блоків
	if rules.has("axes"):
		rules.axes = [
			Vector2i(0, 1),  # Вниз
			Vector2i(1, 0)   # Вправо
		]

	# Створюємо bit matrices для кожного напрямку
	var axis_matrices: Array = []

	if rules.has("axes"):
		for axis in rules.axes:
			var bit_matrix
			if ClassDB.class_exists("WFCBitMatrix"):
				bit_matrix = ClassDB.instantiate("WFCBitMatrix")
			else:
				bit_matrix = {}
			# Спрощена ініціалізація - всі блоки можуть стояти поруч
			# В реальності треба аналізувати навчальну карту
			axis_matrices.append(bit_matrix)

	if rules.has("axis_matrices"):
		rules.axis_matrices = axis_matrices

func generate_dungeon(gridmap: GridMap, center: Vector2i, size: Vector2i) -> bool:
	"""Генерація підземелля"""
	var dungeon_rect = Rect2i(center - size/2, size)
	return generate_structure_with_wfc(gridmap, dungeon_rect)

func generate_building(gridmap: GridMap, position: Vector2i, building_type: String = "house") -> bool:
	"""Генерація будівлі"""
	var building_rect = Rect2i(position, Vector2i(10, 10))  # 10x10 блоків

	# Можна мати різні правила для різних типів будівель
	var building_rules = get_building_rules(building_type)

	return generate_structure_with_wfc(gridmap, building_rect, building_rules)

func get_building_rules(building_type: String) -> Resource:
	"""Отримати правила для конкретного типу будівлі"""
	# Заглушка - повертаємо базові правила
	return rules
