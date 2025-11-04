extends Node
class_name WFCIntegrator

# Модуль для інтеграції WFC (Wave Function Collapse) з ассета

var wfc_generator: Node
var rules: Resource
var mapper: Node

@export var wfc_scene: PackedScene  # Сцена з WFC генератором
@export var rules_resource: Resource  # WFC правила

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
	"""Генерація структури з використанням WFC"""
	if not wfc_generator or not gridmap:
		push_error("WFCIntegrator: WFC генератор або GridMap не ініціалізовані!")
		return false

	# Налаштовуємо правила
	if rules_override:
		wfc_generator.rules = rules_override
	elif rules:
		wfc_generator.rules = rules

	# Налаштовуємо mapper для GridMap
	setup_gridmap_mapper(gridmap, rect)

	# Запускаємо генерацію
	wfc_generator.start_generation()

	print("WFCIntegrator: Запущено WFC генерацію для області ", rect)
	return true

func setup_gridmap_mapper(gridmap: GridMap, rect: Rect2i):
	"""Налаштування mapper'а для GridMap"""
	if not wfc_generator:
		return

	# Створюємо GridMap mapper
	var gridmap_mapper = WFCGridMapMapper2D.new()
	gridmap_mapper.mesh_library = get_mesh_library_from_gridmap(gridmap)
	gridmap_mapper.base_point = Vector3i(rect.position.x, 0, rect.position.y)

	# Налаштовуємо правила для роботи з GridMap
	if wfc_generator.rules:
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
	var new_rules = WFCRules2D.new()

	# Створюємо простий mapper для навчання
	var sample_mapper = WFCGridMapMapper2D.new()
	sample_mapper.mesh_library = get_mesh_library_from_gridmap(sample_gridmap)
	sample_mapper.base_point = Vector3i(sample_rect.position.x, 0, sample_rect.position.y)

	new_rules.mapper = sample_mapper

	# Навчаємо правила (спрощена версія)
	learn_simple_rules(new_rules, sample_gridmap, sample_rect)

	print("WFCIntegrator: Правила навчено")
	return new_rules

func learn_simple_rules(rules: WFCRules2D, sample_gridmap: GridMap, sample_rect: Rect2i):
	"""Простий алгоритм навчання правил"""
	# Це спрощена заглушка - в реальності треба аналізувати сусідні блоки

	# Створюємо базові правила для простих блоків
	rules.axes = [
		Vector2i(0, 1),  # Вниз
		Vector2i(1, 0)   # Вправо
	]

	# Створюємо bit matrices для кожного напрямку
	var axis_matrices: Array[WFCBitMatrix] = []

	for axis in rules.axes:
		var bit_matrix = WFCBitMatrix.new()
		# Спрощена ініціалізація - всі блоки можуть стояти поруч
		# В реальності треба аналізувати навчальну карту
		axis_matrices.append(bit_matrix)

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
