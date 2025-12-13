extends Node
class_name TerrainDepthManager
## Менеджер глибини для VoxdotTerrain - керує Y-sort, depth buffer, матеріалами

# Сигнали
signal depth_settings_changed()
signal y_sort_updated(mesh_count: int)
signal performance_optimized(optimization_type: String)

# Посилання на основні компоненти
var terrain: VoxdotTerrain
var player: Node3D
var view_distance: int
var voxel_scale: float


func initialize(p_terrain: VoxdotTerrain, p_player: Node3D, p_view_distance: int, p_voxel_scale: float) -> void:
	## Ініціалізація менеджера глибини
	terrain = p_terrain
	player = p_player
	view_distance = p_view_distance
	voxel_scale = p_voxel_scale

	print("TerrainDepthManager: Ініціалізований успішно")


func process_delta(delta: float) -> void:
	## Обробка кожного кадру
	if not terrain or not player:
		return

	# Поки що мінімальна обробка
	pass


func check_chunk_seams(loaded_chunks: Dictionary) -> void:
	## Перевірка швів між чанками
	print("TerrainDepthManager: check_chunk_seams called with ", loaded_chunks.size(), " chunks")
