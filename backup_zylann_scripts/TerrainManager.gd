# @tool
# extends Node3D
# class_name TerrainManager
# 
# # Менеджер для перемикання між Zylann (VoxelTools) та Voxdot генераторами
# # ЗАКОМЕНТОВАНО: Voxdot потребує збірки модуля
# 
# # enum TerrainType {
# # 	ZYLANN,  # VoxelTools (Zylann)
# # 	VOXDOT   # Voxdot C++ модуль
# # }
# 
# # @export var terrain_type: TerrainType = TerrainType.ZYLANN
# # @export var auto_switch: bool = false  # Автоматичне перемикання залежно від наявності
# 
# # Референси на обидва террейни
# # var zylann_terrain: VoxelTerrain = null
# # var voxdot_terrain: Node = null  # VoxdotTerrain (якщо доступний)
# 
# # Поточний активний террейн
# # var active_terrain: Node = null
# 
# # func _ready():
# # 	_initialize_terrain_system()
# 
# # func _initialize_terrain_system():
# # 	# Шукаємо Zylann террейн
# # 	zylann_terrain = _find_zylann_terrain()
# # 	
# # 	# Шукаємо Voxdot террейн (якщо доступний)
# # 	if _is_voxdot_available():
# # 		voxdot_terrain = _find_voxdot_terrain()
# # 	
# # 	# Визначаємо активний террейн
# # 	_determine_active_terrain()
# # 	
# # 	# Налаштовуємо активний террейн
# # 	_setup_active_terrain()
# 
# # func _is_voxdot_available() -> bool:
# # 	# Перевіряємо, чи доступний клас VoxdotTerrain
# # 	# Він буде доступний тільки якщо модуль зібрано та завантажено
# # 	return ClassDB.class_exists("VoxdotTerrain")
# 
# # func _find_zylann_terrain() -> VoxelTerrain:
# # 	# Шукаємо VoxelTerrain в сцені
# # 	var terrain = get_tree().get_first_node_in_group("voxel_terrain")
# # 	if terrain and terrain is VoxelTerrain:
# # 		return terrain
# # 	
# # 	# Або шукаємо по типу
# # 	for child in get_tree().root.get_children():
# # 		var found = _find_node_by_type(child, "VoxelTerrain")
# # 		if found:
# # 			return found
# # 	
# # 	return null
# 
# # func _find_voxdot_terrain() -> Node:
# # 	# Шукаємо VoxdotTerrain в сцені
# # 	if not _is_voxdot_available():
# # 		return null
# # 	
# # 	# Шукаємо по типу VoxdotTerrain
# # 	for child in get_tree().root.get_children():
# # 		var found = _find_node_by_type(child, "VoxdotTerrain")
# # 		if found:
# # 			return found
# # 	
# # 	return null
# 
# # func _find_node_by_type(node: Node, type_name: String) -> Node:
# # 	if node.get_class() == type_name:
# # 		return node
# # 	
# # 	for child in node.get_children():
# # 		var found = _find_node_by_type(child, type_name)
# # 		if found:
# # 			return found
# # 	
# # 	return null
# 
# # func _determine_active_terrain():
# # 	if auto_switch:
# # 		# Автоматичне визначення: перевага Voxdot, якщо доступний
# # 		if _is_voxdot_available() and voxdot_terrain:
# # 			terrain_type = TerrainType.VOXDOT
# # 		else:
# # 			terrain_type = TerrainType.ZYLANN
# # 	
# # 	# Встановлюємо активний террейн
# # 	match terrain_type:
# # 		TerrainType.ZYLANN:
# # 			active_terrain = zylann_terrain
# # 		TerrainType.VOXDOT:
# # 			active_terrain = voxdot_terrain
# 
# # func _setup_active_terrain():
# # 	if not active_terrain:
# # 		push_error("[TerrainManager] No active terrain found!")
# # 		return
# # 	
# # 	# Приховуємо неактивний террейн
# # 	if zylann_terrain:
# # 		zylann_terrain.visible = (active_terrain == zylann_terrain)
# # 	
# # 	if voxdot_terrain:
# # 		voxdot_terrain.visible = (active_terrain == voxdot_terrain)
# # 	
# # 	push_warning("[TerrainManager] Active terrain: %s (type: %s)" % [
# # 		active_terrain.name if active_terrain else "None",
# # 		TerrainType.keys()[terrain_type]
# # 	])
# 
# # Публічні методи для роботи з террейном
# # func get_active_terrain() -> Node:
# # 	return active_terrain
# 
# # func switch_terrain(new_type: TerrainType):
# # 	if terrain_type == new_type:
# # 		return
# # 	
# # 	terrain_type = new_type
# # 	_determine_active_terrain()
# # 	_setup_active_terrain()
# 
# # func is_voxdot_available() -> bool:
# # 	return _is_voxdot_available()
# 
# # func get_terrain_type() -> TerrainType:
# # 	return terrain_type

