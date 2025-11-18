extends Node
class_name ConsoleCommands

# Модуль команд для Panku Console
# Доступ до команд через консоль: Player.teleport(x, y, z) або TerrainGenerator.regenerate_chunk(x, z)

var player: Node3D
var terrain_generator: Node

func _ready():
	# Чекаємо один кадр, щоб сцена встигла завантажитися
	await get_tree().process_frame
	
	# Знаходимо гравця та TerrainGenerator
	var world = get_tree().get_root().get_node_or_null("World")
	if world:
		player = world.get_node_or_null("Player")
		# TerrainGenerator може бути дочірнім вузлом World (GridMap)
		terrain_generator = world.get_node_or_null("TerrainGenerator")
		if not terrain_generator:
			# Спробуємо знайти через WorldGenerator
			var world_gen = world
			if world_gen and "terrain_generator" in world_gen:
				terrain_generator = world_gen.terrain_generator
	
	# Реєструємо команди в Panku Console
	_register_commands()

func _register_commands():
	"""Реєстрація команд у Panku Console"""
	# Реєструємо цей об'єкт як 'Debug' для доступу до команд
	var panku = get_node_or_null("/root/Panku")
	if not panku:
		# Спробуємо через autoload
		panku = get_tree().get_root().get_node_or_null("Panku")
	
	if panku and panku.has_method("get") and "gd_exprenv" in panku:
		var gd_exprenv = panku.gd_exprenv
		if gd_exprenv and gd_exprenv.has_method("register_env"):
			gd_exprenv.register_env("Debug", self)
			print("ConsoleCommands: Команди зареєстровано в консолі (використовуйте Debug.command_name())")
		else:
			print("ConsoleCommands: Помилка: gd_exprenv не доступний")
	else:
		print("ConsoleCommands: Помилка: Panku Console не знайдено")

# ========== Команди для гравця ==========

func teleport(x: float, y: float, z: float) -> String:
	"""Телепортувати гравця на позицію (x, y, z)"""
	if not player:
		return "Помилка: Гравець не знайдено"
	
	player.global_position = Vector3(x, y, z)
	return "Гравець телепортовано на (" + str(x) + ", " + str(y) + ", " + str(z) + ")"

func teleport_to_starting_area() -> String:
	"""Телепортувати гравця на стартову зону"""
	if not terrain_generator:
		return "Помилка: TerrainGenerator не знайдено"
	
	if terrain_generator.has_method("teleport_player_to_starting_area"):
		terrain_generator.teleport_player_to_starting_area()
		return "Гравець телепортовано на стартову зону"
	return "Помилка: Метод teleport_player_to_starting_area не знайдено"

func set_speed(multiplier: float) -> String:
	"""Встановити множник швидкості гравця"""
	if not player:
		return "Помилка: Гравець не знайдено"
	
	if "speed_multiplier" in player:
		player.speed_multiplier = clamp(multiplier, 0.1, 10.0)
		return "Швидкість встановлено: " + str(player.speed_multiplier) + "x"
	return "Помилка: Не вдалося встановити швидкість"

func toggle_flight() -> String:
	"""Перемкнути польотний режим"""
	if not player:
		return "Помилка: Гравець не знайдено"
	
	if "flight_mode" in player:
		player.flight_mode = not player.flight_mode
		var status = "увімкнено" if player.flight_mode else "вимкнено"
		return "Польотний режим " + status
	return "Помилка: Не вдалося перемкнути польотний режим"

# ========== Команди для генерації світу ==========

func regenerate_chunk(x: int, z: int) -> String:
	"""Перегенерувати чанк на позиції (x, z)"""
	if not terrain_generator:
		return "Помилка: TerrainGenerator не знайдено"
	
	if not terrain_generator.chunk_module:
		return "Помилка: ChunkManager не доступний"
	
	var chunk_pos = Vector2i(x, z)
	# ВИПРАВЛЕНО: generate_chunk() видалена, використовуємо queue_chunk_generation()
	# Спочатку видаляємо старий чанк якщо він існує
	if terrain_generator.chunk_module.active_chunks.has(chunk_pos):
		if not terrain_generator.target_gridmap or not is_instance_valid(terrain_generator.target_gridmap):
			return "Помилка: GridMap не валідний для видалення чанка"
		terrain_generator.chunk_module.remove_chunk(terrain_generator.target_gridmap, chunk_pos)
	
	# Додаємо в чергу генерації з пріоритетом
	var success = terrain_generator.chunk_module.queue_chunk_generation(chunk_pos)
	if success:
		return "Чанк (" + str(x) + ", " + str(z) + ") додано в чергу генерації"
	else:
		return "Помилка: Не вдалося додати чанк в чергу генерації (перевірте, чи ChunkManager прикріплено до TerrainGenerator та чи валідний target_gridmap)"

func regenerate_world() -> String:
	"""Перегенерувати весь світ"""
	if not terrain_generator:
		return "Помилка: TerrainGenerator не знайдено"
	
	if terrain_generator.has_method("regenerate_terrain"):
		terrain_generator.regenerate_terrain()
		return "Світ перегенеровано"
	return "Помилка: Не вдалося перегенерувати світ"

func get_performance_report() -> String:
	"""Отримати звіт про продуктивність"""
	if not terrain_generator:
		return "Помилка: TerrainGenerator не знайдено"
	
	if terrain_generator.optimization_module and terrain_generator.optimization_module.has_method("get_performance_report"):
		return terrain_generator.optimization_module.get_performance_report()
	return "Помилка: OptimizationManager не доступний"

func toggle_profiling() -> String:
	"""Увімкнути/вимкнути профілювання"""
	if not terrain_generator:
		return "Помилка: TerrainGenerator не знайдено"
	
	if terrain_generator.optimization_module:
		terrain_generator.optimization_module.enable_profiling = not terrain_generator.optimization_module.enable_profiling
		var status = "увімкнено" if terrain_generator.optimization_module.enable_profiling else "вимкнено"
		return "Профілювання " + status
	return "Помилка: OptimizationManager не доступний"

# ========== Допоміжні команди ==========

func get_player_position() -> String:
	"""Отримати поточну позицію гравця"""
	if not player:
		return "Помилка: Гравець не знайдено"
	
	var pos = player.global_position
	return "Позиція гравця: (" + str(pos.x) + ", " + str(pos.y) + ", " + str(pos.z) + ")"

func toggle_xray() -> String:
	"""Перемкнути X-ray режим для підсвітки печер"""
	if not player:
		return "Помилка: Гравець не знайдено"
	
	var build_controller = player.get_node_or_null("BuildMode")
	if build_controller and "enable_xray_mode" in build_controller:
		build_controller.enable_xray_mode = not build_controller.enable_xray_mode
		build_controller._apply_xray_mode()
		var status = "увімкнено" if build_controller.enable_xray_mode else "вимкнено"
		return "X-ray режим " + status
	return "Помилка: BuildController не знайдено"

func toggle_first_person() -> String:
	"""Перемкнути камеру від першої особи"""
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return "Помилка: Камера не знайдена"
	
	if "is_first_person_active" in camera:
		camera.is_first_person_active = not camera.is_first_person_active
		if camera.is_first_person_active:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return "Камера від першої особи увімкнена (V для вимкнення)"
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			camera.first_person_rotation = Vector2.ZERO
			return "Камера від третьої особи увімкнена"
	return "Помилка: Камера не підтримує FPS режим"

func set_break_radius(radius: int) -> String:
	"""Встановити радіус ламання блоків (1-10)"""
	if not player:
		return "Помилка: Гравець не знайдено"
	
	var build_controller = player.get_node_or_null("BuildMode")
	if build_controller and "break_radius" in build_controller:
		build_controller.break_radius = clamp(radius, 1, 10)
		return "Радіус ламання встановлено: " + str(build_controller.break_radius) + " блоків"
	return "Помилка: BuildController не знайдено"

func help() -> String:
	"""Показати список доступних команд"""
	return """Доступні команди:
  === Переміщення ===
  Debug.teleport(x, y, z) - телепортувати гравця
  Debug.teleport_to_starting_area() - телепорт на стартову зону
  Debug.get_player_position() - позиція гравця
  
  === Рух та камера ===
  Debug.set_speed(multiplier) - встановити швидкість (0.1-10.0)
  Debug.toggle_flight() - перемкнути польотний режим (F)
  Debug.toggle_first_person() - камера від першої особи (V)
  
  === Креативний режим ===
  Debug.toggle_xray() - X-ray режим для печер (X)
  Debug.set_break_radius(radius) - радіус ламання блоків (1-10)
  
  === Генерація світу ===
  Debug.regenerate_chunk(x, z) - перегенерувати чанк
  Debug.regenerate_world() - перегенерувати весь світ
  Debug.get_performance_report() - звіт про продуктивність
  Debug.toggle_profiling() - увімкнути/вимкнути профілювання
  
  Debug.help() - показати цю довідку"""

