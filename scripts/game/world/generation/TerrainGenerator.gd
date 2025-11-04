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
@export var use_structures := false
@export var use_lod := false
@export var use_threading := false
@export var use_vegetation := false
@export var use_heightmap := false
@export var use_splat_mapping := false
@export var use_detail_layers := false
@export var use_optimization := true
@export var use_save_load := false
@export var use_native_optimization := false
@export var use_precomputed_patterns := false
@export var use_best_practices := true

@export_group("Параметри процедурної генерації")
@export var noise: FastNoiseLite
@export var chunk_size := Vector2i(50, 50)
@export var chunk_radius := 5
@export var height_amplitude := 5
@export var base_height := 5

@export_group("Параметри chunking")
@export var enable_chunk_culling := true
@export var max_chunk_distance := 100.0

# Посилання на модулі
var procedural_module: ProceduralGeneration
var chunk_module: ChunkManager
var structure_module: StructureGenerator
var lod_module: LODManager
var threading_module: ThreadingManager
var vegetation_module: VegetationManager
var heightmap_module: HeightmapLoader
var splat_module: SplatMapManager
var detail_module: DetailLayerManager
var optimization_module: OptimizationManager
var save_load_module: SaveLoadManager
var native_optimizer: NativeOptimizer
var pattern_manager: PrecomputedPatterns
var best_practices: BestPractices

var is_initialized := false

func _ready():
	if Engine.is_editor_hint():
		return

	initialize_modules()
	generate_initial_terrain()

func initialize_modules():
	"""Ініціалізація всіх модулів генерації"""

	# Процедурна генерація (базова)
	if use_procedural_generation:
		procedural_module = ProceduralGeneration.new()
		procedural_module.noise = noise
		procedural_module.height_amplitude = height_amplitude
		procedural_module.base_height = base_height
		add_child(procedural_module)

	# Chunking система
	if use_chunking:
		chunk_module = ChunkManager.new()
		chunk_module.chunk_size = chunk_size
		chunk_module.chunk_radius = chunk_radius
		chunk_module.enable_culling = enable_chunk_culling
		chunk_module.max_distance = max_chunk_distance
		if player:
			chunk_module.player = player
		add_child(chunk_module)

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
	print("TerrainGenerator: Модулі ініціалізовані")

func generate_initial_terrain():
	"""Генерація початкового терейну"""
	if not is_initialized or not target_gridmap:
		return

	if use_chunking and chunk_module:
		# Chunk-based генерація
		chunk_module.generate_initial_chunks(target_gridmap)
	else:
		# Проста генерація всього світу одразу
		if use_procedural_generation and procedural_module:
			procedural_module.generate_terrain(target_gridmap, Vector2i(-chunk_size.x, -chunk_size.y), chunk_size)

	print("TerrainGenerator: Початкова генерація завершена")

func _process(delta):
	if not is_initialized or Engine.is_editor_hint():
		return

	# Оновлення chunking системи
	if use_chunking and chunk_module and player:
		chunk_module.update_chunks(target_gridmap)

func generate_structures():
	"""Генерація структур на існуючому терейні"""
	if use_structures and structure_module:
		structure_module.generate_structures(target_gridmap)

func regenerate_terrain():
	"""Повна регенерація терейну"""
	if target_gridmap:
		target_gridmap.clear()
		generate_initial_terrain()

# Editor tools
@export_tool_button("Генерувати терейн", "WorldEnvironment")
func _generate_terrain_editor():
	if not target_gridmap:
		push_error("TerrainGenerator: GridMap не встановлений!")
		return

	regenerate_terrain()

@export_tool_button("Генерувати структури", "Node3D")
func _generate_structures_editor():
	generate_structures()

@export_tool_button("Показати звіт продуктивності", "Info")
func _show_performance_report():
	if optimization_module:
		print(optimization_module.get_performance_report())
	else:
		print("Оптимізація вимкнена")

@export_tool_button("Зберегти світ", "Save")
func _save_world():
	if save_load_module:
		save_load_module.save_world_metadata()
		save_load_module.auto_save()
		print("Світ збережено!")
	else:
		print("Save/Load модуль вимкнено")

@export_tool_button("Завантажити світ", "Load")
func _load_world():
	if save_load_module:
		var metadata = save_load_module.load_world_metadata()
		if metadata.size() > 0:
			# Відновлюємо налаштування
			if metadata.has("world_seed"):
				noise.seed = metadata["world_seed"]
			print("Світ завантажено!")
		else:
			print("Немає збережених даних світу")
	else:
		print("Save/Load модуль вимкнено")

@export_tool_button("Показати best practices", "Help")
func _show_best_practices():
	if best_practices:
		var practices = best_practices.get_generation_best_practices()
		print("=== BEST PRACTICES ===")
		for key in practices.keys():
			print(key, ": ", practices[key])
	else:
		print("Best practices модуль вимкнено")

@export_tool_button("Експортувати звіт", "Save")
func _export_performance_report():
	if best_practices:
		var report_path = "user://performance_report.md"
		best_practices.save_performance_report(report_path)
		print("Звіт експортовано в ", report_path)
	else:
		print("Best practices модуль вимкнено")
