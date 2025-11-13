extends Control
class_name WorldGenerationSettings

# Посилання на TerrainGenerator
@export var terrain_generator: TerrainGenerator

# Автоматичне оновлення
var auto_update_enabled := false

# Основні модулі
@onready var procedural_generation = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ProceduralGeneration
@onready var chunking = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/Chunking
@onready var optimization = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/Optimization
@onready var best_practices = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/BestPractices

@onready var chunk_size_x = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/ChunkSizeHBox/ChunkSizeX
@onready var chunk_size_y = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/ChunkSizeHBox/ChunkSizeY
@onready var chunk_radius = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/ChunkRadius
@onready var height_amplitude = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/HeightAmplitude
@onready var base_height = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/BaseHeight
@onready var max_height = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/MaxHeight

# Noise parameters
@onready var seed = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/SeedHBox/Seed
@onready var randomize_seed = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/SeedHBox/RandomizeSeed
@onready var frequency = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/Frequency
@onready var noise_type = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/NoiseType
@onready var fractal_type = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/FractalType
@onready var octaves = $Panel/VBoxContainer/TabContainer/CoreModules/ModulesVBox/ParamsGrid/Octaves

# Розширені модулі
@onready var structures = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/Structures
@onready var structure_density = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/StructureDensity
@onready var lod = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/LOD
@onready var threading = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/Threading
@onready var vegetation = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/Vegetation
@onready var vegetation_radius = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/VegetationRadius
@onready var heightmap = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/Heightmap
@onready var heightmap_scale = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/HeightmapScale
@onready var heightmap_size_x = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/HeightmapSizeHBox/HeightmapSizeX
@onready var heightmap_size_y = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/HeightmapSizeHBox/HeightmapSizeY
@onready var heightmap_subdivides = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/HeightmapSubdivides
@onready var splat_mapping = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/SplatMapping
@onready var detail_layers = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/DetailLayers
@onready var save_load = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/SaveLoad
@onready var native_optimization = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/NativeOptimization
@onready var precomputed_patterns = $Panel/VBoxContainer/TabContainer/AdvancedModules/AdvancedVBox/PrecomputedPatterns

# Оптимізація
@onready var max_generation_time = $Panel/VBoxContainer/TabContainer/Optimization/OptimizationVBox/MaxGenerationTime
@onready var target_fps = $Panel/VBoxContainer/TabContainer/Optimization/OptimizationVBox/TargetFPS
@onready var max_active_chunks = $Panel/VBoxContainer/TabContainer/Optimization/OptimizationVBox/MaxActiveChunks
@onready var enable_chunk_culling = $Panel/VBoxContainer/TabContainer/Optimization/OptimizationVBox/EnableChunkCulling
@onready var max_chunk_distance = $Panel/VBoxContainer/TabContainer/Optimization/OptimizationVBox/MaxChunkDistance

# Кнопки
@onready var auto_update = $Panel/VBoxContainer/ButtonsHBox/AutoUpdate

func _ready():
	# Встановлюємо тексти вкладок
	var tab_container = $Panel/VBoxContainer/TabContainer
	tab_container.set_tab_title(0, "Основні модулі")
	tab_container.set_tab_title(1, "Розширені модулі")
	tab_container.set_tab_title(2, "Оптимізація")

	hide()
	# Завантажуємо поточні налаштування
	load_current_settings()
	
	# Підключаємо сигнали для автоматичного оновлення
	connect_signals()

func connect_signals():
	"""Підключення сигналів для автоматичного оновлення"""
	# Основні модулі
	if procedural_generation:
		procedural_generation.toggled.connect(_on_setting_changed)
	if chunking:
		chunking.toggled.connect(_on_setting_changed)
	if optimization:
		optimization.toggled.connect(_on_setting_changed)
	if best_practices:
		best_practices.toggled.connect(_on_setting_changed)
	
	# Параметри
	if chunk_size_x:
		chunk_size_x.value_changed.connect(_on_setting_changed)
	if chunk_size_y:
		chunk_size_y.value_changed.connect(_on_setting_changed)
	if chunk_radius:
		chunk_radius.value_changed.connect(_on_setting_changed)
	if height_amplitude:
		height_amplitude.value_changed.connect(_on_setting_changed)
	if base_height:
		base_height.value_changed.connect(_on_setting_changed)
	if max_height:
		max_height.value_changed.connect(_on_setting_changed)

	# Noise parameters
	if seed:
		seed.value_changed.connect(_on_setting_changed)
	if randomize_seed:
		randomize_seed.pressed.connect(_on_randomize_seed_pressed)
	if frequency:
		frequency.value_changed.connect(_on_setting_changed)
	if noise_type:
		noise_type.item_selected.connect(_on_setting_changed)
	if fractal_type:
		fractal_type.item_selected.connect(_on_setting_changed)
	if octaves:
		octaves.value_changed.connect(_on_setting_changed)
	
	# Розширені модулі
	if structures:
		structures.toggled.connect(_on_setting_changed)
	if structure_density:
		structure_density.value_changed.connect(_on_setting_changed)
	if lod:
		lod.toggled.connect(_on_setting_changed)
	if threading:
		threading.toggled.connect(_on_setting_changed)
	if vegetation:
		vegetation.toggled.connect(_on_setting_changed)
	if vegetation_radius:
		vegetation_radius.value_changed.connect(_on_setting_changed)
	if heightmap:
		heightmap.toggled.connect(_on_setting_changed)
	if heightmap_scale:
		heightmap_scale.value_changed.connect(_on_setting_changed)
	if heightmap_size_x:
		heightmap_size_x.value_changed.connect(_on_setting_changed)
	if heightmap_size_y:
		heightmap_size_y.value_changed.connect(_on_setting_changed)
	if heightmap_subdivides:
		heightmap_subdivides.value_changed.connect(_on_setting_changed)
	if splat_mapping:
		splat_mapping.toggled.connect(_on_setting_changed)
	if detail_layers:
		detail_layers.toggled.connect(_on_setting_changed)
	if save_load:
		save_load.toggled.connect(_on_setting_changed)
	if native_optimization:
		native_optimization.toggled.connect(_on_setting_changed)
	if precomputed_patterns:
		precomputed_patterns.toggled.connect(_on_setting_changed)
	
	# Оптимізація
	if max_generation_time:
		max_generation_time.value_changed.connect(_on_setting_changed)
	if target_fps:
		target_fps.value_changed.connect(_on_setting_changed)
	if max_active_chunks:
		max_active_chunks.value_changed.connect(_on_setting_changed)
	if enable_chunk_culling:
		enable_chunk_culling.toggled.connect(_on_setting_changed)
	if max_chunk_distance:
		max_chunk_distance.value_changed.connect(_on_setting_changed)

func _on_setting_changed(_value = null):
	"""Обробник зміни налаштування"""
	if auto_update_enabled:
		# Для зміни noise_type або інших параметрів, що вимагають повної регенерації,
		# застосовуємо налаштування без повної регенерації (тільки для нових чанків)
		apply_settings()
		# Повна регенерація тільки при явному натисканні кнопки "Generate"

func load_current_settings():
	"""Завантажити поточні налаштування з TerrainGenerator"""
	if not terrain_generator:
		find_terrain_generator()
		return

	if not terrain_generator:
		return

	# Основні модулі
	procedural_generation.button_pressed = terrain_generator.use_procedural_generation
	chunking.button_pressed = terrain_generator.use_chunking
	optimization.button_pressed = terrain_generator.use_optimization
	best_practices.button_pressed = terrain_generator.use_best_practices

	# Параметри
	chunk_size_x.value = terrain_generator.chunk_size.x
	chunk_size_y.value = terrain_generator.chunk_size.y
	chunk_radius.value = terrain_generator.chunk_radius
	height_amplitude.value = terrain_generator.height_amplitude
	base_height.value = terrain_generator.base_height
	max_height.value = terrain_generator.max_height

	# Noise parameters
	if terrain_generator.noise:
		seed.value = terrain_generator.noise.seed
		frequency.value = terrain_generator.noise.frequency
		noise_type.selected = terrain_generator.noise.noise_type
		fractal_type.selected = terrain_generator.noise.fractal_type
		octaves.value = terrain_generator.noise.fractal_octaves

	# Розширені модулі
	structures.button_pressed = terrain_generator.use_structures
	lod.button_pressed = terrain_generator.use_lod
	threading.button_pressed = terrain_generator.use_threading
	vegetation.button_pressed = terrain_generator.use_vegetation
	heightmap.button_pressed = terrain_generator.use_heightmap
	splat_mapping.button_pressed = terrain_generator.use_splat_mapping
	detail_layers.button_pressed = terrain_generator.use_detail_layers
	save_load.button_pressed = terrain_generator.use_save_load
	native_optimization.button_pressed = terrain_generator.use_native_optimization
	precomputed_patterns.button_pressed = terrain_generator.use_precomputed_patterns

	# Оптимізація
	enable_chunk_culling.button_pressed = terrain_generator.enable_chunk_culling
	max_chunk_distance.value = terrain_generator.max_chunk_distance

	# Heightmap параметри (з TerrainGenerator)
	heightmap_scale.value = terrain_generator.heightmap_scale
	heightmap_size_x.value = terrain_generator.heightmap_size.x
	heightmap_size_y.value = terrain_generator.heightmap_size.y
	heightmap_subdivides.value = terrain_generator.heightmap_subdivides

	# Завантажуємо налаштування з модулів якщо вони існують
	if terrain_generator.structure_module:
		structure_density.value = terrain_generator.structure_module.structure_density
	
	if terrain_generator.vegetation_module:
		vegetation_radius.value = terrain_generator.vegetation_module.multimesh_radius
	
	if terrain_generator.optimization_module:
		max_generation_time.value = terrain_generator.optimization_module.max_generation_time_per_frame
		target_fps.value = terrain_generator.optimization_module.target_fps
		max_active_chunks.value = terrain_generator.optimization_module.max_active_chunks

	print("WorldGenerationSettings: Налаштування завантажено")

func find_terrain_generator():
	"""Знайти TerrainGenerator в сцені"""
	var generators = get_tree().get_nodes_in_group("terrain_generator")
	if generators.size() > 0:
		terrain_generator = generators[0]
		load_current_settings()
		print("WorldGenerationSettings: Знайдено TerrainGenerator")
	else:
		push_warning("WorldGenerationSettings: TerrainGenerator не знайдено!")

func apply_settings():
	"""Застосувати налаштування до TerrainGenerator"""
	if not terrain_generator:
		find_terrain_generator()
		if not terrain_generator:
			push_error("WorldGenerationSettings: Неможливо знайти TerrainGenerator!")
			return

	# Основні модулі
	terrain_generator.use_procedural_generation = procedural_generation.button_pressed
	terrain_generator.use_chunking = chunking.button_pressed
	terrain_generator.use_optimization = optimization.button_pressed
	terrain_generator.use_best_practices = best_practices.button_pressed

	# Параметри
	terrain_generator.chunk_size = Vector2i(int(chunk_size_x.value), int(chunk_size_y.value))
	terrain_generator.chunk_radius = int(chunk_radius.value)
	terrain_generator.height_amplitude = int(height_amplitude.value)
	terrain_generator.base_height = int(base_height.value)
	terrain_generator.max_height = int(max_height.value)

	# Noise parameters
	if terrain_generator.noise:
		terrain_generator.noise.seed = int(seed.value)
		terrain_generator.noise.frequency = frequency.value
		terrain_generator.noise.noise_type = noise_type.selected
		terrain_generator.noise.fractal_type = fractal_type.selected
		terrain_generator.noise.fractal_octaves = int(octaves.value)

	# Розширені модулі
	terrain_generator.use_structures = structures.button_pressed
	terrain_generator.use_lod = lod.button_pressed
	terrain_generator.use_threading = threading.button_pressed
	terrain_generator.use_vegetation = vegetation.button_pressed
	terrain_generator.use_heightmap = heightmap.button_pressed
	terrain_generator.use_splat_mapping = splat_mapping.button_pressed
	terrain_generator.use_detail_layers = detail_layers.button_pressed
	terrain_generator.use_save_load = save_load.button_pressed
	terrain_generator.use_native_optimization = native_optimization.button_pressed
	terrain_generator.use_precomputed_patterns = precomputed_patterns.button_pressed

	# Оптимізація
	terrain_generator.enable_chunk_culling = enable_chunk_culling.button_pressed
	terrain_generator.max_chunk_distance = max_chunk_distance.value

	# Heightmap параметри (до TerrainGenerator, вони застосуються при ініціалізації модуля)
	terrain_generator.heightmap_scale = heightmap_scale.value
	terrain_generator.heightmap_size = Vector2(heightmap_size_x.value, heightmap_size_y.value)
	terrain_generator.heightmap_subdivides = heightmap_subdivides.value

	# Застосовуємо налаштування до модулів (якщо вони вже існують)
	if terrain_generator.structure_module:
		terrain_generator.structure_module.structure_density = structure_density.value
	
	if terrain_generator.vegetation_module:
		terrain_generator.vegetation_module.multimesh_radius = vegetation_radius.value
	
	# Heightmap параметри застосовуються під час ініціалізації модуля
	if terrain_generator.heightmap_module:
		terrain_generator.heightmap_module.height_scale = heightmap_scale.value
		terrain_generator.heightmap_module.mesh_size = Vector2(heightmap_size_x.value, heightmap_size_y.value)
		terrain_generator.heightmap_module.subdivides = heightmap_subdivides.value
	
	if terrain_generator.optimization_module:
		terrain_generator.optimization_module.max_generation_time_per_frame = max_generation_time.value
		terrain_generator.optimization_module.target_fps = target_fps.value
		terrain_generator.optimization_module.max_active_chunks = max_active_chunks.value

	print("WorldGenerationSettings: Налаштування застосовано")

func clear_world():
	"""Очистити поточний світ"""
	if terrain_generator and terrain_generator.target_gridmap:
		terrain_generator.target_gridmap.clear()
		print("WorldGenerationSettings: Світ очищено")

func generate_world():
	"""Запустити генерацію світу з поточними налаштуваннями"""
	apply_settings()

	if not terrain_generator:
		push_error("WorldGenerationSettings: TerrainGenerator не доступний!")
		return

	# Очищаємо старий світ (тільки активні чанки, щоб уникнути зависання)
	if terrain_generator.chunk_module:
		# Видаляємо чанки поступово
		var chunks_to_remove = terrain_generator.chunk_module.active_chunks.keys()
		for chunk_pos in chunks_to_remove:
			terrain_generator.chunk_module.remove_chunk(terrain_generator.target_gridmap, chunk_pos)
			# Чекаємо мікросекунду між видаленнями
			await get_tree().process_frame
	else:
		# Якщо немає chunk_module, очищаємо все одразу
		clear_world()
	
	# Чекаємо один кадр для очищення
	await get_tree().process_frame

	# Переініціалізовуємо модулі
	terrain_generator.initialize_modules()
	
	# Чекаємо один кадр для ініціалізації модулів
	await get_tree().process_frame

	# Генеруємо новий світ
	terrain_generator.generate_initial_terrain()
	
	# Телепортуємо гравця на стартову зону після регенерації
	terrain_generator.teleport_player_to_starting_area()

	print("WorldGenerationSettings: Генерація світу розпочата")

func apply_and_generate():
	"""Застосувати налаштування та згенерувати світ"""
	generate_world()

func _on_generate_pressed():
	"""Обробник натискання кнопки генерації"""
	apply_and_generate()

func _on_close_pressed():
	"""Обробник натискання кнопки закриття"""
	hide()

func _on_randomize_seed_pressed():
	"""Обробник натискання кнопки рандомізації seed"""
	var random_seed = randi()
	seed.value = random_seed
	_on_setting_changed()

func _on_auto_update_toggled(button_pressed: bool):
	"""Обробник перемикання автоматичного оновлення"""
	auto_update_enabled = button_pressed
	if button_pressed:
		# Генеруємо одразу при увімкненні
		apply_and_generate()

# Публічні методи для зовнішнього керування
func show_settings():
	"""Показати налаштування"""
	load_current_settings()
	show()

func hide_settings():
	"""Сховати налаштування"""
	hide()