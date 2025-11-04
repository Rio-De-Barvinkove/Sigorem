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
