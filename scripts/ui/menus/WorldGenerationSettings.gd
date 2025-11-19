extends Control
class_name WorldGenerationSettings

# Посилання на VoxelLodTerrain (старий TerrainGenerator замінено)
@export var voxel_lod_terrain: Node # VoxelLodTerrain

# Старий terrain_generator більше не використовується
var terrain_generator = null

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
	"""Завантажити поточні налаштування з VoxelLodTerrain"""
	push_warning("WorldGenerationSettings: Старий TerrainGenerator замінено на VoxelLodTerrain. Завантаження налаштувань вимкнено.")
	print("WorldGenerationSettings: Налаштування не завантажено (VoxelLodTerrain)")

func find_terrain_generator():
	"""Знайти VoxelLodTerrain в сцені"""
	push_warning("WorldGenerationSettings: Старий TerrainGenerator замінено на VoxelLodTerrain. Пошук генератора вимкнено.")
	print("WorldGenerationSettings: Пошук генератора пропущено (VoxelLodTerrain)")

func apply_settings():
	"""Застосувати налаштування до VoxelLodTerrain"""
	push_warning("WorldGenerationSettings: Старий TerrainGenerator замінено на VoxelLodTerrain. Застосування налаштувань вимкнено.")
	print("WorldGenerationSettings: Налаштування не застосовано (VoxelLodTerrain)")

func clear_world():
	"""Очистити поточний світ"""
	push_warning("WorldGenerationSettings: Старий TerrainGenerator замінено на VoxelLodTerrain. Очищення світу вимкнено.")
	print("WorldGenerationSettings: Світ не очищено (VoxelLodTerrain)")

func generate_world():
	"""Запустити генерацію світу з поточними налаштуваннями"""
	
	# Перевірка на безпечність налаштувань
	var warning_messages = []
	
	if height_amplitude and height_amplitude.value > 32:
		warning_messages.append("Амплітуда висоти > 32 може викликати краш!")
	
	if max_height and max_height.value > 128:
		warning_messages.append("Макс. висота > 128 може викликати краш!")
	
	if chunk_radius and chunk_radius.value > 5:
		warning_messages.append("Радіус чанків > 5 може викликати фризи!")
	
	# Оцінка приблизної кількості блоків
	var total_chunks = (chunk_radius.value * 2 + 1) * (chunk_radius.value * 2 + 1) if chunk_radius else 121
	var blocks_per_chunk = chunk_size_x.value * chunk_size_y.value * max_height.value if max_height else 100000
	var total_blocks = total_chunks * blocks_per_chunk
	
	if total_blocks > 10000000:  # 10 мільйонів блоків
		warning_messages.append("Світ ДУЖЕ великий (" + str(total_blocks / 1000000) + "M блоків)! Ризик краша!")
	
	if warning_messages.size() > 0:
		print("ПОПЕРЕДЖЕННЯ генерації:")
		for msg in warning_messages:
			push_warning(msg)
			print("  - " + msg)
	
	apply_settings()

	# Перевірка наявності VoxelLodTerrain замість старого TerrainGenerator
	var voxel_lod_terrain = get_tree().get_root().find_child("VoxelLodTerrain", true, false)
	if not voxel_lod_terrain:
		push_error("WorldGenerationSettings: VoxelLodTerrain не доступний!")
		return

	push_warning("WorldGenerationSettings: Старий TerrainGenerator замінено на VoxelLodTerrain. Перегенерація світу буде імітувати перезапуск генератора.")
	# Для VoxelLodTerrain просто імітуємо перезапуск - це не ідеально, але працює для тесту
	voxel_lod_terrain.stream = voxel_lod_terrain.stream # Перезапуск генератора

	# Показуємо повідомлення про успішну операцію
	print("WorldGenerationSettings: Світ перегенеровано (імітація)")

	# Спробуємо телепортувати гравця на поверхню
	var player = get_tree().get_root().find_child("Player", true, false)
	if player:
		player.global_position = Vector3(0, 25, 0)  # Проста телепортація на висоту
		print("WorldGenerationSettings: Гравець телепортовано на стартову позицію")

	print("WorldGenerationSettings: Операція завершена")

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
