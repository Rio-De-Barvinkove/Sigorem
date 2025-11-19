extends Node
class_name LODManager

# Модуль для керування LOD (Level of Detail)
# 
# ВАЖЛИВО: Цей файл є заглушкою і НЕ реалізований.
# Поки що не інтегровано з ChunkManager і не виконує жодних дій.
# 
# Рекомендації:
# - Файл залишено для майбутньої реалізації
# - use_lod := false в TerrainGenerator (вимкнено за замовчуванням)
# - Для простого LOD можна додати логіку безпосередньо в ChunkManager
#   при генерації чанка (див. коментарі в _create_chunk_generation_job)

@export_group("LOD налаштування")
@export var lod_distances: Array[float] = [50.0, 100.0, 200.0]
@export var lod_resolutions: Array[float] = [1.0, 0.5, 0.25]  # Резолюція генерації (НЕ ВИКОРИСТОВУЄТЬСЯ)

var player: Node3D
var active_lod_levels: Dictionary = {}

func _ready():
	# ВИПРАВЛЕНО: Додано перевірку наявності батьківського вузла
	if get_parent() and get_parent().has("player"):
		player = get_parent().player

func _process(delta):
	# ВИПРАВЛЕНО: Видалено виклик update_lod_levels() оскільки він нічого не робить
	# if player:
	# 	update_lod_levels()
	pass

func update_lod_levels():
	"""Оновлення LOD рівнів залежно від відстані до гравця
	
	ВАЖЛИВО: Заглушка - не реалізовано.
	Поки що не інтегровано з ChunkManager.
	"""
	# Заглушка для LOD системи
	# Реалізація буде залежати від chunking системи
	pass

func get_lod_level_for_distance(distance: float) -> int:
	"""Отримати LOD рівень для заданої відстані
	
	ВАЖЛИВО: Метод працює, але не використовується, оскільки
	apply_lod_to_chunk() є заглушкою.
	"""
	for i in range(lod_distances.size()):
		if distance <= lod_distances[i]:
			return i
	return lod_distances.size()  # Найнижчий LOD

func apply_lod_to_chunk(chunk_pos: Vector2i, lod_level: int):
	"""Застосувати LOD до чанка
	
	ВАЖЛИВО: Заглушка - не реалізовано.
	Поки що не інтегровано з ChunkManager.
	"""
	# Заглушка - не робить нічого
	# Для реалізації потрібно інтегрувати з ChunkManager._create_chunk_generation_job()
	pass
