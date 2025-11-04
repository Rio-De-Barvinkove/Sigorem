extends Node
class_name LODManager

# Модуль для керування LOD (Level of Detail)

@export_group("LOD налаштування")
@export var lod_distances: Array[float] = [50.0, 100.0, 200.0]
@export var lod_resolutions: Array[float] = [1.0, 0.5, 0.25]  # Резолюція генерації

var player: Node3D
var active_lod_levels: Dictionary = {}

func _ready():
	if get_parent().player:
		player = get_parent().player

func _process(delta):
	if player:
		update_lod_levels()

func update_lod_levels():
	"""Оновлення LOD рівнів залежно від відстані до гравця"""
	# Заглушка для LOD системи
	# Реалізація буде залежати від chunking системи
	pass

func get_lod_level_for_distance(distance: float) -> int:
	"""Отримати LOD рівень для заданої відстані"""
	for i in range(lod_distances.size()):
		if distance <= lod_distances[i]:
			return i
	return lod_distances.size()  # Найнижчий LOD

func apply_lod_to_chunk(chunk_pos: Vector2i, lod_level: int):
	"""Застосувати LOD до чанка"""
	# Заглушка
	print("LODManager: Застосовано LOD рівень ", lod_level, " до чанка ", chunk_pos)
