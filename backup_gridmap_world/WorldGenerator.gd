@tool
extends GridMap

# Старий WorldGenerator - тепер просто обгортка для нового TerrainGenerator
# Зберігається для сумісності, але використовує новий модульний підхід

@export var terrain_generator: Node
@export var auto_setup_mesh_library := true

func _ready():
	_setup_mesh_library()
	_setup_terrain_generator()

func _enter_tree():
	# В редакторі _ready() може не викликатися, тому використовуємо _enter_tree()
	if Engine.is_editor_hint():
		_setup_mesh_library()

func _notification(what):
	# В редакторі оновлюємо MeshLibrary при зміні скрипта
	if Engine.is_editor_hint():
		if what == NOTIFICATION_READY or what == NOTIFICATION_ENTER_TREE:
			_setup_mesh_library()

func _setup_mesh_library():
	"""Встановлення MeshLibrary з BlockRegistry"""
	if not mesh_library and auto_setup_mesh_library:
		# В редакторі BlockRegistry може бути не готовий
		if Engine.is_editor_hint():
			# В редакторі створюємо простий MeshLibrary
			_setup_mesh_library_editor()
		else:
			# В грі чекаємо на BlockRegistry
			if BlockRegistry.has_signal("blocks_loaded"):
				await BlockRegistry.blocks_loaded
			mesh_library = BlockRegistry.get_mesh_library()
			print("WorldGenerator: MeshLibrary встановлено з BlockRegistry")

func _setup_mesh_library_editor():
	"""Налаштування MeshLibrary в редакторі"""
	if not mesh_library:
		mesh_library = MeshLibrary.new()
		# Створюємо базові блоки для редактора
		_create_editor_block(0, "grass", Color(0.4, 0.8, 0.2))
		_create_editor_block(1, "dirt", Color(0.55, 0.27, 0.07))
		_create_editor_block(2, "stone", Color(0.5, 0.5, 0.5))
		print("WorldGenerator: Створено MeshLibrary для редактора")

func _create_editor_block(index: int, name: String, color: Color):
	"""Створення блоку для редактора"""
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var shape = BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	mesh_library.create_item(index)
	mesh_library.set_item_name(index, name.capitalize() + " Block")
	mesh_library.set_item_mesh(index, mesh)
	mesh_library.set_item_shapes(index, [shape, Transform3D.IDENTITY])

func _setup_terrain_generator():
	"""Налаштування TerrainGenerator"""
	if not Engine.is_editor_hint():
		if not terrain_generator:
			# Створюємо новий TerrainGenerator якщо не встановлений
			var terrain_gen_node = Node.new()
			terrain_gen_node.set_script(load("res://scripts/game/world/generation/TerrainGenerator.gd"))
			terrain_generator = terrain_gen_node
			terrain_generator.target_gridmap = self
			add_child(terrain_generator)
			print("WorldGenerator: Створено новий TerrainGenerator")

		# Чекаємо один кадр, щоб скрипт встиг завантажитися
		await get_tree().process_frame

		# Знаходимо гравця в сцені та встановлюємо його для генератора
		var player = get_node("/root/World/Player")
		if player and terrain_generator:
			terrain_generator.player = player
			print("WorldGenerator: Встановлено гравця для TerrainGenerator")

		# Налаштовуємо базові параметри (тільки в грі)
		if terrain_generator and terrain_generator.has_method("set"):
			if "use_procedural_generation" in terrain_generator:
				terrain_generator.use_procedural_generation = true
			if "use_chunking" in terrain_generator:
				terrain_generator.use_chunking = true  # Увімкнути chunking для кращої продуктивності
			if "noise" in terrain_generator:
				if not terrain_generator.noise:
					terrain_generator.noise = FastNoiseLite.new()
				terrain_generator.noise.seed = randi()
				terrain_generator.noise.frequency = 0.05
