extends VoxelViewer

# Скрипт для VoxelViewer, який слідує за гравцем
@export var target: Node3D

func _ready():
	# Якщо target встановлений через NodePath в сцені, використовуємо його
	if not target:
		# Якщо VoxelViewer дочірній вузол VoxelTerrain, шукаємо Player через NodePath
		if get_parent() and get_parent().name == "VoxelTerrain":
			# Перевіряємо NodePath target
			var target_path = get("target")
			if target_path and target_path is NodePath:
				target = get_node_or_null(target_path)
		# Якщо VoxelViewer дочірній вузол Player, використовуємо батьківський вузол
		elif get_parent() and get_parent().name == "Player":
			target = get_parent()
		else:
			# Шукаємо Player автоматично
			target = get_node_or_null("../../Player")
			if not target:
				target = get_node_or_null("../Player")
			if not target:
				target = get_tree().get_first_node_in_group("player")
	
	if target:
		global_position = target.global_position
		push_warning("[VoxelViewer] Initialized at: %s target: %s" % [global_position, target])
	else:
		push_warning("VoxelViewerFollower: target not found!")
	
	# Явно підключаємо до VoxelTerrain
	call_deferred("_connect_to_terrain")

func _connect_to_terrain():
	# Шукаємо VoxelTerrain в сцені
	var terrain = null
	
	# Спробуємо знайти через батьківський вузол
	if get_parent() and get_parent().name == "Player":
		# Якщо VoxelViewer дочірній вузол Player, шукаємо VoxelTerrain на рівні VoxelWorld
		terrain = get_node_or_null("../../VoxelTerrain")
	
	# Якщо не знайшли, шукаємо по всьому дереву
	if not terrain:
		# Шукаємо по типу в усіх вузлах дерева
		var root = get_tree().root
		terrain = _find_voxel_terrain(root)
	
	if terrain:
		print("[VoxelViewer] Terrain found: ", terrain.name, " at ", terrain.global_position)
		push_warning("[VoxelViewer] Connected to terrain: %s" % terrain.name)
		# VoxelViewer автоматично підключається до найближчого VoxelTerrain
		# Переконаємося, що ми в правильній позиції
		if target:
			global_position = target.global_position
		# Додаткова діагностика: перевіряємо, чи terrain має generator
		if terrain.generator:
			push_warning("[VoxelViewer] Terrain has generator: %s" % terrain.generator)
		else:
			push_warning("[VoxelViewer] WARNING: Terrain has NO generator!")
		if terrain.stream:
			push_warning("[VoxelViewer] Terrain has stream: %s" % terrain.stream)
		else:
			push_warning("[VoxelViewer] Stream: None (generation only)")
	else:
		push_warning("[VoxelViewer] VoxelTerrain not found! Generation will not work.")

func _find_voxel_terrain(node: Node) -> VoxelTerrain:
	# Рекурсивно шукаємо VoxelTerrain
	if node is VoxelTerrain:
		return node as VoxelTerrain
	
	for child in node.get_children():
		var result = _find_voxel_terrain(child)
		if result:
			return result
	
	return null

func _process(_delta):
	if target:
		var new_pos = target.global_position
		if global_position.distance_to(new_pos) > 0.1:
			var old_pos = global_position
			global_position = new_pos
			# Діагностика руху (тільки якщо пройшли більше 5 одиниць)
			if old_pos.distance_to(new_pos) > 5.0:
				push_warning("[VoxelViewer] Moved from %s to %s (distance: %.1f)" % [old_pos, new_pos, old_pos.distance_to(new_pos)])
