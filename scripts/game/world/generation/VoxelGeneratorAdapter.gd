extends VoxelGeneratorScript
class_name VoxelGeneratorAdapter

# Адаптер для генерації воксельного світу, використовуючи логіку ProceduralGeneration.gd

var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var height_amplitude := 32
var base_height := 16
var max_height := 128
var biome_scale := 100.0

# IDs from VoxelLibrary
const CHANNEL_TYPE = VoxelBuffer.CHANNEL_TYPE
const AIR = 0
const STONE = 1
const DIRT = 2
const GRASS = 3
const BEDROCK = 4

func _init():
	resource_name = "VoxelGeneratorAdapter"
	_setup_noise()

func _setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.005 
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = noise.seed + 9137
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	biome_noise.frequency = 1.0 / max(biome_scale, 0.001)
	biome_noise.fractal_octaves = 1

func _get_used_channels_mask() -> int:
	return 1 << CHANNEL_TYPE

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int):
	var size := out_buffer.get_size()
	var size_x := size.x
	var size_y := size.y
	var size_z := size.z
	
	var start_x := origin.x
	var start_y := origin.y
	var start_z := origin.z
	
	# Проходимо по X та Z (стовпчики)
	for x in range(size_x):
		var world_x = start_x + x
		for z in range(size_z):
			var world_z = start_z + z
			
			# Отримуємо біом для цієї координати
			var biome_data = _get_biome_at_position(world_x, world_z)
			
			# Отримуємо висоту поверхні
			var height = _get_height_at(world_x, world_z, biome_data)
			
			# Переводимо в локальні координати буфера
			var local_height = height - start_y
			
			# Якщо весь стовпчик під землею
			if local_height >= size_y:
				var surface_block = _get_block_id(biome_data.get("surface_block", "grass"))
				var dirt_block = _get_block_id(biome_data.get("dirt_block", "dirt"))
				var stone_block = _get_block_id(biome_data.get("stone_block", "stone"))
				
				for y in range(size_y):
					var world_y = start_y + y
					var voxel_id = stone_block
					if world_y == height:
						voxel_id = surface_block
					elif world_y > height - 4:
						voxel_id = dirt_block
					
					out_buffer.set_voxel(voxel_id, x, y, z, CHANNEL_TYPE)
			
			# Якщо весь стовпчик над землею
			elif local_height < 0:
				continue
				
			# Змішаний випадок
			else:
				var surface_block = _get_block_id(biome_data.get("surface_block", "grass"))
				var dirt_block = _get_block_id(biome_data.get("dirt_block", "dirt"))
				var stone_block = _get_block_id(biome_data.get("stone_block", "stone"))

				for y in range(local_height + 1):
					var world_y = start_y + y
					var voxel_id = stone_block
					
					if world_y == height:
						voxel_id = surface_block
					elif world_y > height - 4:
						voxel_id = dirt_block
					
					if world_y == 0:
						voxel_id = BEDROCK
						
					out_buffer.set_voxel(voxel_id, x, y, z, CHANNEL_TYPE)

func _get_height_at(x: int, z: int, biome_data: Dictionary) -> int:
	var height_modifier = biome_data.get("height_modifier", 0.0)
	var raw_height = int(noise.get_noise_2d(x, z) * height_amplitude * (1.0 + height_modifier)) + base_height
	return raw_height

func _get_biome_at_position(x: int, z: int) -> Dictionary:
	var scale = max(0.001, biome_scale)
	var biome_value = biome_noise.get_noise_2d(x / scale, z / scale)
	
	if biome_value < -0.5:
		return _get_biome_data("desert")
	elif biome_value < 0.0:
		return _get_biome_data("plains")
	elif biome_value < 0.5:
		return _get_biome_data("forest")
	else:
		return _get_biome_data("mountains")

func _get_biome_data(biome_name: String) -> Dictionary:
	var biomes = {
		"plains": {
			"surface_block": "grass",
			"dirt_block": "dirt",
			"stone_block": "stone",
			"height_modifier": 0.0
		},
		"forest": {
			"surface_block": "grass",
			"dirt_block": "dirt",
			"stone_block": "stone",
			"height_modifier": 0.5
		},
		"desert": {
			"surface_block": "sand", # fallback to dirt if sand not def defined
			"dirt_block": "sand",
			"stone_block": "stone",
			"height_modifier": -0.2
		},
		"mountains": {
			"surface_block": "stone",
			"dirt_block": "dirt",
			"stone_block": "stone",
			"height_modifier": 2.0
		}
	}
	return biomes.get(biome_name, biomes["plains"])

func _get_block_id(block_name: String) -> int:
	match block_name:
		"grass": return GRASS
		"dirt": return DIRT
		"stone": return STONE
		"sand": return DIRT # Use dirt for sand for now
		_: return STONE
