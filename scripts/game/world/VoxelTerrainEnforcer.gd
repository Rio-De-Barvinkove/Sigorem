extends Node

# Скрипт який примусово встановлює run_stream_in_editor = true для VoxelLodTerrain
# Щоб Godot не вимикав його автоматично

var voxel_terrain: VoxelLodTerrain

func _enter_tree():
	voxel_terrain = get_node_or_null("../VoxelLodTerrain")
	if not voxel_terrain:
		voxel_terrain = get_node_or_null("VoxelLodTerrain")
	if not voxel_terrain:
		voxel_terrain = get_tree().get_first_node_in_group("voxel_terrain")
	
	if voxel_terrain:
		_force_enable()

func _ready():
	if voxel_terrain:
		_force_enable()
	# Також через кадр
	call_deferred("_force_enable")
	await get_tree().process_frame
	_force_enable()
	await get_tree().create_timer(0.1).timeout
	_force_enable()

func _process(_delta):
	# Агресивно перевіряємо кожен кадр
	if voxel_terrain:
		if not voxel_terrain.run_stream_in_editor:
			voxel_terrain.run_stream_in_editor = true

func _force_enable():
	if voxel_terrain:
		voxel_terrain.run_stream_in_editor = true
		print("[Enforcer] VoxelLodTerrain: run_stream_in_editor=", voxel_terrain.run_stream_in_editor)
		print("[Enforcer] generator=", voxel_terrain.generator, " (valid: ", voxel_terrain.generator != null, ")")
		print("[Enforcer] stream=", voxel_terrain.stream, " (valid: ", voxel_terrain.stream != null, ")")
		print("[Enforcer] mesher=", voxel_terrain.mesher, " (valid: ", voxel_terrain.mesher != null, ")")
		print("[Enforcer] is_inside_tree=", voxel_terrain.is_inside_tree())
		
		# Перевірка чи terrain активний
		if not voxel_terrain.is_inside_tree():
			push_warning("VoxelTerrainEnforcer: VoxelLodTerrain NOT in tree!")
		
		# Перевірка та підключення VoxelViewer - шукаємо в дочірніх вузлах VoxelLodTerrain
		var viewer = voxel_terrain.get_node_or_null("VoxelViewer")
		if not viewer:
			# Шукаємо по типу в сцені
			for node in get_tree().get_nodes_in_group(""):
				if node is VoxelViewer:
					viewer = node
					break
		
		if viewer:
			print("[Enforcer] Found VoxelViewer: ", viewer, " at: ", viewer.global_position if viewer.is_inside_tree() else viewer.position)
			print("[Enforcer] VoxelViewer parent: ", viewer.get_parent())
		else:
			push_error("[Enforcer] VoxelViewer NOT FOUND! This is why generation doesn't work!")
