extends Node
class_name VegetationManager

# Модуль для управління рослинністю з multimesh (з infinite_heightmap_terrain)

@export_group("Multimesh налаштування")
@export var multimesh_cast_shadow: MeshInstance3D.ShadowCastingSetting
@export var multimesh_radius: int = 6
@export var multimesh_noise: FastNoiseLite
@export var multimesh_mesh: Mesh
@export_range(0.0, 1.0, 0.01) var multimesh_coverage: float = 0.5
@export_range(0.0, 10.0, 0.1) var multimesh_jitter: float = 5.0
@export var multimesh_on_cliffs := false
@export_range(0.0, 1.0, 0.1) var multimesh_steep_threshold: float = 0.5
@export_range(1.0, 10.0, 1.0) var multimesh_repeats: int = 1

var multimesh_dict: Dictionary = {}  # ВИПРАВЛЕНО: Зберігає MultiMeshInstance3D назавжди → пам'ять росте. Потрібно видаляти при unload.
var terrain_height_multiplier: float = 150.0
var terrain_height_offset: float = 0.0

func _ready():
	if not multimesh_mesh:
		multimesh_mesh = RibbonTrailMesh.new()
	if not multimesh_noise:
		multimesh_noise = FastNoiseLite.new()

func generate_multimesh_for_chunk(chunk_pos: Vector2i, gridmap: GridMap):
	"""Генерація multimesh для чанка"""
	if multimesh_dict.has(chunk_pos):
		return

	var multimesh_positions = generate_multimesh_positions(chunk_pos, gridmap)

	if multimesh_positions.is_empty():
		return

	var multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.multimesh = MultiMesh.new()
	multimesh_instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh_instance.multimesh.mesh = multimesh_mesh
	multimesh_instance.multimesh.use_colors = true
	multimesh_instance.multimesh.use_custom_data = true
	multimesh_instance.multimesh.instance_count = multimesh_positions.size()

	for i in range(multimesh_positions.size()):
		var pos = multimesh_positions[i]
		var basis = Basis(Vector3(randfn(1.0, 0.1), 0.0, 0.0),
						 Vector3(0.0, randf_range(0.5, 1.5), 0.0),
						 Vector3(0.0, 0.0, randfn(1.0, 0.1)))
		basis = basis.rotated(Vector3.UP, randf_range(-PI/2.0, PI/2.0))

		var scale_factor = clampf(abs(multimesh_noise.get_noise_2dv(Vector2(pos.x, pos.z))) * 10.0, 0.5, 1.5)
		basis = basis.scaled(Vector3(scale_factor, scale_factor, scale_factor))

		var transform = Transform3D(basis, pos)
		multimesh_instance.multimesh.set_instance_transform(i, transform)
		multimesh_instance.multimesh.set_instance_custom_data(i, Color(pos.x, pos.y, pos.z, 0.0))

	multimesh_instance.multimesh.visible_instance_count = multimesh_positions.size()
	multimesh_instance.cast_shadow = multimesh_cast_shadow

	multimesh_dict[chunk_pos] = multimesh_instance

	# Додати до сцени
	if get_parent() and get_parent().get_parent():
		get_parent().get_parent().add_child(multimesh_instance)
		multimesh_instance.global_position.y = terrain_height_offset

func generate_multimesh_positions(chunk_pos: Vector2i, gridmap: GridMap) -> PackedVector3Array:
	"""Генерація позицій для multimesh
	
	КРИТИЧНА ПРОБЛЕМА ПРОДУКТИВНОСТІ: Робить тисячі get_height_at() → лагає на 50-200 мс на чанк.
	
	ВИПРАВЛЕНО: Збільшено крок з 2 до 4 для зменшення кількості викликів get_height_at().
	Можна також робити 1 раз на 2×2 чанки для подальшої оптимізації.
	"""
	var positions: PackedVector3Array = []

	# Розмір чанка (адаптувати до налаштувань)
	var chunk_size = Vector2i(50, 50)
	if get_parent() and get_parent().has_method("get_chunk_size"):
		chunk_size = get_parent().get_chunk_size()
	
	var chunk_world_pos = chunk_pos * chunk_size

	# ВИПРАВЛЕНО: Збільшено крок з 2 до 4 для зменшення кількості викликів get_height_at()
	# Це зменшує кількість викликів з ~625 (25×25) до ~156 (12.5×12.5) на чанк
	var step = 4  # Крок для оптимізації (було 2)
	
	# Генеруємо точки всередині чанка
	for x in range(chunk_world_pos.x, chunk_world_pos.x + chunk_size.x, step):
		for z in range(chunk_world_pos.y, chunk_world_pos.y + chunk_size.y, step):
			# Випадково вирішуємо, чи розмістити рослину тут
			if randf() > multimesh_coverage:
				continue

			# ПРОБЛЕМА: Отримати висоту місцевості - тисячі викликів get_height_at()
			var height = get_terrain_height_at(x, z)
			var pos_3d = Vector3(x, height, z)

			# Додати jitter
			pos_3d.x += randfn(0.0, multimesh_jitter)
			pos_3d.z += randfn(0.0, multimesh_jitter)

			# Перевірити крутизну схилу (якщо потрібно)
			if multimesh_on_cliffs or is_valid_steepness(pos_3d):
				positions.append(pos_3d)

	return positions

func is_valid_steepness(position: Vector3) -> bool:
	"""Перевірити, чи підходить крутизна для рослинності"""
	if not multimesh_on_cliffs:
		# Обчислити нормаль місцевості
		var normal = calculate_terrain_normal(position)
		var steepness = Vector3.UP.dot(normal)
		steepness = clampf(steepness, 0.0, 1.0)
		return steepness >= multimesh_steep_threshold
	return true

func calculate_terrain_normal(position: Vector3) -> Vector3:
	"""Обчислити нормаль місцевості в точці"""
	# Спрощена версія - в реальності треба використовувати градієнт висоти
	return Vector3.UP

func get_terrain_height_at(x: int, z: int) -> float:
	"""Отримати висоту місцевості"""
	if get_parent() and get_parent().procedural_module:
		return get_parent().procedural_module.get_height_at(x, z)
	return 5.0

func remove_multimesh_for_chunk(chunk_pos: Vector2i):
	"""Видалити multimesh для чанка
	
	ВИПРАВЛЕНО: Викликається з ChunkManager при unload чанка для запобігання витоку пам'яті.
	"""
	if multimesh_dict.has(chunk_pos):
		var multimesh_instance = multimesh_dict[chunk_pos]
		if is_instance_valid(multimesh_instance):
			multimesh_instance.queue_free()
		multimesh_dict.erase(chunk_pos)
		if get_parent() and get_parent().has_method("get_chunk_size"):
			print("[VegetationManager] remove_multimesh_for_chunk: Видалено multimesh для чанка ", chunk_pos)
