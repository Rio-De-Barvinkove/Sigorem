# @tool
# extends RefCounted
# class_name VoxdotTerrainAdapter
# 
# # Адаптер для роботи з VoxdotTerrain через уніфікований інтерфейс
# # VoxdotTerrain - це C++ клас, який потребує збірки модуля
# # ЗАКОМЕНТОВАНО: Voxdot потребує збірки модуля
# 
# # var voxdot_terrain: Node = null  # VoxdotTerrain instance
# 
# # func _init(terrain_node: Node):
# # 	if not terrain_node:
# # 		push_error("[VoxdotAdapter] Terrain node is null!")
# # 		return
# # 	
# # 	if not ClassDB.class_exists("VoxdotTerrain"):
# # 		push_error("[VoxdotAdapter] VoxdotTerrain class not available! Module needs to be compiled.")
# # 		return
# # 	
# # 	if not terrain_node.get_class() == "VoxdotTerrain":
# # 		push_error("[VoxdotAdapter] Node is not VoxdotTerrain!")
# # 		return
# # 	
# # 	voxdot_terrain = terrain_node
# 
# # Уніфікований інтерфейс для роботи з террейном
# # func initialize(noise_seed: int = 1337, voxel_scale: float = 0.1):
# # 	if not voxdot_terrain:
# # 		return false
# # 	
# # 	# Voxdot API: init_terrain_system(initial_voxel_scale, noise_seed, pool_size)
# # 	voxdot_terrain.init_terrain_system(voxel_scale, noise_seed, 500)
# # 	return true
# 
# # func set_noise(noise: FastNoiseLite):
# # 	if not voxdot_terrain:
# # 		return
# # 	
# # 	voxdot_terrain.set_noise(noise)
# 
# # func set_material(material: Material):
# # 	if not voxdot_terrain:
# # 		return
# # 	
# # 	voxdot_terrain.set_shared_material(material)
# 
# # func add_chunk(coords: Vector3, empty: bool = false):
# # 	if not voxdot_terrain:
# # 		return
# # 	
# # 	voxdot_terrain.add_chunk(coords, empty)
# 
# # func remove_chunk(coords: Vector3):
# # 	if not voxdot_terrain:
# # 		return
# # 	
# # 	voxdot_terrain.remove_chunk(coords)
# 
# # func has_chunk(coords: Vector3) -> bool:
# # 	if not voxdot_terrain:
# # 		return false
# # 	
# # 	return voxdot_terrain.has_chunk(coords)
# 
# # func get_loaded_chunks() -> Array:
# # 	if not voxdot_terrain:
# # 		return []
# # 	
# # 	return voxdot_terrain.get_loaded_chunk_coords()
# 
# # func process_dirty_chunks(max_chunks: int = 10):
# # 	if not voxdot_terrain:
# # 		return
# # 	
# # 	voxdot_terrain.process_dirty_chunks(max_chunks, false)
# 
# # func is_available() -> bool:
# # 	return ClassDB.class_exists("VoxdotTerrain") and voxdot_terrain != null

