extends Node
class_name DetailLayerManager

# Модуль для detail layers - рослинність та деталі на поверхні
# Вдохновлено zylann.hterrain

@export_group("Detail Settings")
@export var detail_texture: Texture2D  # Текстура для detail layer
@export var detail_scale := 5.0  # Масштаб detail текстури
@export var detail_strength := 1.0  # Сила впливу detail
@export var detail_distance := 100.0  # Відстань видимості detail

@export_group("Grass Settings")
@export var grass_mesh: Mesh  # Mesh для трави
@export var grass_density := 0.5  # Щільність трави
@export var grass_height := 1.0  # Висота трави
@export var grass_width := 0.1  # Ширина трави

var detail_material: ShaderMaterial
var grass_multimesh: MultiMeshInstance3D
var chunk_grass_data: Dictionary = {}  # chunk_pos -> {"start_index": int, "count": int}
var total_grass_instances: int = 0  # Загальна кількість інстансів трави

func _ready():
	setup_detail_material()
	setup_grass_multimesh()

func setup_detail_material():
	"""Налаштування матеріалу для detail layer"""
	detail_material = ShaderMaterial.new()

	var shader_code = """
	shader_type spatial;
	render_mode blend_mix, depth_draw_opaque, cull_back;

	uniform sampler2D detail_texture;
	uniform float detail_scale = 5.0;
	uniform float detail_strength = 1.0;

	void fragment() {
		vec2 detail_uv = UV * detail_scale;
		vec4 detail = texture(detail_texture, detail_uv);

		// Модифікуємо albedo на основі detail текстури
		ALBEDO *= mix(vec3(1.0), detail.rgb, detail_strength);
	}
	"""

	var shader = Shader.new()
	shader.code = shader_code
	detail_material.shader = shader

	if detail_texture:
		detail_material.set_shader_parameter("detail_texture", detail_texture)

	detail_material.set_shader_parameter("detail_scale", detail_scale)
	detail_material.set_shader_parameter("detail_strength", detail_strength)

func setup_grass_multimesh():
	"""Налаштування multimesh для трави"""
	if not grass_mesh:
		# Створюємо простий grass mesh
		var grass_quad = QuadMesh.new()
		grass_quad.size = Vector2(grass_width, grass_height)
		grass_mesh = grass_quad

	grass_multimesh = MultiMeshInstance3D.new()
	grass_multimesh.multimesh = MultiMesh.new()
	grass_multimesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	grass_multimesh.multimesh.mesh = grass_mesh
	grass_multimesh.multimesh.instance_count = 0  # Буде встановлено пізніше

	# ВИПРАВЛЕНО: Безпечне додавання до сцени
	var parent_node = get_parent()
	if not parent_node:
		push_error("[DetailLayerManager] setup_grass_multimesh: Немає батьківського вузла")
		return
	
	# Шукаємо TerrainGenerator або World вузол
	var target_parent = parent_node
	if parent_node.get_parent():
		target_parent = parent_node.get_parent()
	
	if target_parent and is_instance_valid(target_parent):
		target_parent.add_child(grass_multimesh)
		grass_multimesh.name = "GrassMultiMesh"
	else:
		push_error("[DetailLayerManager] setup_grass_multimesh: Не вдалося знайти валідний батьківський вузол для grass_multimesh")

func generate_detail_layer_for_chunk(chunk_pos: Vector2i, gridmap: GridMap):
	"""Генерація detail layer для чанка"""
	if not detail_material:
		return

	# Тут можна додати логіку для накладання detail матеріалу на чанк
	# Спрощена версія - поки що тільки логування
	print("DetailLayerManager: Detail layer для чанка ", chunk_pos)

func generate_grass_for_chunk(chunk_pos: Vector2i, gridmap: GridMap):
	"""Генерація трави для чанка"""
	if not grass_multimesh or not grass_mesh:
		return

	# ВИПРАВЛЕНО: Отримуємо chunk_size з батьківського TerrainGenerator
	var chunk_size = Vector2i(50, 50)  # Дефолт
	if get_parent() and get_parent().has_method("get_chunk_size"):
		chunk_size = get_parent().get_chunk_size()
	elif get_parent() and "chunk_size" in get_parent():
		chunk_size = get_parent().chunk_size

	var chunk_world_pos = chunk_pos * chunk_size
	var grass_positions = PackedVector3Array()

	# Генеруємо позиції трави
	for x in range(chunk_world_pos.x, chunk_world_pos.x + chunk_size.x, 2):
		for z in range(chunk_world_pos.y, chunk_world_pos.y + chunk_size.y, 2):
			if randf() > grass_density:
				continue

			var height = get_terrain_height_at(x, z)
			if height > 0:  # Трава тільки на поверхні
				var grass_pos = Vector3(x, height, z)
				grass_positions.append(grass_pos)

	# ВИПРАВЛЕНО: Зберігаємо інформацію про траву для чанка
	if grass_positions.size() > 0:
		var start_index = total_grass_instances
		var new_total = total_grass_instances + grass_positions.size()
		
		# Збільшуємо instance_count одразу
		grass_multimesh.multimesh.instance_count = new_total

		# Додаємо нові інстанси
		for i in range(grass_positions.size()):
			var pos = grass_positions[i]
			var instance_index = start_index + i

			# Випадкова трансформація
			var basis = Basis()
			basis = basis.rotated(Vector3.UP, randf_range(0, PI * 2))
			basis = basis.scaled(Vector3(1, randf_range(0.8, 1.2), 1))

			var transform = Transform3D(basis, pos)
			grass_multimesh.multimesh.set_instance_transform(instance_index, transform)

		# Зберігаємо дані для можливості видалення
		chunk_grass_data[chunk_pos] = {
			"start_index": start_index,
			"count": grass_positions.size()
		}
		total_grass_instances = new_total

		print("DetailLayerManager: Згенеровано ", grass_positions.size(), " травинок для чанка ", chunk_pos, " (загалом: ", new_total, ")")

func get_terrain_height_at(x: int, z: int) -> float:
	"""Отримати висоту місцевості з fallback"""
	# ВИПРАВЛЕНО: Додано fallback та перевірку наявності методу
	if get_parent() and get_parent().procedural_module:
		if get_parent().procedural_module.has_method("get_height_at"):
			var height = get_parent().procedural_module.get_height_at(x, z)
			if height > 0:
				return height
	
	# Fallback: використовуємо GridMap якщо доступний
	if get_parent() and get_parent().target_gridmap:
		var gridmap = get_parent().target_gridmap
		if is_instance_valid(gridmap):
			# Шукаємо найвищий блок в колонці
			var max_height = 0
			if get_parent().has_method("get_max_height"):
				max_height = get_parent().get_max_height()
			else:
				max_height = 192  # Дефолт
			
			for y in range(max_height - 1, -64, -1):
				var cell_item = gridmap.get_cell_item(Vector3i(x, y, z))
				if cell_item >= 0:
					return float(y + 1)  # Поверхня блоку
	
	# Останній fallback
	return 5.0

func apply_detail_to_mesh(mesh_instance: MeshInstance3D):
	"""Застосування detail матеріалу до mesh"""
	if detail_material:
		mesh_instance.set_surface_override_material(0, detail_material)

func set_detail_visibility_distance(distance: float):
	"""Встановлення відстані видимості detail"""
	detail_distance = distance
	if grass_multimesh:
		grass_multimesh.visibility_range_end = distance
		grass_multimesh.visibility_range_begin = distance * 0.1
		grass_multimesh.visibility_range_end_margin = distance * 0.1

func update_detail_layer(chunk_pos: Vector2i, gridmap: GridMap):
	"""Оновлення detail layer для чанка"""
	generate_detail_layer_for_chunk(chunk_pos, gridmap)
	generate_grass_for_chunk(chunk_pos, gridmap)

func remove_detail_for_chunk(chunk_pos: Vector2i):
	"""Видалення detail layer для чанка"""
	remove_grass_for_chunk(chunk_pos)
	print("DetailLayerManager: Detail видалено для чанка ", chunk_pos)

func remove_grass_for_chunk(chunk_pos: Vector2i):
	"""Видалення трави для чанка"""
	if not grass_multimesh or not chunk_grass_data.has(chunk_pos):
		return

	var grass_data = chunk_grass_data[chunk_pos]
	var start_index = grass_data["start_index"]
	var count = grass_data["count"]

	# ВИПРАВЛЕНО: Видаляємо інстанси трави для чанка
	# Переміщуємо всі інстанси після видаленого діапазону назад
	var current_count = grass_multimesh.multimesh.instance_count
	var new_count = current_count - count

	if new_count < 0:
		new_count = 0

	# ВИПРАВЛЕНО: Правильне переміщення інстансів
	# Спочатку збираємо всі інстанси, які потрібно перемістити
	var instances_to_move: Array[Dictionary] = []
	for check_pos in chunk_grass_data.keys():
		var check_data = chunk_grass_data[check_pos]
		if check_pos != chunk_pos and check_data["start_index"] > start_index:
			instances_to_move.append({
				"chunk_pos": check_pos,
				"data": check_data
			})
	
	# Сортуємо за start_index
	instances_to_move.sort_custom(func(a, b): return a["data"]["start_index"] < b["data"]["start_index"])

	# Переміщуємо інстанси назад
	var move_index = start_index
	for item in instances_to_move:
		var check_data = item["data"]
		var old_start = check_data["start_index"]
		
		# Переміщуємо всі інстанси цього чанка
		for i in range(check_data["count"]):
			var old_index = old_start + i
			var new_index = move_index + i
			if old_index < current_count:
				var transform = grass_multimesh.multimesh.get_instance_transform(old_index)
				grass_multimesh.multimesh.set_instance_transform(new_index, transform)
		
		# Оновлюємо індекси в chunk_grass_data
		check_data["start_index"] = move_index
		move_index += check_data["count"]

	# Оновлюємо загальну кількість
	grass_multimesh.multimesh.instance_count = new_count
	total_grass_instances = new_count

	# Видаляємо дані чанка
	chunk_grass_data.erase(chunk_pos)

	print("DetailLayerManager: Видалено ", count, " травинок для чанка ", chunk_pos, " (залишилось: ", new_count, ")")
