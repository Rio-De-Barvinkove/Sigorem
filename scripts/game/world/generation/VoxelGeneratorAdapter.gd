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

# SDF channel for smooth terrain
const CHANNEL_SDF = VoxelBuffer.CHANNEL_SDF

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
	return 1 << CHANNEL_SDF

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int):
	var size := out_buffer.get_size()
	var size_x := size.x
	var size_y := size.y
	var size_z := size.z

	var start_x := origin.x
	var start_y := origin.y
	var start_z := origin.z

	# LOD scaling - for higher LOD levels, we use larger steps
	var lod_scale := 1 << lod

	# Проходимо по всіх вокселях в блоці
	for x in range(0, size_x, lod_scale):
		var world_x = start_x + x
		for z in range(0, size_z, lod_scale):
			var world_z = start_z + z

			# Отримуємо біом для цієї координати
			var biome_data = _get_biome_at_position(world_x, world_z)

			# Отримуємо висоту поверхні
			var surface_height = _get_height_at(world_x, world_z, biome_data)

			# Генеруємо SDF для кожного Y рівня в цьому стовпчику
			for y in range(0, size_y, lod_scale):
				var world_y = start_y + y

				# Розраховуємо signed distance до поверхні
				var distance_to_surface = float(world_y) - surface_height

				# Додаємо невеликий шум для більш природного вигляду
				var surface_noise = noise.get_noise_3d(world_x * 0.1, world_y * 0.1, world_z * 0.1) * 2.0
				distance_to_surface += surface_noise

				# Для печер: якщо шум негативний в певному діапазоні, створюємо порожнину
				var cave_value = cave_noise.get_noise_3d(world_x * 0.05, world_y * 0.05, world_z * 0.05)
				if cave_value < -0.3 and world_y < surface_height - 5:
					distance_to_surface = 1.0  # Повітря всередині печери

				# Базальтовий шар на дні
				if world_y <= 2:
					distance_to_surface = -1.0  # Завжди всередині

				out_buffer.set_voxel_f(distance_to_surface, x, y, z, CHANNEL_SDF)

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
			"height_modifier": 0.0,
			"surface_roughness": 1.0
		},
		"forest": {
			"height_modifier": 0.5,
			"surface_roughness": 1.2
		},
		"desert": {
			"height_modifier": -0.2,
			"surface_roughness": 0.8
		},
		"mountains": {
			"height_modifier": 2.0,
			"surface_roughness": 1.5
		}
	}
	return biomes.get(biome_name, biomes["plains"])
