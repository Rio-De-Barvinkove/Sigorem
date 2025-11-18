@tool
extends Node
class_name TerrainGenerator

# Головний менеджер генерації терейну
# Модульна архітектура з можливістю включення/виключення компонентів

@export_group("Основні налаштування")
@export var target_gridmap: GridMap
@export var player: Node3D

@export_group("Модулі генерації")
@export var use_procedural_generation := true
@export var use_chunking := true
@export var use_starting_area := true
@export var use_structures := false
@export var use_lod := false
@export var use_threading := false
@export var use_vegetation := false
@export var use_heightmap := false
@export var use_splat_mapping := false
@export var use_detail_layers := false
@export var use_optimization := false
@export var use_save_load := false
@export var use_native_optimization := false
@export var use_precomputed_patterns := false
@export var use_best_practices := true

@export_group("Параметри процедурної генерації")
@export var noise: FastNoiseLite
@export var chunk_size := Vector2i(50, 50)
@export var chunk_radius := 3
@export var height_amplitude := 32
@export var base_height := 16
@export var min_height := -64   # Мінімальна висота для шарів під землею (оптимізовано)
@export var max_height := 192   # Збільшена максимальна висота (оптимізовано)

@export_group("Параметри печер")
@export var enable_caves := true
@export var cave_density := 0.4
@export var cave_noise_scale := 0.03

@export_group("Параметри chunking")
@export var enable_chunk_culling := true
@export var max_chunk_distance := 100.0
@export var chunk_cull_interval := 0.5  # Мінімальний інтервал між видаленнями чанків (секунди)
@export var max_chunks_removed_per_frame := 3  # Максимум чанків для видалення за кадр

@export_group("Параметри heightmap")
@export var heightmap_scale: float = 5.0
@export var heightmap_size: Vector2 = Vector2(100.0, 100.0)
@export var heightmap_subdivides: int = 50

# Посилання на модулі
var procedural_module
var chunk_module
var starting_area_module
var structure_module
var lod_module
var threading_module
var vegetation_module
var heightmap_module
var splat_module
var detail_module
var optimization_module
var save_load_module
var native_optimizer
var pattern_manager
var best_practices

const PLAYER_LOOKUP_WARNING := "TerrainGenerator: Гравець не знайдений для стартової зони"

var is_initialized := false
var _player_lookup_attempted := false

func _ready():
	if Engine.is_editor_hint():
		return

	# Якщо гравець не встановлений, спробуємо знайти його
	if not player:
		var world = get_tree().get_root().get_node_or_null("World")
		if world:
			player = world.get_node_or_null("Player")

	initialize_modules()
	generate_initial_terrain()

func initialize_modules():
	"""Ініціалізація всіх модулів генерації"""

	# Очищаємо старі модулі перед ініціалізацією нових
	cleanup_modules()

	# Нормалізуємо параметри висоти
	height_amplitude = int(max(height_amplitude, 1))
	base_height = int(max(base_height, 0))
	min_height = int(min(min_height, base_height - 1))  # min_height має бути менше base_height
	max_height = int(max(max_height, base_height + 1))

	# Процедурна генерація (базова)
	if use_procedural_generation:
		procedural_module = ProceduralGeneration.new()
		procedural_module.noise = noise
		procedural_module.height_amplitude = height_amplitude
		procedural_module.base_height = base_height
		procedural_module.min_height = min_height
		procedural_module.max_height = max_height
		# Печери
		procedural_module.enable_caves = enable_caves
		procedural_module.cave_density = cave_density
		procedural_module.cave_noise_scale = cave_noise_scale
		add_child(procedural_module)

	# Chunking система
	if use_chunking:
		chunk_module = ChunkManager.new()
		chunk_module.chunk_size = chunk_size
		chunk_module.chunk_radius = chunk_radius
		chunk_module.enable_culling = enable_chunk_culling
		chunk_module.max_distance = max_chunk_distance
		chunk_module.min_cull_interval = chunk_cull_interval
		chunk_module.max_chunks_to_remove_per_frame = max_chunks_removed_per_frame
		if player:
			chunk_module.player = player
		add_child(chunk_module)

	# Starting Area Generator
	if use_starting_area:
		starting_area_module = StartingAreaGenerator.new()
		starting_area_module.starting_area_height = base_height
		add_child(starting_area_module)

	# Генерація структур (WFC)
	if use_structures:
		structure_module = StructureGenerator.new()
		structure_module.target_gridmap = target_gridmap
		add_child(structure_module)

	# LOD система
	if use_lod:
		lod_module = LODManager.new()
		add_child(lod_module)

	# Threading менеджер
	if use_threading:
		threading_module = ThreadingManager.new()
		add_child(threading_module)

	# Vegetation менеджер
	if use_vegetation:
		vegetation_module = VegetationManager.new()
		add_child(vegetation_module)

	# Heightmap лоадер
	if use_heightmap:
		heightmap_module = HeightmapLoader.new()
		heightmap_module.height_scale = heightmap_scale
		heightmap_module.mesh_size = heightmap_size
		heightmap_module.subdivides = heightmap_subdivides
		add_child(heightmap_module)

	# Splat mapping
	if use_splat_mapping:
		splat_module = SplatMapManager.new()
		add_child(splat_module)

	# Detail layers
	if use_detail_layers:
		detail_module = DetailLayerManager.new()
		add_child(detail_module)

	# Optimization manager (завжди активний, якщо use_optimization = true)
	if use_optimization:
		optimization_module = OptimizationManager.new()
		add_child(optimization_module)

	# Save/Load manager
	if use_save_load:
		save_load_module = SaveLoadManager.new()
		add_child(save_load_module)

	# Native optimizer
	if use_native_optimization:
		native_optimizer = NativeOptimizer.new()
		add_child(native_optimizer)

	# Precomputed patterns
	if use_precomputed_patterns:
		pattern_manager = PrecomputedPatterns.new()
		add_child(pattern_manager)

	# Best practices
	if use_best_practices:
		best_practices = BestPractices.new()
		add_child(best_practices)

	is_initialized = true
	add_to_group("terrain_generator")
	print("TerrainGenerator: Модулі ініціалізовані")

func cleanup_modules():
	"""Очищення всіх модулів перед реініціалізацією"""
	var nodes_to_remove: Array = []
	for child in get_children():
		if child != target_gridmap:
			nodes_to_remove.append(child)

	for child in nodes_to_remove:
		if child == chunk_module and target_gridmap and chunk_module and chunk_module.has_method("clear_all_chunks"):
			chunk_module.clear_all_chunks(target_gridmap)
		if child.get_parent() == self:
			remove_child(child)
		child.call_deferred("free")

	# Очищаємо посилання
	procedural_module = null
	chunk_module = null
	starting_area_module = null
	structure_module = null
	lod_module = null
	threading_module = null
	vegetation_module = null
	heightmap_module = null
	splat_module = null
	detail_module = null
	optimization_module = null
	save_load_module = null
	native_optimizer = null
	pattern_manager = null
	best_practices = null

	print("TerrainGenerator: Модулі очищено")

func generate_initial_terrain():
	"""Генерація початкового терейну"""
	if not is_initialized or not target_gridmap:
		return

	var center_chunk = Vector2i.ZERO

	if use_chunking and chunk_module:
		if chunk_module.has_method("set_player"):
			chunk_module.set_player(player)
		elif player:
			chunk_module.player = player
		# Chunk-based генерація
		chunk_module.generate_initial_chunks(target_gridmap)
	else:
		# Проста генерація всього світу одразу
		if use_procedural_generation and procedural_module:
			procedural_module.generate_terrain(target_gridmap, Vector2i(-chunk_size.x, -chunk_size.y), chunk_size)

	# ВИПРАВЛЕНО: Starting area тепер генерується в ChunkManager._finalize_chunk_job() після завершення генерації чанка (0, 0)
	# Це гарантує що стартова зона генерується після повної генерації чанка
	if use_chunking:
		print("TerrainGenerator: Starting area буде згенерована після завершення генерації чанка (0, 0)")
	else:
		# Для не-chunking режиму генеруємо одразу
		if use_starting_area and starting_area_module:
			starting_area_module.generate_starting_area(target_gridmap, center_chunk, chunk_size)
			print("TerrainGenerator: Starting area згенеровано")

	print("TerrainGenerator: Початкова генерація завершена")

	# Встановлюємо безпечну позицію гравця (використовуємо call_deferred для встановлення після оновлення GridMap)
	if player and use_starting_area and starting_area_module:
		if starting_area_module.always_spawn_on_starting_area:
			call_deferred("_set_player_safe_position")

	# Позначаємо, що початкова генерація завершена
	if optimization_module:
		optimization_module.set_initial_generation_complete()

func _set_player_safe_position():
	"""Встановити безпечну позицію гравця на стартовій зоні"""
	if not player and not _player_lookup_attempted:
		_player_lookup_attempted = true
		var world = get_tree().get_root().get_node_or_null("World")
		if world:
			player = world.get_node_or_null("Player")
	
	if not use_starting_area or not starting_area_module or not target_gridmap:
		return
	
	if not player:
		push_warning(PLAYER_LOOKUP_WARNING)
		return
	
	if not starting_area_module.always_spawn_on_starting_area:
		return
	
	var safe_pos = starting_area_module.find_safe_spawn_with_collision_check(target_gridmap, chunk_size)
	if player and is_instance_valid(player):
		player.global_position = safe_pos
		print("TerrainGenerator: Гравець встановлено на безпечну позицію: ", safe_pos)

func teleport_player_to_starting_area():
	"""Телепортувати гравця на стартову зону (використовується при регенерації)"""
	if player and use_starting_area and starting_area_module:
		if starting_area_module.always_spawn_on_starting_area:
			_set_player_safe_position()

func _process(delta):
	if not is_initialized or Engine.is_editor_hint():
		return

	# ВИПРАВЛЕНО: ChunkManager тепер сам обробляє оновлення в своєму _process()
	# Не потрібно викликати update_chunks() - вона видалена, логіка перенесена в _process() ChunkManager

func generate_structures():
	"""Генерація структур на існуючому терейні"""
	if use_structures and structure_module:
		structure_module.generate_structures(target_gridmap)

func regenerate_terrain():
	"""Повна регенерація терейну"""
	if target_gridmap:
		if use_chunking and chunk_module:
			chunk_module.clear_all_chunks(target_gridmap)
		target_gridmap.clear()
		generate_initial_terrain()
		# Телепортуємо гравця на стартову зону після регенерації
		teleport_player_to_starting_area()

func get_chunk_size() -> Vector2i:
	return chunk_size

func get_max_height() -> int:
	return max_height

func get_min_height() -> int:
	return min_height

# Editor tools (використовувати через консоль або скрипти)
func generate_terrain_editor():
	"""Генерація терейну в редакторі"""
	if not target_gridmap:
		push_error("TerrainGenerator: GridMap не встановлений!")
		return
	regenerate_terrain()

func generate_structures_editor():
	"""Генерація структур в редакторі"""
	generate_structures()

func show_performance_report():
	"""Показати звіт продуктивності"""
	if optimization_module:
		print(optimization_module.get_performance_report())
	else:
		print("Оптимізація вимкнена")

func save_world():
	"""Зберегти світ"""
	if save_load_module:
		save_load_module.save_world_metadata()
		save_load_module.auto_save()
		print("Світ збережено!")
	else:
		print("Save/Load модуль вимкнено")

func load_world():
	"""Завантажити світ"""
	if save_load_module:
		var metadata = save_load_module.load_world_metadata()
		if metadata.size() > 0:
			# Відновлюємо налаштування
			if metadata.has("world_seed") and noise:
				noise.seed = metadata["world_seed"]
			print("Світ завантажено!")
		else:
			print("Немає збережених даних світу")
	else:
		print("Save/Load модуль вимкнено")

func show_best_practices():
	"""Показати best practices"""
	if best_practices:
		var practices = best_practices.get_generation_best_practices()
		print("=== BEST PRACTICES ===")
		for key in practices.keys():
			print(key, ": ", practices[key])
	else:
		print("Best practices модуль вимкнено")

func export_performance_report():
	"""Експортувати звіт продуктивності"""
	if best_practices:
		var report_path = "user://performance_report.md"
		best_practices.save_performance_report(report_path)
		print("Звіт експортовано в ", report_path)
	else:
		print("Best practices модуль вимкнено")
