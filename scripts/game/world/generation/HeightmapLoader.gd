extends Node
class_name HeightmapLoader

# Модуль для роботи з heightmap текстурами (з Procedural-Terrain-Generator)

@export var heightmap: Texture2D
@export var height_scale: float = 5.0
@export var mesh_size: Vector2 = Vector2(100.0, 100.0)
@export var subdivides: int = 50

var image_data: Image

func _ready():
	if heightmap:
		load_heightmap()

func load_heightmap() -> bool:
	"""Завантаження heightmap текстури"""
	if not heightmap:
		push_error("HeightmapLoader: Heightmap не встановлений!")
		return false

	image_data = heightmap.get_image()
	if not image_data:
		push_error("HeightmapLoader: Не вдалося отримати image з текстури!")
		return false

	# Конвертуємо в підтримуваний формат
	image_data.convert(Image.FORMAT_RGB8)

	print("HeightmapLoader: Завантажено heightmap ", image_data.get_size())
	return true

func get_height_from_image(uv: Vector2) -> float:
	"""Отримати висоту з heightmap в нормалізованих координатах UV (0-1)"""
	if not image_data:
		return 0.0

	# Перетворюємо UV в піксельні координати
	var pixel_x = int(uv.x * (image_data.get_width() - 1))
	var pixel_y = int(uv.y * (image_data.get_height() - 1))

	# Клапимо координати
	pixel_x = clamp(pixel_x, 0, image_data.get_width() - 1)
	pixel_y = clamp(pixel_y, 0, image_data.get_height() - 1)

	# Отримуємо колір пікселя
	var pixel_color = image_data.get_pixel(pixel_x, pixel_y)

	# Використовуємо червоний канал як висоту (0-1)
	return pixel_color.r * height_scale

func get_height_at_position(world_pos: Vector2, terrain_size: Vector2) -> float:
	"""Отримати висоту в світових координатах"""
	if not image_data:
		return 0.0

	# Перетворюємо світові координати в UV
	var uv = Vector2(
		(world_pos.x / terrain_size.x + 0.5),  # -terrain_size.x/2 до +terrain_size.x/2 -> 0 до 1
		(world_pos.y / terrain_size.y + 0.5)
	)

	# Клапимо UV координати
	uv.x = clamp(uv.x, 0.0, 1.0)
	uv.y = clamp(uv.y, 0.0, 1.0)

	return get_height_from_image(uv)

func generate_mesh_from_heightmap() -> Mesh:
	"""Генерація mesh з heightmap (як у Procedural-Terrain-Generator)"""
	if not image_data:
		push_error("HeightmapLoader: Немає heightmap для генерації mesh!")
		return null

	var plane = PlaneMesh.new()
	plane.subdivide_depth = subdivides
	plane.subdivide_width = subdivides

	var img_size = image_data.get_size()
	var aspect_ratio = float(img_size.x) / float(img_size.y)

	plane.size = Vector2(mesh_size.x, mesh_size.y * aspect_ratio)

	var arrays = ArrayMesh.new()
	var mesh_data = plane.get_mesh_arrays()

	var vertices: PackedVector3Array = mesh_data[Mesh.ARRAY_VERTEX]

	for i in range(vertices.size()):
		var vertex = vertices[i]

		# Перетворюємо координати вертекса в UV
		var uv = Vector2(
			(vertex.x / plane.size.x) + 0.5,
			(vertex.z / plane.size.y) + 0.5
		)

		# Отримуємо висоту з heightmap
		vertex.y = get_height_from_image(uv)

		vertices[i] = vertex

	# Оновлюємо mesh data
	mesh_data[Mesh.ARRAY_VERTEX] = vertices

	var new_mesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data)

	# Генеруємо нормалі
	var tool = SurfaceTool.new()
	tool.create_from(new_mesh, 0)
	tool.generate_normals()
	var final_mesh = tool.commit()

	print("HeightmapLoader: Згенеровано mesh з heightmap")
	return final_mesh

func save_mesh(mesh: Mesh, path: String):
	"""Збереження mesh (як у Procedural-Terrain-Generator)"""
	if not mesh:
		push_error("HeightmapLoader: Mesh не існує!")
		return

	var error = ResourceSaver.save(mesh, path)

	if error == OK:
		print("HeightmapLoader: Mesh збережено в: ", path)
	else:
		push_error("HeightmapLoader: Помилка збереження mesh: ", error)
