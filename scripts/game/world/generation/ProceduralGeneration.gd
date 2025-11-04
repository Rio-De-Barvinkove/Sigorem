extends Node
class_name ProceduralGeneration

# Модуль для базової процедурної генерації терейну з шуму

var noise: FastNoiseLite
var height_amplitude := 5
var base_height := 5

func _ready():
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.05

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

func generate_chunk(gridmap: GridMap, chunk_pos: Vector2i):
	"""Генерація окремого чанка"""
	var chunk_start = chunk_pos * Vector2i(50, 50)  # Припускаємо chunk_size = 50x50
	var chunk_size = Vector2i(50, 50)

	generate_terrain(gridmap, chunk_start, chunk_size)

func get_height_at(x: int, z: int) -> int:
	"""Отримати висоту терейну в точці"""
	if not noise:
		return base_height
	return int(noise.get_noise_2d(x, z) * height_amplitude) + base_height
