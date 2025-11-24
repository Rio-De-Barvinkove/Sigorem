extends VoxelTerrain

func _enter_tree():
	# VoxelTerrain (без LOD) для мікровокселів
	push_warning("[VoxelTerrain] _enter_tree() called, max_view_distance = %d" % max_view_distance)
	max_view_distance = 256  # Відстань генерації
	mesh_block_size = 16  # Маленькі блоки для мікровокселів
	# Примітка: threaded_update_enabled та full_load_mode_enabled доступні тільки в VoxelLodTerrain
	push_warning("[VoxelTerrain] _enter_tree() set max_view_distance=%d, mesh_block_size=%d" % [max_view_distance, mesh_block_size])

func _ready():
	push_warning("[VoxelTerrain] _ready() called, max_view_distance = %d" % max_view_distance)

	# Додаткова діагностика
	if generator:
		push_warning("[VoxelTerrain] Generator: %s" % generator)
		if generator.has_method("_generate_block"):
			push_warning("[VoxelTerrain] Generator has _generate_block method")
		else:
			push_error("[VoxelTerrain] Generator MISSING _generate_block method!")
	else:
		push_error("[VoxelTerrain] WARNING: No generator!")

	if stream:
		push_warning("[VoxelTerrain] Stream: %s" % stream)
	else:
		push_error("[VoxelTerrain] WARNING: No stream!")

	if mesher:
		push_warning("[VoxelTerrain] Mesher: %s" % mesher)
		if mesher is VoxelMesherTransvoxel:
			push_warning("[VoxelTerrain] Using VoxelMesherTransvoxel (smooth meshing for microvoxels)")
		else:
			push_warning("[VoxelTerrain] Mesher type: %s" % mesher.get_class())
	else:
		push_error("[VoxelTerrain] WARNING: No mesher!")

	# Перевіряємо, чи є дочірні вузли (blocks)
	push_warning("[VoxelTerrain] Child count: %d" % get_child_count())
	for i in range(get_child_count()):
		var child = get_child(i)
		push_warning("[VoxelTerrain] Child %d: %s (%s)" % [i, child.name, child.get_class()])

	push_warning("[VoxelTerrain] Terrain initialization complete - VoxelTerrain generates automatically based on max_view_distance")
