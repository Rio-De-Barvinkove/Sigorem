extends CanvasLayer

@onready var info_label = $InfoLabel
@onready var debug_label = $DebugLabel
@onready var build_mode_label = $BuildModeLabel
@onready var world_gen_settings = get_node_or_null("../UI/WorldGenerationSettings")

var debug_hud_enabled := false

func _ready():
	build_mode_label.text = ""
	info_label.text = "WASD - рух | I - інвентар | B - build mode | Q/E - поворот камери | Mouse Wheel - зум | F10 - налаштування генерації"
	debug_label.visible = debug_hud_enabled
	debug_label.text = ""

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		toggle_world_gen_settings()
	elif event.is_action_pressed("toggle_debug_hud"):
		debug_hud_enabled = !debug_hud_enabled
		debug_label.visible = debug_hud_enabled
		if not debug_hud_enabled:
			debug_label.text = ""

func toggle_world_gen_settings():
	"""Перемикання меню налаштувань генерації світу"""
	if world_gen_settings:
		if world_gen_settings.visible:
			world_gen_settings.hide_settings()
		else:
			world_gen_settings.show_settings()
	else:
		push_warning("GameHUD: WorldGenerationSettings не знайдено!")

func _process(_delta):
	# Перевіряємо стан build mode
	var player = get_node_or_null("/root/World/Player")
	if player:
		var build_mode_node = player.get_node_or_null("BuildMode")
		if build_mode_node and build_mode_node.build_mode:
			build_mode_label.text = "BUILD MODE: ON | LMB - поставити блок | RMB - видалити блок"
		else:
			build_mode_label.text = ""

	# Показуємо debug інформацію про генерацію
	update_terrain_debug_info()

func update_terrain_debug_info():
	"""Оновлення debug інформації про генерацію терейну"""
	if not debug_hud_enabled:
		return

	var debug_text = ""

	# Знаходимо TerrainGenerator
	var terrain_generator = get_node_or_null("/root/World/GridMap/TerrainGenerator")
	if terrain_generator:
		# Інформація про seed
		if terrain_generator.noise:
			debug_text += "Seed: %d\n" % terrain_generator.noise.seed
		else:
			debug_text += "Seed: N/A\n"

		# Інформація про chunk_size
		debug_text += "Chunk: %dx%d\n" % [terrain_generator.chunk_size.x, terrain_generator.chunk_size.y]

		# Інформація про активні чанки
		if terrain_generator.chunk_module:
			var chunk_module = terrain_generator.chunk_module
			var active_chunks_count = 0
			if chunk_module.has_method("get_active_chunk_count"):
				active_chunks_count = chunk_module.get_active_chunk_count()
			else:
				active_chunks_count = chunk_module.active_chunks.size()
			debug_text += "Active Chunks: %d\n" % active_chunks_count

			var player_chunk := Vector2i.ZERO
			if chunk_module.has_method("get_player_chunk_position"):
				player_chunk = chunk_module.get_player_chunk_position()
			else:
				player_chunk = chunk_module.current_player_chunk
			debug_text += "Player Chunk: (%d, %d)" % [player_chunk.x, player_chunk.y]
		else:
			debug_text += "Active Chunks: 0\nPlayer Chunk: (0, 0)"
	else:
		debug_text = "Seed: N/A\nChunk: 0x0\nActive Chunks: 0\nPlayer Chunk: (0, 0)"

	debug_label.text = debug_text.strip_edges()
