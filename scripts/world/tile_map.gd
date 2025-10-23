extends GridMap

const MAP_SIZE = Vector2i(50, 50)
var noise: FastNoiseLite

@export var grass_block_id = 0
@export var dirt_block_id = 1
@export var stone_block_id = 2

func _ready():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05
	generate_terrain_with_height()

func generate_terrain_with_height():
	clear() # Clear the old flat terrain
	for x in range(MAP_SIZE.x):
		for z in range(MAP_SIZE.y):
			var height = int(noise.get_noise_2d(x, z) * 5) + 5
			for y in range(height):
				var block_type
				if y < height - 2:
					block_type = stone_block_id
				elif y < height -1:
					block_type = dirt_block_id
				else:
					block_type = grass_block_id
				set_cell_item(Vector3i(x, y, z), block_type)
