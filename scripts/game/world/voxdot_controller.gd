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

const CHUNK_SIZE: int = 62  ## Внутрішній розмір чанка (з mesher.h)

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
	print("VoxdotController: Depth settings updated")


func _on_y_sort_updated(mesh_count: int) -> void:
	## Обробник оновлення Y-sort
	print("VoxdotController: Y-sort updated for ", mesh_count, " meshes")


func _on_performance_optimized(optimization_type: String) -> void:
	## Обробник оптимізації продуктивності
	print("VoxdotController: Performance optimized: ", optimization_type)


func _initialize_managers() -> void:
	## Відкладена ініціалізація всіх менеджерів

	# Увімкнути обробку input для цього нода
	set_process_input(true)

	# Ініціалізація менеджера збереження чанків
	_chunk_save_manager = ChunkSaveManager.new()
	add_child(_chunk_save_manager)
	_chunk_save_manager.initialize(randi(), "default_world", voxel_scale)

	# Автоматичне завантаження всіх збережених модифікацій після ініціалізації terrain
	_load_all_modifications()

	# Ініціалізація менеджера глибини
	_depth_manager = TerrainDepthManager.new()
	add_child(_depth_manager)
	_depth_manager.initialize(terrain, player, view_distance, voxel_scale)

	# Підключення сигналів від менеджерів
	_depth_manager.depth_settings_changed.connect(_on_depth_settings_changed)
	_depth_manager.y_sort_updated.connect(_on_y_sort_updated)
	_depth_manager.performance_optimized.connect(_on_performance_optimized)

	# Ініціалізація воксельної системи
	# API: init_terrain_system(initial_voxel_scale, noise_seed, pool_size)
	terrain.init_terrain_system(voxel_scale, randi(), 500)
	
	# Спробуємо створити біом
	var biome = ClassDB.instantiate("Biome")
	if biome:
		print("VoxdotController: Biome class available")
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
			print("VoxdotController: Biome assigned")
	else:
		push_warning("VoxdotController: Biome class NOT available, using manual generation")
	
	# Noise для процедурної генерації чанків (якщо біоми не спрацюють)
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.seed = randi()
	_noise.frequency = terrain_frequency
	_noise.fractal_octaves = 3

	# Безпечний спавн до масового завантаження чанків
	_safe_spawn = SafeSpawn.new()
	_safe_spawn.ensure_safe_spawn(terrain, player, _noise, terrain_height, terrain_amplitude, voxel_scale, material_ground)
	
	# Завантажити початкові чанки навколо гравця
	_update_chunks_around_player()

	# Дослідження після генерації чанків
	print("VoxdotController: VoxdotTerrain дочірні ноди після генерації чанків:")
	for child in terrain.get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
		if child is MeshInstance3D:
			print("    MeshInstance3D: visible=", child.visible)
			if child.mesh and child.mesh is ArrayMesh:
				var array_mesh = child.mesh as ArrayMesh
				var vertex_count = 0
				for surface_idx in array_mesh.get_surface_count():
					var arrays = array_mesh.surface_get_arrays(surface_idx)
					if arrays[Mesh.ARRAY_VERTEX]:
						vertex_count += arrays[Mesh.ARRAY_VERTEX].size()
				print("      mesh vertices=", vertex_count)

	print("VoxdotController: Ініціалізовано. voxel_scale=", voxel_scale, ", view_distance=", view_distance)


func _input(event: InputEvent) -> void:
	# Debug: check if input is being received
	if event is InputEventKey and event.pressed:
		print("VoxdotController: Key pressed: ", event.keycode, " key_label: ", event.key_label)
		if event.keycode == KEY_8 or event.keycode == KEY_9:
			print("VoxdotController: Save/Load key detected! Keycode: ", event.keycode)

	if event is InputEventKey and event.pressed:
		# Use number keys instead of F-keys for easier testing
		if event.keycode == KEY_8:  # 8 key for save
			if _chunk_save_manager:
				print("VoxdotController: Force saving all chunks (8 pressed)")
				_chunk_save_manager.force_save_all()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_9:  # 9 key for load
			if _chunk_save_manager:
				print("VoxdotController: Force loading all chunks (9 pressed)")
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

	# Обробити dirty chunks
	var t0 := Time.get_ticks_usec()
	terrain.process_dirty_chunks(chunks_per_frame, true)
	var dt = Time.get_ticks_usec() - t0

	if dt > 0:  # Якщо був витрачений час на обробку
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

		# Логування в PerformanceLogger тільки якщо було виконано значну роботу
		if dt > 10000:  # тільки якщо час > 10ms (було оброблено багато чанків)
			PerformanceLogger.log_chunk_generation_time(dt)  # загальний час на кадр
			PerformanceLogger.log_custom_metric("chunk_processing_time", dt / 1000.0, "ms")
			print("Processed dirty chunks in ", dt / 1000.0, "ms")


func _world_to_chunk(world_pos: Vector3) -> Vector3:
	## Конвертувати світові координати в координати чанка
	var chunk_world_size = CHUNK_SIZE * voxel_scale
	return Vector3(
		floor(world_pos.x / chunk_world_size),
		floor(world_pos.y / chunk_world_size),
		floor(world_pos.z / chunk_world_size)
	)


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
	print("VoxdotController: Loading ", chunks_to_load.size(), " new chunks")
	for chunk_coords in chunks_to_load:
		var t_add := Time.get_ticks_usec()
		terrain.add_chunk(chunk_coords, false)  # API: add_chunk(coords, empty) - false = generate terrain
		if _perf_logger:
			_perf_logger.log_add_time(t_add)
		loaded_chunks[chunk_coords] = true

		# Застосувати збережені модифікації після генерації
		if _chunk_save_manager:
			print("VoxdotController: Applying saved modifications for chunk ", chunk_coords)
			_chunk_save_manager.apply_modifications_to_chunk(terrain, chunk_coords)
			# Immediately process any dirty chunks after applying modifications
			terrain.process_dirty_chunks(chunks_per_frame, true)
	
	# Вивантажити зайві чанки
	print("VoxdotController: Unloading ", chunks_to_unload.size(), " chunks (total loaded: ", loaded_chunks.size(), ")")
	for chunk_coords in chunks_to_unload:
		print("VoxdotController: Unloading chunk ", chunk_coords)

		# Зберегти модифікації перед вивантаженням
		if _chunk_save_manager:
			var has_mods = _chunk_save_manager.loaded_chunks.has(chunk_coords) and not _chunk_save_manager.loaded_chunks[chunk_coords].modifications.is_empty()
			print("VoxdotController: Chunk ", chunk_coords, " has modifications: ", has_mods)
			_chunk_save_manager.save_chunk_modifications(chunk_coords)
			_chunk_save_manager.unload_chunk(chunk_coords)

		terrain.remove_chunk(chunk_coords)
		loaded_chunks.erase(chunk_coords)
	
		if chunks_to_load.size() > 0 or chunks_to_unload.size() > 0:
			print("Chunks: loaded=", chunks_to_load.size(), ", unloaded=", chunks_to_unload.size(), ", total=", loaded_chunks.size())

			# Логування в PerformanceLogger
			PerformanceLogger.log_active_chunks(loaded_chunks.size())

		# Перевірка швів між чанками після генерації
		if _depth_manager:
			_depth_manager.check_chunk_seams(loaded_chunks)


func place_voxel(world_pos: Vector3, material: int = 1) -> void:
	## Поставити воксель (куб 1x1x1)
	terrain.place_edit(Vector3(voxel_scale, voxel_scale, voxel_scale), world_pos, material, 1)

	# Зберегти модифікацію для персистентності
	if _chunk_save_manager:
		print("VoxdotController: Adding voxel modification at ", world_pos, " material=", material)
		_chunk_save_manager.add_voxel_modification(world_pos, material)
		var chunk_coords = _world_to_chunk(world_pos)
		_chunk_save_manager.mark_chunk_dirty(chunk_coords)
		print("VoxdotController: Marked chunk ", chunk_coords, " as dirty")


func remove_voxel(world_pos: Vector3, radius: float = 0.3) -> void:
	## Видалити воксель (сфера)
	terrain.place_edit(Vector3(radius, radius, radius), world_pos, 0, 0)

	# Зберегти модифікацію для персистентності (матеріал 0 = повітря)
	if _chunk_save_manager:
		print("VoxdotController: Removing voxel at ", world_pos)
		_chunk_save_manager.add_voxel_modification(world_pos, 0)
		var chunk_coords = _world_to_chunk(world_pos)
		_chunk_save_manager.mark_chunk_dirty(chunk_coords)
		print("VoxdotController: Marked chunk ", chunk_coords, " as dirty")


func place_sphere(world_pos: Vector3, radius: float, material: int = 1) -> void:
	## Поставити сферу
	terrain.place_edit(Vector3(radius, radius, radius), world_pos, material, 0)

	# Зберегти модифікацію для персистентності
	if _chunk_save_manager:
		print("VoxdotController: Adding sphere modification at ", world_pos, " radius=", radius, " material=", material)
		_chunk_save_manager.add_voxel_modification(world_pos, material)
		var chunk_coords = _world_to_chunk(world_pos)
		_chunk_save_manager.mark_chunk_dirty(chunk_coords)
		print("VoxdotController: Marked chunk ", chunk_coords, " as dirty")


func place_cube(world_pos: Vector3, size: Vector3, material: int = 1) -> void:
	## Поставити куб
	terrain.place_edit(size, world_pos, material, 1)

	# Зберегти модифікацію для персистентності
	if _chunk_save_manager:
		print("VoxdotController: Adding cube modification at ", world_pos, " size=", size, " material=", material)
		_chunk_save_manager.add_voxel_modification(world_pos, material)
		var chunk_coords = _world_to_chunk(world_pos)
		_chunk_save_manager.mark_chunk_dirty(chunk_coords)
		print("VoxdotController: Marked chunk ", chunk_coords, " as dirty")


func place_vox_model(world_pos: Vector3, vox_path: String, material: int = 0) -> void:
	## Поставити .vox модель (MagicaVoxel)
	terrain.place_vox_edit(vox_path, world_pos, material)

## Завантажити всі збережені модифікації чанків
func _load_all_modifications() -> void:
	if not _chunk_save_manager:
		return

	print("VoxdotController: Loading all saved chunk modifications...")

	# Отримати список всіх збережених файлів чанків
	var save_dir = DirAccess.open(_chunk_save_manager.save_directory)
	if not save_dir:
		print("VoxdotController: No save directory found, starting fresh")
		return

	var chunk_files = []
	save_dir.list_dir_begin()
	var current_file = save_dir.get_next()
	while current_file != "":
		if current_file.ends_with(".json") and current_file.begins_with("chunk_"):
			chunk_files.append(current_file)
		current_file = save_dir.get_next()
	save_dir.list_dir_end()

	print("VoxdotController: Found ", chunk_files.size(), " saved chunk files")

	# Завантажити модифікації для кожного файлу
	for file_name in chunk_files:
		var parts = file_name.trim_suffix(".json").split("_")
		if parts.size() == 4 and parts[0] == "chunk":
			var chunk_coords = Vector3(int(parts[1]), int(parts[2]), int(parts[3]))
			_chunk_save_manager.load_chunk_modifications(chunk_coords)
			print("VoxdotController: Loaded modifications for chunk ", chunk_coords)

	print("VoxdotController: Finished loading all chunk modifications")
}

## Застосувати завантажені модифікації до всіх поточних чанків
func _apply_loaded_modifications_to_current_chunks() -> void:
	if not _chunk_save_manager or not terrain:
		return

	print("VoxdotController: Applying loaded modifications to current chunks...")

	for chunk_coords in loaded_chunks.keys():
		if _chunk_save_manager.loaded_chunks.has(chunk_coords):
			print("VoxdotController: Re-applying modifications for current chunk ", chunk_coords)
			_chunk_save_manager.apply_modifications_to_chunk(terrain, chunk_coords)
			# Immediately process any dirty chunks after applying modifications
			terrain.process_dirty_chunks(chunks_per_frame, true)

	print("VoxdotController: Finished re-applying modifications to current chunks")
