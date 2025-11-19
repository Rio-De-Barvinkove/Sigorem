extends Node
class_name ErosionSimulator

# Erosion Simulation - природніший рельєф
# Заготовка для гідрологічної/теплової ерозії
# Це фундамент для реалістичного ландшафту в майбутньому

@export_group("Erosion Parameters")
@export var enable_erosion := false  # Вимкнено поки - заготовка
@export var erosion_iterations := 50
@export var erosion_strength := 0.1
@export var sediment_capacity := 0.5
@export var evaporation_rate := 0.01
@export var rain_amount := 0.1

@export_group("Thermal Erosion")
@export var enable_thermal_erosion := false
@export var thermal_iterations := 25
@export var talus_angle := 0.5  # Кут природного укосу
@export var thermal_strength := 0.1

var heightmap = []
var water_map = []
var sediment_map = []

func simulate_erosion_for_chunk(heightmap_data: Array, chunk_pos: Vector2i, chunk_size: Vector2i) -> Array:
	"""Імітація ерозії для чанка"""
	if not enable_erosion:
		return heightmap_data

	# Ініціалізуємо карти
	_initialize_maps(heightmap_data, chunk_size)

	# Базова гідрологічна ерозія (заготовка)
	for iteration in range(erosion_iterations):
		_simulate_hydrological_step()

	# Теплова ерозія якщо увімкнено
	if enable_thermal_erosion:
		for iteration in range(thermal_iterations):
			_simulate_thermal_step()

	# Повертаємо модифікований heightmap
	return _extract_heightmap_from_simulation()

func _initialize_maps(original_heightmap: Array, chunk_size: Vector2i):
	"""Ініціалізація карт для симуляції"""
	heightmap = original_heightmap.duplicate()
	water_map = []
	water_map.resize(chunk_size.x * chunk_size.y)
	water_map.fill(0.0)

	sediment_map = []
	sediment_map.resize(chunk_size.x * chunk_size.y)
	sediment_map.fill(0.0)

func _simulate_hydrological_step():
	"""Один крок гідрологічної ерозії (заготовка)"""
	# Тут буде реалізація:
	# 1. Додати дощ (rain_amount в випадкових місцях)
	# 2. Симулювати потік води вниз по схилу
	# 3. Еродувати матеріал де вода тече швидко
	# 4. Відкладати осад де вода сповільнюється
	pass

func _simulate_thermal_step():
	"""Один крок теплової ерозії (заготовка)"""
	# Тут буде реалізація:
	# 1. Знайти місця де кут схилу > talus_angle
	# 2. Перенести матеріал вниз по схилу
	# 3. Створити природні тераси та укоси
	pass

func _extract_heightmap_from_simulation() -> Array:
	"""Витягти heightmap після симуляції"""
	# Повертаємо модифікований heightmap
	return heightmap

# Future API - заготовки для розширення

func add_rain_at_position(position: Vector2, amount: float):
	"""Додати дощ в конкретній позиції"""
	# В майбутньому: для динамічної погоди
	pass

func get_erosion_strength_at_position(position: Vector2) -> float:
	"""Отримати силу ерозії в позиції"""
	# В майбутньому: для різноманітності місцевості
	return erosion_strength

func simulate_river_erosion(start_pos: Vector2, end_pos: Vector2, flow_strength: float):
	"""Симулювати ерозію річки"""
	# В майбутньому: для створення річкових долин
	pass

func apply_erosion_mask(mask: Array, erosion_type: String):
	"""Застосувати маску ерозії"""
	# В майбутньому: для контрольованої ерозії в певних областях
	pass
