extends VoxelViewer

# Скрипт для VoxelViewer, який слідує за гравцем
@export var target: Node3D

func _ready():
	# Якщо target встановлений через NodePath в сцені, використовуємо його
	if not target:
		# Якщо VoxelViewer дочірній вузол VoxelLodTerrain, шукаємо Player через NodePath
		if get_parent() and get_parent().name == "VoxelLodTerrain":
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
		print("[VoxelViewer] Initialized at: ", global_position, " target: ", target)
	else:
		push_warning("VoxelViewerFollower: target not found!")
	
	# Явно підключаємо до VoxelLodTerrain
	call_deferred("_connect_to_terrain")

func _connect_to_terrain():
	# Якщо VoxelViewer дочірній вузол VoxelLodTerrain, використовуємо батьківський вузол
	var terrain = null
	if get_parent() and get_parent() is VoxelLodTerrain:
		terrain = get_parent()
	else:
		# Шукаємо VoxelLodTerrain
		terrain = get_tree().get_first_node_in_group("voxel_terrain")
		if not terrain:
			terrain = get_node_or_null("../VoxelLodTerrain")
		if not terrain:
			terrain = get_node_or_null("../../VoxelLodTerrain")
		if not terrain:
			# Шукаємо по типу
			for node in get_tree().get_nodes_in_group(""):
				if node is VoxelLodTerrain:
					terrain = node
					break
	
	if terrain:
		print("[VoxelViewer] Terrain found: ", terrain, " (parent: ", get_parent(), ")")
		# VoxelViewer автоматично підключається до найближчого VoxelLodTerrain
		# Не потрібно явно встановлювати terrain
	else:
		push_warning("[VoxelViewer] VoxelLodTerrain not found!")

func _process(_delta):
	if target:
		var new_pos = target.global_position
		if global_position.distance_to(new_pos) > 0.1:
			global_position = new_pos
