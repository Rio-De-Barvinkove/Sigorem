extends GridMap

const MAP_SIZE = Vector2i(50, 50)
var noise: FastNoiseLite

@export_group("Terrain Generation")
@export var use_procedural = true
@export var flat_height = 5
@export var noise_amplitude = 5
@export var base_height = 5

func _ready():
	# Встановлюємо MeshLibrary з BlockRegistry (автолоад завжди готовий)
	var mesh_lib = BlockRegistry.get_mesh_library()
	if mesh_lib:
		mesh_library = mesh_lib
		print("GridMap MeshLibrary set, items: ", mesh_library.get_item_list().size())
		print("GridMap cell_size: ", cell_size)
	else:
		push_error("BlockRegistry MeshLibrary not available!")
		return
	
	# Чекаємо один кадр щоб бути впевненим що все завантажене
	await get_tree().process_frame
	
	# Генеруємо терейн
	if use_procedural:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.05
		generate_terrain_with_height()
	else:
		generate_flat_terrain()
	
	print("Terrain generation complete!")

func generate_terrain_with_height():
	clear()
	for x in range(MAP_SIZE.x):
		for z in range(MAP_SIZE.y):
			var height = int(noise.get_noise_2d(x, z) * noise_amplitude) + base_height
			for y in range(height):
				var block_id: String
				if y < height - 2:
					block_id = "stone"
				elif y < height - 1:
					block_id = "dirt"
				else:
					block_id = "grass"
				
				var mesh_index = BlockRegistry.get_mesh_index(block_id)
				if mesh_index >= 0:
					set_cell_item(Vector3i(x, y, z), mesh_index)

func generate_flat_terrain():
	clear()
	for x in range(MAP_SIZE.x):
		for z in range(MAP_SIZE.y):
			for y in range(flat_height):
				var block_id: String
				if y < flat_height - 2:
					block_id = "stone"
				elif y < flat_height - 1:
					block_id = "dirt"
				else:
					block_id = "grass"
				
				var mesh_index = BlockRegistry.get_mesh_index(block_id)
				if mesh_index >= 0:
					set_cell_item(Vector3i(x, y, z), mesh_index)


