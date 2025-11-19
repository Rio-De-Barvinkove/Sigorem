extends VoxelGeneratorScript
class_name VoxelGeneratorAdapter

# Адаптер для генерації воксельного світу, використовуючи логіку ProceduralGeneration.gd

var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var cave_noise: FastNoiseLite
var height_amplitude := 32
var base_height := 16
var max_height := 128
var biome_scale := 100.0

# TYPE channel for blocky terrain
const CHANNEL_TYPE = VoxelBuffer.CHANNEL_TYPE

# Block type IDs (matching assets/voxel_library.tres)
const BLOCK_AIR = 0
const BLOCK_STONE = 1
const BLOCK_DIRT = 2
const BLOCK_GRASS = 3
const BLOCK_ROCK = 4

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

	cave_noise = FastNoiseLite.new()
	cave_noise.seed = noise.seed + 4242
	cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cave_noise.frequency = 0.02
	cave_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	cave_noise.fractal_octaves = 3

func _get_used_channels_mask() -> int:
	return 1 << CHANNEL_TYPE

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int):
	var size := out_buffer.get_size()
	var size_x := size.x
	var size_y := size.y
	var size_z := size.z

	# Проходимо по всіх вокселях в блоці
	# Важливо: origin вже враховує LOD від VoxelLodTerrain, тому просто додаємо локальні координати
	for x in range(0, size_x, 1):
		var world_x = origin.x + x
		for z in range(0, size_z, 1):
			var world_z = origin.z + z

			# Отримуємо біом для цієї координати
			var biome_data = _get_biome_at_position(world_x, world_z)

			# Отримуємо висоту поверхні (округлюємо до цілого для блочного стилю)
			var surface_height = int(_get_height_at(world_x, world_z, biome_data))

			# Генеруємо блоки для кожного Y рівня в цьому стовпчику
			for y in range(0, size_y, 1):
				var world_y = origin.y + y
				var block_type = BLOCK_AIR

				# Визначаємо тип блоку на основі висоти
				if world_y <= 2:
					# Базальтовий шар на дні
					block_type = BLOCK_STONE
				elif world_y < surface_height - 3:
					# Камінь глибоко під землею
					block_type = BLOCK_STONE
				elif world_y < surface_height:
					# Земля під поверхнею
					block_type = BLOCK_DIRT
				elif world_y == surface_height:
					# Поверхня - залежить від біому
					var biome_name = biome_data.get("name", "plains")
					if biome_name == "desert":
						block_type = BLOCK_ROCK
					else:
						block_type = BLOCK_GRASS
				else:
					# Повітря над поверхнею
					block_type = BLOCK_AIR

				# Для печер: якщо шум негативний в певному діапазоні, створюємо порожнину
				var cave_value = cave_noise.get_noise_3d(world_x * 0.05, world_y * 0.05, world_z * 0.05)
				if cave_value < -0.3 and world_y < surface_height - 5 and block_type != BLOCK_AIR:
					block_type = BLOCK_AIR  # Повітря всередині печери

				out_buffer.set_voxel(block_type, x, y, z, CHANNEL_TYPE)

func _get_height_at(x: int, z: int, biome_data: Dictionary) -> float:
	var height_modifier = biome_data.get("height_modifier", 0.0)
	var surface_roughness = biome_data.get("surface_roughness", 1.0)
	var raw_height = noise.get_noise_2d(x, z) * height_amplitude * surface_roughness * (1.0 + height_modifier) + base_height
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
			"name": "plains",
			"height_modifier": 0.0,
			"surface_roughness": 1.0
		},
		"forest": {
			"name": "forest",
			"height_modifier": 0.5,
			"surface_roughness": 1.2
		},
		"desert": {
			"name": "desert",
			"height_modifier": -0.2,
			"surface_roughness": 0.8
		},
		"mountains": {
			"name": "mountains",
			"height_modifier": 2.0,
			"surface_roughness": 1.5
		}
	}
	return biomes.get(biome_name, biomes["plains"])
