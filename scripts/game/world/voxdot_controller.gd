extends Node3D
class_name VoxdotController
## Контролер для VoxdotTerrain - керує чанками навколо гравця
## Використовує TerrainDepthManager для керування глибиною та Y-sort

@export_node_path("VoxdotTerrain") var terrain_path: NodePath
@export_node_path("Node3D") var player_path: NodePath
@export var view_distance: int = 4  ## Радіус в чанках
@export var chunks_per_frame: int = 2  ## Скільки чанків обробляти за кадр
@export var voxel_scale: float = 0.1  ## Розмір вокселя в метрах
@export var terrain_radius_chunks: int = 4 ## Радіус процедурної генерації в чанках
@export var terrain_height: float = 12.0 ## Базова висота
@export var terrain_amplitude: float = 18.0 ## Амплітуда шуму
@export var terrain_frequency: float = 0.045 ## Частота шуму
@export var material_ground: int = 2 ## Індекс матеріалу для грунту/трави
@export_node_path("PerfLogger") var perf_logger_path: NodePath
@export_node_path("PerformanceLogger") var performance_logger_path: NodePath

var _noise: FastNoiseLite
var _chunk_save_manager: ChunkSaveManager

var terrain: VoxdotTerrain
var player: Node3D
var loaded_chunks: Dictionary = {}  ## Vector3 -> bool
var _last_player_chunk: Vector3 = Vector3.INF
var _safe_spawn: SafeSpawn
var _perf_logger: PerfLogger
var _performance_logger: PerformanceLogger
var _depth_manager: TerrainDepthManager


func _ready() -> void:
	# Отримати ноди з NodePath
	if terrain_path:
		terrain = get_node_or_null(terrain_path)
	if player_path:
		player = get_node_or_null(player_path)
	if perf_logger_path:
		_perf_logger = get_node_or_null(perf_logger_path)

	if performance_logger_path:
		_performance_logger = get_node_or_null(performance_logger_path)
	
	if not terrain:
		push_error("VoxdotController: terrain не призначено!")
		return
	
	if not player:
		push_error("VoxdotController: player не призначено!")
		return

	# Створення та ініціалізація менеджерів (відкладено для надійності)
	call_deferred("_initialize_managers")


func _on_depth_settings_changed() -> void:
	## Обробник зміни налаштувань глибини
	pass  # Видалити надмірне логування


func _on_y_sort_updated(mesh_count: int) -> void:
	## Обробник оновлення Y-sort
	pass  # Видалити надмірне логування


func _on_performance_optimized(optimization_type: String) -> void:
	## Обробник оптимізації продуктивності
	pass  # Видалити надмірне логування


func _initialize_managers() -> void:
	## Відкладена ініціалізація всіх менеджерів
	
	if not terrain or not player:
		push_error("VoxdotController: Cannot initialize - terrain or player is null")
		return

	# Увімкнути обробку input для цього нода
	set_process_input(true)

	# Ініціалізація менеджера збереження чанків
	_chunk_save_manager = ChunkSaveManager.new()
	if not _chunk_save_manager:
		push_error("VoxdotController: Failed to create ChunkSaveManager")
		return
	add_child(_chunk_save_manager)
	# Генерація унікальної назви світу на основі seed для нового світу без старих модифікацій
	var world_seed = randi()
	var world_name = "world_" + str(world_seed)
	_chunk_save_manager.initialize(world_seed, world_name, voxel_scale)

	# Автоматичне завантаження всіх збережених модифікацій після ініціалізації terrain
	_load_all_modifications()

	# Ініціалізація менеджера глибини
	_depth_manager = TerrainDepthManager.new()
	if not _depth_manager:
		push_error("VoxdotController: Failed to create TerrainDepthManager")
		return
	add_child(_depth_manager)
	_depth_manager.initialize(terrain, player, view_distance, voxel_scale)

	# Підключення сигналів від менеджерів
	if _depth_manager.has_signal("depth_settings_changed"):
		_depth_manager.depth_settings_changed.connect(_on_depth_settings_changed)
	if _depth_manager.has_signal("y_sort_updated"):
		_depth_manager.y_sort_updated.connect(_on_y_sort_updated)
	if _depth_manager.has_signal("performance_optimized"):
		_depth_manager.performance_optimized.connect(_on_performance_optimized)

	# Ініціалізація воксельної системи
	# API: init_terrain_system(initial_voxel_scale, noise_seed, pool_size)
	if terrain.has_method("init_terrain_system"):
		terrain.init_terrain_system(voxel_scale, randi(), TerrainConstants.DEFAULT_POOL_SIZE)
	else:
		push_error("VoxdotController: terrain doesn't have init_terrain_system method")
		return
	
	# Спробуємо створити біом
	var biome = ClassDB.instantiate("Biome")
	if biome:
		var layer = ClassDB.instantiate("TerrainLayer")
		if layer:
			layer.set("noise_base", terrain_height)
			layer.set("noise_max", terrain_amplitude)
			layer.set("material_type", material_ground)
			# Створимо і налаштуємо noise для шару
			var layer_noise = FastNoiseLite.new()
			layer_noise.noise_type = FastNoiseLite.TYPE_PERLIN
			layer_noise.frequency = terrain_frequency
			layer.set("noise", layer_noise)
			
			biome.set("terrain_layers", [layer])
			terrain.set("biomes", [biome])
	
	# Noise для процедурної генерації чанків (якщо біоми не спрацюють)
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.seed = randi()
	_noise.frequency = terrain_frequency
	_noise.fractal_octaves = 3

	# Безпечний спавн до масового завантаження чанків
	_safe_spawn = SafeSpawn.new()
	if _safe_spawn and _safe_spawn.has_method("ensure_safe_spawn"):
		_safe_spawn.ensure_safe_spawn(terrain, player, _noise, terrain_height, terrain_amplitude, voxel_scale, material_ground)
	else:
		push_warning("VoxdotController: SafeSpawn not available or missing method")
	
	# Завантажити початкові чанки навколо гравця
	_update_chunks_around_player()

	# Debug логування тільки в debug mode
	if OS.is_debug_build():
		print("VoxdotController: Ініціалізовано. voxel_scale=", voxel_scale, ", view_distance=", view_distance)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Use number keys instead of F-keys for easier testing
		if event.keycode == KEY_8:  # 8 key for save
			if _chunk_save_manager:
				_chunk_save_manager.force_save_all()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_9:  # 9 key for load
			if _chunk_save_manager:
				_load_all_modifications()
				# Застосувати завантажені модифікації до всіх поточних чанків
				_apply_loaded_modifications_to_current_chunks()
				get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not terrain or not player:
		return

	# Перевірити чи гравець змінив чанк
	var current_chunk = _world_to_chunk(player.global_position)
	if current_chunk != _last_player_chunk:
		_last_player_chunk = current_chunk
		_update_chunks_around_player()

	# Обробка глибини та Y-sort через менеджер
	if _depth_manager:
		_depth_manager.process_delta(_delta)

	# Обробити dirty chunks (обмежена кількість за кадр для продуктивності)
	var t0 := Time.get_ticks_usec()
	if terrain.has_method("process_dirty_chunks"):
		terrain.process_dirty_chunks(chunks_per_frame, false)  # false = не форсувати, обробити тільки якщо є dirty
	var dt = Time.get_ticks_usec() - t0

	# Логування тільки якщо була значна робота (зменшити частоту логування)
	if dt > 10000:  # тільки якщо час > 10ms
		if _perf_logger:
			_perf_logger.log_mesh_time(t0)
			_perf_logger.request_report()

		# Логування кількості активних чанків
		var active_chunks = 0
		if terrain.has_method("get_active_chunk_count"):
			active_chunks = terrain.get_active_chunk_count()
		else:
			# Спробуємо отримати через властивість active_chunks
			var chunks_prop = terrain.get("active_chunks")
			if chunks_prop is Array:
				active_chunks = chunks_prop.size()
		PerformanceLogger.log_active_chunks(active_chunks)
		PerformanceLogger.log_chunk_generation_time(dt)
		PerformanceLogger.log_custom_metric("chunk_processing_time", dt / 1000.0, "ms")


func _world_to_chunk(world_pos: Vector3) -> Vector3:
	## Конвертувати світові координати в координати чанка
	return TerrainConstants.world_to_chunk(world_pos, voxel_scale)


func _update_chunks_around_player() -> void:
	## Оновити завантажені чанки навколо гравця
	if not player:
		return
	
	var player_chunk = _world_to_chunk(player.global_position)
	var chunks_to_load: Array[Vector3] = []
	var chunks_to_unload: Array[Vector3] = []
	
	# Визначити потрібні чанки
	var needed_chunks: Dictionary = {}
	for x in range(-view_distance, view_distance + 1):
		for y in range(-2, 4):  # Обмежити по вертикалі
			for z in range(-view_distance, view_distance + 1):
				# Перевірити чи чанк в радіусі (XZ)
				var dist_sq = x * x + z * z
				if dist_sq > view_distance * view_distance:
					continue
				
				var chunk_coords = player_chunk + Vector3(x, y, z)
				needed_chunks[chunk_coords] = true
	
	# Знайти чанки для завантаження (без перевірки is_chunk_partially_filled)
	for chunk_coords in needed_chunks.keys():
		if not loaded_chunks.has(chunk_coords):
			chunks_to_load.append(chunk_coords)

	# Знайти чанки для вивантаження (поза зоною видимості + буфер)
	var unload_distance_sq = (view_distance + 2) * (view_distance + 2)  # Збільшений буфер
	for chunk_coords in loaded_chunks.keys():
		var delta = chunk_coords - player_chunk
		var dist_sq = delta.x * delta.x + delta.z * delta.z  # Тільки XZ відстань
		if dist_sq > unload_distance_sq:
			chunks_to_unload.append(chunk_coords)
	
	# Завантажити нові чанки
	var chunks_need_processing = false
	for chunk_coords in chunks_to_load:
		var t_add := Time.get_ticks_usec()
		if terrain.has_method("add_chunk"):
			terrain.add_chunk(chunk_coords, false)  # API: add_chunk(coords, empty) - false = generate terrain
		else:
			push_error("VoxdotController: terrain doesn't have add_chunk method")
			continue
		if _perf_logger:
			_perf_logger.log_add_time(t_add)
		loaded_chunks[chunk_coords] = true

		# Застосувати збережені модифікації після генерації
		if _chunk_save_manager:
			# Переконатися що модифікації завантажені в пам'ять
			_chunk_save_manager.load_chunk_modifications(chunk_coords)
			_chunk_save_manager.apply_modifications_to_chunk(terrain, chunk_coords)
			chunks_need_processing = true
	
	# Обробити dirty chunks один раз після всього циклу завантаження
	if chunks_need_processing and terrain.has_method("process_dirty_chunks"):
		terrain.process_dirty_chunks(chunks_per_frame, true)
	
	# Вивантажити зайві чанки
	for chunk_coords in chunks_to_unload:
		# Зберегти модифікації перед вивантаженням
		if _chunk_save_manager:
			# Зберегти модифікації перед вивантаженням
			_chunk_save_manager.save_chunk_modifications(chunk_coords)
			_chunk_save_manager.unload_chunk(chunk_coords)

		if terrain.has_method("remove_chunk"):
			terrain.remove_chunk(chunk_coords)
		else:
			push_error("VoxdotController: terrain doesn't have remove_chunk method")
		loaded_chunks.erase(chunk_coords)
	
	# Логування в PerformanceLogger - прибрати дублювання
	if chunks_to_load.size() > 0 or chunks_to_unload.size() > 0:
		PerformanceLogger.log_active_chunks(loaded_chunks.size())

		# Перевірка швів між чанками після генерації
		if _depth_manager:
			_depth_manager.check_chunk_seams(loaded_chunks)


func place_voxel(world_pos: Vector3, material: int = 2) -> void:
	## Поставити точно один воксель (куб 1x1x1)
	## place_edit очікує halfExtents як перший параметр для куба (shape=1)
	## Для одного вокселя: повний розмір = voxel_scale, halfExtents = voxel_scale * 0.5
	if not terrain or not terrain.has_method("place_edit"):
		push_error("VoxdotController: terrain or place_edit method not available")
		return
	var half_size = Vector3(voxel_scale * 0.5, voxel_scale * 0.5, voxel_scale * 0.5)
	terrain.place_edit(half_size, world_pos, material, 1)

	# Зберегти SDF-операцію (cube) для персистентності
	# КРИТИЧНО: зберігаємо операцію (cube з size), а не точку
	if _chunk_save_manager:
		var full_size = Vector3(voxel_scale, voxel_scale, voxel_scale)
		_chunk_save_manager.add_modification_operation("cube", world_pos, full_size, material)
		var chunk_coords = _world_to_chunk(world_pos)
		_chunk_save_manager.mark_chunk_dirty(chunk_coords)


func remove_voxel(world_pos: Vector3) -> void:
	## Видалити точно один воксель (куб 1x1x1)
	## place_edit очікує halfExtents як перший параметр для куба (shape=1)
	## Для одного вокселя: повний розмір = voxel_scale, halfExtents = voxel_scale * 0.5
	if not terrain or not terrain.has_method("place_edit"):
		push_error("VoxdotController: terrain or place_edit method not available")
		return
	var half_size = Vector3(voxel_scale * 0.5, voxel_scale * 0.5, voxel_scale * 0.5)
	terrain.place_edit(half_size, world_pos, 0, 1)  # shape=1 (cube), material=0 (повітря)
	
	# Зберегти SDF-операцію (cube) для персистентності (матеріал 0 = повітря)
	# КРИТИЧНО: зберігаємо операцію (cube з size), а не точку
	if _chunk_save_manager:
		var full_size = Vector3(voxel_scale, voxel_scale, voxel_scale)
		_chunk_save_manager.add_modification_operation("cube", world_pos, full_size, 0)
		var chunk_coords = _world_to_chunk(world_pos)
		_chunk_save_manager.mark_chunk_dirty(chunk_coords)


func place_sphere(world_pos: Vector3, radius: float, material: int = 1) -> void:
	## Поставити сферу
	terrain.place_edit(Vector3(radius, radius, radius), world_pos, material, 0)

	# Зберегти операцію для персистентності
	if _chunk_save_manager:
		_chunk_save_manager.add_modification_operation("sphere", world_pos, Vector3(radius, radius, radius), material)
		var chunk_coords = _world_to_chunk(world_pos)
		_chunk_save_manager.mark_chunk_dirty(chunk_coords)


func place_cube(world_pos: Vector3, size: Vector3, material: int = 1) -> void:
	## Поставити куб
	## place_edit очікує half_size як перший параметр
	var half_size = size * 0.5
	terrain.place_edit(half_size, world_pos, material, 1)

	# Зберегти операцію для персистентності
	if _chunk_save_manager:
		_chunk_save_manager.add_modification_operation("cube", world_pos, size, material)
		var chunk_coords = _world_to_chunk(world_pos)
		_chunk_save_manager.mark_chunk_dirty(chunk_coords)


func place_vox_model(world_pos: Vector3, vox_path: String, material: int = 0) -> void:
	## Поставити .vox модель (MagicaVoxel)
	terrain.place_vox_edit(vox_path, world_pos, material)

## Завантажити всі збережені модифікації чанків
func _load_all_modifications() -> void:
	if not _chunk_save_manager:
		return

	# Отримати список всіх збережених файлів чанків
	var save_dir = DirAccess.open(_chunk_save_manager.save_directory)
	if not save_dir:
		return

	var chunk_files = []
	save_dir.list_dir_begin()
	var current_file = save_dir.get_next()
	while current_file != "":
		if current_file.ends_with(".json") and current_file.begins_with("chunk_"):
			chunk_files.append(current_file)
		current_file = save_dir.get_next()
	save_dir.list_dir_end()

	# Видалити надмірне логування

	# Завантажити модифікації для кожного файлу
	for file_name in chunk_files:
		var parts = file_name.trim_suffix(".json").split("_")
		if parts.size() == 4 and parts[0] == "chunk":
			var chunk_coords = Vector3(int(parts[1]), int(parts[2]), int(parts[3]))
			_chunk_save_manager.load_chunk_modifications(chunk_coords)

## Застосувати завантажені модифікації до всіх поточних чанків
func _apply_loaded_modifications_to_current_chunks() -> void:
	if not _chunk_save_manager or not terrain:
		return

	# Застосувати модифікації до всіх чанків
	var has_modifications = false
	for chunk_coords in loaded_chunks.keys():
		if _chunk_save_manager.loaded_chunks.has(chunk_coords):
			_chunk_save_manager.apply_modifications_to_chunk(terrain, chunk_coords)
			has_modifications = true
	
	# Обробити dirty chunks один раз після всіх модифікацій
	if has_modifications and terrain.has_method("process_dirty_chunks"):
		terrain.process_dirty_chunks(chunks_per_frame, true)
