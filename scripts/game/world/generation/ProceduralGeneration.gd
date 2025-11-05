extends Node
class_name ProceduralGeneration

# Модуль для базової процедурної генерації терейну з шуму

var noise: FastNoiseLite
var height_amplitude := 5
var base_height := 5

# Додаткові шари шуму (з infinite_heightmap_terrain)
@export var extra_terrain_noise_layers: Array[FastNoiseLite] = []
@export var terrain_height_multiplier: float = 150.0
@export var terrain_height_offset: float = 0.0

# Налаштування кольорів (з infinite_heightmap_terrain)
@export var two_colors := true
@export var terrain_color_steepness_curve: Curve
@export var terrain_level_color: Color = Color.DARK_OLIVE_GREEN
@export var terrain_cliff_color: Color = Color.DIM_GRAY
@export var terrain_material: StandardMaterial3D

func _ready():
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.05

	if not terrain_color_steepness_curve:
		terrain_color_steepness_curve = Curve.new()
		terrain_color_steepness_curve.add_point(Vector2(0.0, 0.0))
		terrain_color_steepness_curve.add_point(Vector2(1.0, 1.0))

	if not terrain_material:
		terrain_material = StandardMaterial3D.new()
		terrain_material.vertex_color_use_as_albedo = true

func generate_terrain(gridmap: GridMap, start_pos: Vector2i, size: Vector2i):
	"""Генерація терейну в заданій області"""
	if not gridmap or not noise:
		push_error("ProceduralGeneration: GridMap або noise не встановлені!")
		return

	print("ProceduralGeneration: Генерація терейну від ", start_pos, " розміром ", size)

	for x in range(start_pos.x, start_pos.x + size.x):
		for z in range(start_pos.y, start_pos.y + size.y):
			var height = int(noise.get_noise_2d(x, z) * height_amplitude) + base_height

			for y in range(height):
				var block_id: String

				# Визначення типу блоку залежно від висоти
				if y < height - 2:
					block_id = "stone"
				elif y < height - 1:
					block_id = "dirt"
				else:
					block_id = "grass"

				var mesh_index = BlockRegistry.get_mesh_index(block_id)
				if mesh_index >= 0:
					gridmap.set_cell_item(Vector3i(x, y, z), mesh_index)

func generate_chunk(gridmap: GridMap, chunk_pos: Vector2i, optimization: Dictionary = {}):
	"""Генерація окремого чанка з оптимізацією"""
	var chunk_start = chunk_pos * Vector2i(50, 50)  # Припускаємо chunk_size = 50x50
	var chunk_size = Vector2i(50, 50)
	
	# Застосовуємо оптимізацію якщо вона є
	var resolution = optimization.get("resolution", 1.0)
	if resolution < 1.0:
		# Зменшуємо розмір чанка або деталізацію
		chunk_size = Vector2i(int(chunk_size.x * resolution), int(chunk_size.y * resolution))

	generate_terrain(gridmap, chunk_start, chunk_size)

func get_height_at(x: int, z: int) -> int:
	"""Отримати висоту терейну в точці"""
	if not noise:
		return base_height
	return int(sample_2dv(Vector2(x, z)) * height_amplitude) + base_height

func sample_2dv(point: Vector2) -> float:
	"""Семплінг шуму з додатковими шарами (з infinite_heightmap_terrain)"""
	var value: float = noise.get_noise_2dv(point)

	for extra_noise in extra_terrain_noise_layers:
		value += extra_noise.get_noise_2dv(point)

	return value
