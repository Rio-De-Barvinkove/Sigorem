extends Node
class_name ConsoleCommands

# Модуль команд для Panku Console
# Доступ до команд через консоль: Player.teleport(x, y, z) або TerrainGenerator.regenerate_chunk(x, z)

var player: Node3D
var voxel_terrain: Node

# Block types for building
const BLOCK_AIR = 0
const BLOCK_STONE = 1
const BLOCK_DIRT = 2
const BLOCK_GRASS = 3
const BLOCK_ROCK = 4

func _ready():
	# Чекаємо один кадр, щоб сцена встигла завантажитися
	await get_tree().process_frame

	# Знаходимо гравця та VoxelTerrain
	var world = get_tree().get_root().get_node_or_null("VoxelWorld")
	if world:
		player = world.get_node_or_null("Player")
		voxel_terrain = world.get_node_or_null("VoxelTerrain")
	
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

func teleport_to_surface(x: float, z: float) -> String:
	"""Телепортувати гравця на поверхню над позицією (x, z)"""
	if not player or not voxel_terrain:
		return "Помилка: Гравець або VoxelTerrain не знайдено"

	# Raycast down from high altitude to find surface
	var space_state = player.get_world_3d().direct_space_state
	var from = Vector3(x, 200, z)
	var to = Vector3(x, -50, z)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)

	if result:
		player.global_position = result.position + Vector3(0, 2, 0) # 2 units above surface
		return "Гравець телепортовано на поверхню над (" + str(x) + ", " + str(z) + ")"
	return "Помилка: Поверхня не знайдена на цій позиції"

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

func fill_area(x1: int, y1: int, z1: int, x2: int, y2: int, z2: int, block_id: int = BLOCK_STONE) -> String:
	"""Заповнити область блоками (за замовчуванням - камінь)"""
	if not voxel_terrain:
		return "Помилка: VoxelTerrain не знайдено"

	var tool = voxel_terrain.get_voxel_tool()
	if not tool:
		return "Помилка: VoxelTool не доступний"

	tool.channel = VoxelBuffer.CHANNEL_TYPE
	tool.mode = VoxelTool.MODE_SET

	# Ensure coordinates are in correct order
	var min_pos = Vector3i(min(x1, x2), min(y1, y2), min(z1, z2))
	var max_pos = Vector3i(max(x1, x2), max(y1, y2), max(z1, z2))

	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			for z in range(min_pos.z, max_pos.z + 1):
				tool.set_voxel(Vector3i(x, y, z), block_id)

	return "Область заповнено від " + str(min_pos) + " до " + str(max_pos) + " блоком ID=" + str(block_id)

func create_sphere(center_x: int, center_y: int, center_z: int, radius: float, block_id: int = BLOCK_STONE) -> String:
	"""Створити сферу з блоків"""
	if not voxel_terrain:
		return "Помилка: VoxelTerrain не знайдено"

	var tool = voxel_terrain.get_voxel_tool()
	if not tool:
		return "Помилка: VoxelTool не доступний"

	tool.channel = VoxelBuffer.CHANNEL_TYPE
	tool.mode = VoxelTool.MODE_SET

	var center = Vector3(center_x, center_y, center_z)
	var radius_squared = radius * radius

	# Create a bounding box for the sphere
	var min_pos = Vector3i(center - Vector3(radius, radius, radius))
	var max_pos = Vector3i(center + Vector3(radius, radius, radius))

	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			for z in range(min_pos.z, max_pos.z + 1):
				var pos = Vector3(x, y, z)
				var distance_squared = pos.distance_squared_to(center)
				if distance_squared <= radius_squared:
					# Inside sphere - set block
					tool.set_voxel(Vector3i(x, y, z), block_id)

	return "Сферу створено в центрі " + str(center) + " з радіусом " + str(radius)

func get_terrain_info() -> String:
	"""Отримати інформацію про VoxelTerrain"""
	if not voxel_terrain:
		return "Помилка: VoxelTerrain не знайдено"

	var info = "VoxelTerrain інформація:\n"
	info += "Max View Distance: " + str(voxel_terrain.max_view_distance) + "\n"
	info += "Mesh Block Size: " + str(voxel_terrain.mesh_block_size) + "\n"
	info += "Generate Collisions: " + str(voxel_terrain.generate_collisions) + "\n"
	
	if voxel_terrain.generator:
		info += "Generator: " + str(voxel_terrain.generator.resource_name) + "\n"
	if voxel_terrain.mesher:
		info += "Mesher: " + str(voxel_terrain.mesher.get_class()) + "\n"

	return info

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
  Debug.teleport_to_surface(x, z) - телепорт на поверхню над позицією
  Debug.get_player_position() - позиція гравця

  === Рух та камера ===
  Debug.set_speed(multiplier) - встановити швидкість (0.1-10.0)
  Debug.toggle_flight() - перемкнути польотний режим (F)
  Debug.toggle_first_person() - камера від першої особи (V)

  === Креативний режим ===
  Debug.toggle_xray() - X-ray режим для печер (X)
  Debug.set_break_radius(radius) - радіус ламання блоків (1-10)

  === Генерація світу ===
  Debug.fill_area(x1,y1,z1,x2,y2,z2,block_id) - заповнити область блоками (0=air,1=stone,2=dirt,3=grass)
  Debug.create_sphere(x,y,z,radius,block_id) - створити сферу з блоків
  Debug.get_terrain_info() - інформація про VoxelTerrain

  Debug.help() - показати цю довідку"""
