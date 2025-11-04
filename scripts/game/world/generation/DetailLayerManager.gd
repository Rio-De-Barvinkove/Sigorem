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

	# Додамо до сцени
	if get_parent() and get_parent().get_parent():
		get_parent().get_parent().add_child(grass_multimesh)

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

	var chunk_size = Vector2i(50, 50)  # Розмір чанка
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

	# Налаштовуємо multimesh
	if grass_positions.size() > 0:
		grass_multimesh.multimesh.instance_count = grass_positions.size()

		for i in range(grass_positions.size()):
			var pos = grass_positions[i]

			# Випадкова трансформація
			var basis = Basis()
			basis = basis.rotated(Vector3.UP, randf_range(0, PI * 2))
			basis = basis.scaled(Vector3(1, randf_range(0.8, 1.2), 1))

			var transform = Transform3D(basis, pos)
			grass_multimesh.multimesh.set_instance_transform(i, transform)

		print("DetailLayerManager: Згенеровано ", grass_positions.size(), " травинок для чанка ", chunk_pos)

func get_terrain_height_at(x: int, z: int) -> float:
	"""Отримати висоту місцевості"""
	if get_parent() and get_parent().procedural_module:
		return get_parent().procedural_module.get_height_at(x, z)
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
	# Тут можна додати логіку очищення detail для чанка
	print("DetailLayerManager: Detail видалено для чанка ", chunk_pos)
