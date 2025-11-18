extends Node
class_name WFCIntegrator

# Модуль для інтеграції WFC (Wave Function Collapse) з ассета
#
# ВАЖЛИВО: Цей модуль потребує готового робочого WFC-ассета (наприклад godot-wfc, GDQuest WFC, Overlapping WFC тощо).
# Без реального ассета модуль не працюватиме.
#
# ФІКСИ ЗАСТОСОВАНО:
# - Видалено самопальний код навчання і WFCBitMatrix
# - Додано правильну передачу правил через set_rules() або rules =
# - Додано очікування завершення генерації
# - Спрощено generate_dungeon() і generate_building()
# - Додано setup_gridmap_mapper() для виводу результату в GridMap

var wfc_generator: Node
var rules: Resource
var mapper: Node

@export var wfc_scene: PackedScene  # ВИПРАВЛЕНО: Має бути саме сцена з твоїм WFC-нодом (кореневий нод має методи generate()/run()/start_generation() тощо)
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

func generate_structure_with_wfc(gridmap: GridMap, rect: Rect2i, custom_rules = null) -> bool:
	"""Генерація структури з використанням WFC
	
	ВИПРАВЛЕНО: Мінімальний робочий шаблон після фіксів.
	Потрібно адаптувати під конкретний WFC-ассет.
	"""
	if not wfc_generator or not gridmap:
		push_error("WFCIntegrator: WFC генератор або GridMap не ініціалізовані!")
		return false
	
	if not is_instance_valid(wfc_generator):
		push_error("WFCIntegrator: wfc_generator не валідний!")
		return false

	var final_rules = custom_rules if custom_rules else rules
	
	# ВИПРАВЛЕНО: Передача правил (більшість ассетів приймають rules через set_rules() або в конструкторі)
	if wfc_generator.has_method("set_rules"):
		wfc_generator.set_rules(final_rules)
	else:
		wfc_generator.rules = final_rules
	
	# ВИПРАВЛЕНО: Встановлюємо розмір (якщо підтримується)
	if wfc_generator.has("size"):
		wfc_generator.size = Vector2i(rect.size.x, rect.size.y)
	
	# ВИПРАВЛЕНО: tile_probabilities → initial state (якщо твій ассет підтримує початкові ймовірності)
	if tile_probabilities.size() > 0 and wfc_generator.has_method("set_initial_probabilities"):
		wfc_generator.set_initial_probabilities(tile_probabilities)

	# Налаштовуємо mapper для GridMap
	setup_gridmap_mapper(gridmap, rect)

	# ВИПРАВЛЕНО: Запускаємо генерацію (назва методу залежить від ассета)
	# Приклади: wfc_generator.generate(), wfc_generator.run(), wfc_generator.start_generation()
	var generation_started = false
	if wfc_generator.has_method("generate"):
		wfc_generator.generate()
		generation_started = true
	elif wfc_generator.has_method("run"):
		wfc_generator.run()
		generation_started = true
	elif wfc_generator.has_method("start_generation"):
		wfc_generator.start_generation()
		generation_started = true
	elif wfc_generator.has_method("observe_all"):
		wfc_generator.observe_all()
		generation_started = true
	else:
		push_error("WFCIntegrator: wfc_generator не має методу для запуску генерації (generate/run/start_generation/observe_all)!")
		return false
	
	if not generation_started:
		return false

	# ВИПРАВЛЕНО: Очікування завершення генерації
	await _wait_for_generation_complete()

	# Застосовуємо результат до GridMap
	_apply_wfc_result_to_gridmap(gridmap, rect)
	
	print("WFCIntegrator: Запущено WFC генерацію для області ", rect)
	return true

func _wait_for_generation_complete():
	"""Очікування завершення генерації
	
	ВИПРАВЛЕНО: Додано перевірку або сигнал для очікування завершення генерації.
	"""
	if not wfc_generator:
		return
	
	# Варіант 1: Перевірка через is_running() / is_generating()
	if wfc_generator.has_method("is_running"):
		while wfc_generator.is_running():
			await get_tree().process_frame
	elif wfc_generator.has_method("is_generating"):
		while wfc_generator.is_generating():
			await get_tree().process_frame
	# Варіант 2: Підписка на сигнал finished/completed (якщо є)
	elif wfc_generator.has_signal("finished"):
		await wfc_generator.finished
	elif wfc_generator.has_signal("completed"):
		await wfc_generator.completed
	# Варіант 3: Просто чекаємо один кадр (якщо генерація синхронна)
	else:
		await get_tree().process_frame

func _apply_wfc_result_to_gridmap(gridmap: GridMap, rect: Rect2i):
	"""Застосувати результат WFC генерації до GridMap
	
	ВИПРАВЛЕНО: Додано функцію для виводу результату в GridMap.
	Потрібно адаптувати під конкретний WFC-ассет.
	"""
	if not wfc_generator or not gridmap:
		return
	
	# Варіант 1: Якщо ассет має метод для отримання результату
	if wfc_generator.has_method("get_result"):
		var result = wfc_generator.get_result()
		# Застосовуємо результат до GridMap
		_apply_result_array_to_gridmap(gridmap, rect, result)
	# Варіант 2: Якщо ассет має властивість result
	elif wfc_generator.has("result"):
		var result = wfc_generator.result
		_apply_result_array_to_gridmap(gridmap, rect, result)
	# Варіант 3: Якщо mapper вже застосував результат
	else:
		push_warning("[WFCIntegrator] _apply_wfc_result_to_gridmap: Не вдалося отримати результат генерації!")

func _apply_result_array_to_gridmap(gridmap: GridMap, rect: Rect2i, result: Array):
	"""Застосувати масив результатів до GridMap"""
	if not result or result.is_empty():
		return
	
	# Припускаємо, що result - це 2D масив з ID блоків
	for x in range(rect.size.x):
		for z in range(rect.size.y):
			var index = x * rect.size.y + z
			if index < result.size():
				var block_id = result[index]
				if block_id >= 0:
					var world_pos = Vector3i(rect.position.x + x, 0, rect.position.y + z)
					# Отримуємо висоту терейну
					if get_parent() and get_parent().procedural_module:
						var height = get_parent().procedural_module.get_height_at(world_pos.x, world_pos.z)
						world_pos.y = height
					# Встановлюємо блок
					gridmap.set_cell_item(world_pos, block_id)

func setup_gridmap_mapper(gridmap: GridMap, rect: Rect2i):
	"""Налаштування mapper'а для GridMap
	
	ВИПРАВЛЕНО: Додано функцію для mapper / вивід результату в GridMap.
	Потрібно адаптувати під конкретний WFC-ассет.
	"""
	if not wfc_generator or not gridmap:
		return

	# Варіант 1: Якщо ассет має вбудований mapper
	if wfc_generator.has_method("set_mapper"):
		var gridmap_mapper = _create_gridmap_mapper(gridmap, rect)
		if gridmap_mapper:
			wfc_generator.set_mapper(gridmap_mapper)
	# Варіант 2: Якщо mapper встановлюється через rules
	elif wfc_generator.has("rules") and wfc_generator.rules:
		if wfc_generator.rules.has_method("set_mapper"):
			var gridmap_mapper = _create_gridmap_mapper(gridmap, rect)
			if gridmap_mapper:
				wfc_generator.rules.set_mapper(gridmap_mapper)
		elif wfc_generator.rules.has("mapper"):
			var gridmap_mapper = _create_gridmap_mapper(gridmap, rect)
			if gridmap_mapper:
				wfc_generator.rules.mapper = gridmap_mapper

func _create_gridmap_mapper(gridmap: GridMap, rect: Rect2i):
	"""Створити mapper для GridMap (якщо клас доступний)"""
	# ВИПРАВЛЕНО: Видалено ClassDB.instantiate("WFCBitMatrix") - це точно краш
	# Створюємо GridMap mapper (якщо клас доступний)
	var gridmap_mapper = null
	if ClassDB.class_exists("WFCGridMapMapper2D"):
		gridmap_mapper = ClassDB.instantiate("WFCGridMapMapper2D")
		if gridmap_mapper:
			gridmap_mapper.mesh_library = get_mesh_library_from_gridmap(gridmap)
			if gridmap_mapper.has("base_point"):
				gridmap_mapper.base_point = Vector3i(rect.position.x, 0, rect.position.y)
	
	return gridmap_mapper

func get_mesh_library_from_gridmap(gridmap: GridMap) -> MeshLibrary:
	"""Отримати MeshLibrary з GridMap"""
	if gridmap.mesh_library:
		return gridmap.mesh_library

	# Створюємо базову MeshLibrary якщо немає
	var library = MeshLibrary.new()
	gridmap.mesh_library = library
	return library

func learn_patterns_from_sample(sample_gridmap: GridMap, sample_rect: Rect2i) -> Resource:
	"""Навчити правила з прикладу карти
	
	ВИПРАВЛЕНО: Видалено весь самопальний код навчання і WFCBitMatrix.
	Якщо твій WFC-ассет має вбудоване навчання, використовуй його методи.
	"""
	if not wfc_generator:
		push_error("WFCIntegrator: WFC генератор не ініціалізований!")
		return null

	print("WFCIntegrator: Навчання патернів з прикладу...")

	# ВИПРАВЛЕНО: Використовуємо методи ассета для навчання (якщо є)
	if wfc_generator.has_method("learn_from_sample"):
		var new_rules = wfc_generator.learn_from_sample(sample_gridmap, sample_rect)
		print("WFCIntegrator: Правила навчено через learn_from_sample()")
		return new_rules
	elif wfc_generator.has_method("train"):
		var new_rules = wfc_generator.train(sample_gridmap, sample_rect)
		print("WFCIntegrator: Правила навчено через train()")
		return new_rules
	else:
		push_warning("[WFCIntegrator] learn_patterns_from_sample: WFC-ассет не має методу для навчання!")
		return null

func generate_dungeon(gridmap: GridMap, center: Vector2i, size: Vector2i) -> bool:
	"""Генерація підземелля
	
	ВИПРАВЛЕНО: Спрощено - залишено тільки виклик generate_structure_with_wfc + apply_result.
	"""
	var dungeon_rect = Rect2i(center - size/2, size)
	return await generate_structure_with_wfc(gridmap, dungeon_rect)

func generate_building(gridmap: GridMap, position: Vector2i, building_type: String = "house") -> bool:
	"""Генерація будівлі
	
	ВИПРАВЛЕНО: Спрощено - залишено тільки виклик generate_structure_with_wfc + apply_result.
	"""
	var building_rect = Rect2i(position, Vector2i(10, 10))  # 10x10 блоків

	# Можна мати різні правила для різних типів будівель
	var building_rules = get_building_rules(building_type)

	return await generate_structure_with_wfc(gridmap, building_rect, building_rules)

func get_building_rules(building_type: String) -> Resource:
	"""Отримати правила для конкретного типу будівлі"""
	# Заглушка - повертаємо базові правила
	return rules
