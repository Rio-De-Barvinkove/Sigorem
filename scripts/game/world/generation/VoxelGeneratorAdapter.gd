@tool
extends VoxelGeneratorScript
class_name VoxelGeneratorAdapter

# Адаптер для генерації воксельного світу, використовуючи логіку ProceduralGeneration.gd

# Багатошарові шуми для плавнішої генерації
var noise: FastNoiseLite  # Основний шум висоти
var macro_noise: FastNoiseLite  # Макро-рельєф (великі форми)
var micro_noise: FastNoiseLite  # Мікро-деталі (дрібні нерівності)
var biome_noise: FastNoiseLite
var temperature_noise: FastNoiseLite  # Температура для біомів
var humidity_noise: FastNoiseLite  # Вологість для біомів
var cave_noise: FastNoiseLite
# Параметри для рівнини з невеликими пагорбами
var height_amplitude := 8  # Невелика амплітуда для низьких пагорбів
var base_height := 10  # Базовий рівень
var max_height := 32  # Максимальна висота (невеликі пагорби)
var biome_scale := 200.0  # Великі біоми для плавних переходів

# Фіксований seed для відтворюваності генерації
@export var world_seed: int = 1337

# TYPE channel for blocky terrain
const CHANNEL_TYPE = VoxelBuffer.CHANNEL_TYPE

# Block type IDs (matching assets/voxel_library.tres)
const BLOCK_AIR = 0
const BLOCK_STONE = 1
const BLOCK_DIRT = 2
const BLOCK_GRASS = 3
const BLOCK_ROCK = 4

# Starting area settings
@export var enable_starting_area := true
@export var starting_area_size := 32  # Розмір стартової зони в блоках
@export var starting_area_height := 16  # Висота платформи

func _init():
	resource_name = "VoxelGeneratorAdapter"
	_setup_noise()

func _setup_noise():
	var base_seed = world_seed
	
	# Макро-рельєф: великі плавні форми для плато
	macro_noise = FastNoiseLite.new()
	macro_noise.seed = base_seed
	macro_noise.frequency = 0.005  # Дуже низька частота для великих плато
	macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	macro_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	macro_noise.fractal_octaves = 4  # Більше октав для плавності
	
	# Основний шум: середні пагорби
	noise = FastNoiseLite.new()
	noise.seed = base_seed + 1000
	noise.frequency = 0.008  # Низька частота для плавних переходів
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5  # Більше октав для плавності
	
	# Мікро-деталі: дрібні нерівності (мінімальний вплив)
	micro_noise = FastNoiseLite.new()
	micro_noise.seed = base_seed + 2000
	micro_noise.frequency = 0.03  # Середня частота
	micro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	micro_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	micro_noise.fractal_octaves = 2

	# Біоми (збільшена шкала для плавніших переходів)
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = base_seed + 9137
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	biome_noise.frequency = 1.0 / max(biome_scale, 0.001)
	biome_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	biome_noise.fractal_octaves = 2  # Збільшено для плавніших переходів
	
	# Температура для біомів
	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = base_seed + 5000
	temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	temperature_noise.frequency = 1.0 / max(biome_scale * 1.5, 0.001)
	temperature_noise.fractal_octaves = 2
	
	# Вологість для біомів
	humidity_noise = FastNoiseLite.new()
	humidity_noise.seed = base_seed + 6000
	humidity_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	humidity_noise.frequency = 1.0 / max(biome_scale * 1.2, 0.001)
	humidity_noise.fractal_octaves = 2

	# Печери
	cave_noise = FastNoiseLite.new()
	cave_noise.seed = base_seed + 4242
	cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cave_noise.frequency = 0.08
	cave_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	cave_noise.fractal_octaves = 3

func _get_used_channels_mask() -> int:
	return 1 << CHANNEL_TYPE

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int):
	var size := out_buffer.get_size()
	var size_x := size.x
	var size_y := size.y
	var size_z := size.z

	# Діагностика - завжди виводимо, щоб перевірити чи викликається
	print("[GEN] _generate_block CALLED: origin=", origin, " size=", size, " lod=", lod)
	
	# Перевірка чи буфер валідний
	if size.x == 0 or size.y == 0 or size.z == 0:
		push_error("VoxelGeneratorAdapter: Invalid buffer size!")
		return

	# Проходимо по всіх вокселях в блоці
	# Важливо: origin вже враховує LOD від VoxelLodTerrain, тому просто додаємо локальні координати
	for x in range(0, size_x, 1):
		var world_x = origin.x + x
		for z in range(0, size_z, 1):
			var world_z = origin.z + z

			# Отримуємо біом для цієї координати
			var biome_data = _get_biome_at_position(world_x, world_z)

			# Отримуємо висоту поверхні з плавною інтерполяцією
			var surface_height_float = _get_height_at(world_x, world_z, biome_data)
			# Використовуємо плавне округлення для більш природних переходів
			var surface_height = int(round(surface_height_float))

			# Генеруємо блоки для кожного Y рівня в цьому стовпчику
			for y in range(0, size_y, 1):
				var world_y = origin.y + y
				var block_type = BLOCK_AIR

				# Перевірка чи ця позиція в стартовій зоні
				var in_starting_area = enable_starting_area and _is_position_in_starting_area(world_x, world_z)

				if in_starting_area:
					# Стартова зона - плоска платформа
					if world_y < starting_area_height - 1:
						# Кам'яна основа
						block_type = BLOCK_STONE
					elif world_y == starting_area_height - 1:
						# Земля
						block_type = BLOCK_DIRT
					elif world_y == starting_area_height:
						# Трава на поверхні
						block_type = BLOCK_GRASS
					else:
						# Повітря над стартовою зоною
						block_type = BLOCK_AIR
				else:
					# Звичайна генерація світу
					# Визначаємо тип блоку на основі висоти з плавними переходами
					var height_diff = surface_height_float - world_y

					if world_y <= 2:
						# Базальтовий шар на дні
						block_type = BLOCK_STONE
					elif world_y < surface_height - 3:
						# Камінь глибоко під землею
						block_type = BLOCK_STONE
					elif height_diff > 0.5:
						# Земля під поверхнею (плавний перехід)
						block_type = BLOCK_DIRT
					elif height_diff > 0.0:
						# Перехідна зона між землею і поверхнею (плавний перехід)
						# Чим ближче до поверхні, тим більше шанс на траву
						if randf() < height_diff * 2.0:
							var biome_name = biome_data.get("name", "plains")
							if biome_name == "desert":
								block_type = BLOCK_ROCK
							else:
								block_type = BLOCK_GRASS
						else:
							block_type = BLOCK_DIRT
					elif height_diff > -0.5:
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
					# Масштаб для мікровокселів (0.25м замість 1м)
					var cave_value = cave_noise.get_noise_3d(world_x * 0.2, world_y * 0.2, world_z * 0.2)
					if cave_value < -0.3 and world_y < surface_height - 5 and block_type != BLOCK_AIR:
						block_type = BLOCK_AIR  # Повітря всередині печери

				out_buffer.set_voxel(block_type, x, y, z, CHANNEL_TYPE)

func _get_height_at(x: int, z: int, biome_data: Dictionary) -> float:
	var height_modifier = biome_data.get("height_modifier", 0.0)
	var surface_roughness = biome_data.get("surface_roughness", 1.0)
	
	# Багатошаровий шум для створення плато
	# Макро-рельєф (70% впливу) - великі плавні форми, створюють плато
	var macro_height = macro_noise.get_noise_2d(x, z) * height_amplitude * 0.7
	
	# Основний шум (25% впливу) - середні пагорби
	var main_height = noise.get_noise_2d(x, z) * height_amplitude * 0.25
	
	# Мікро-деталі (5% впливу) - мінімальні нерівності
	var micro_height = micro_noise.get_noise_2d(x, z) * height_amplitude * 0.05
	
	# Комбінуємо шари
	var combined_height = macro_height + main_height + micro_height
	
	# Застосовуємо модифікатори біому (зменшений вплив для рівнини)
	var final_height = combined_height * surface_roughness * (1.0 + height_modifier * 0.3) + base_height
	
	# Обмежуємо максимальну висоту
	return clamp(final_height, 0.0, max_height)

func _get_biome_at_position(x: int, z: int) -> Dictionary:
	var scale = max(0.001, biome_scale)
	
	# Отримуємо температуру та вологість
	var temperature = temperature_noise.get_noise_2d(x / (scale * 1.5), z / (scale * 1.5))
	var humidity = humidity_noise.get_noise_2d(x / (scale * 1.2), z / (scale * 1.2))
	var biome_value = biome_noise.get_noise_2d(x / scale, z / scale)
	
	# Визначаємо біом на основі температури, вологості та основного значення
	# Плавні переходи між біомами
	if biome_value < -0.6:
		return _get_biome_data("desert")
	elif biome_value < -0.2:
		# Перехідна зона між пустелею і рівнинами
		if temperature < -0.3:
			return _get_biome_data("plains")
		else:
			return _get_biome_data("desert")
	elif biome_value < 0.2:
		return _get_biome_data("plains")
	elif biome_value < 0.6:
		# Перехідна зона між рівнинами і лісом
		if humidity > 0.2:
			return _get_biome_data("forest")
		else:
			return _get_biome_data("plains")
	else:
		# Гори (тільки якщо достатньо високо)
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
			"height_modifier": 0.3,  # Мінімальний вплив для рівнини
			"surface_roughness": 1.0  # Плавні переходи
		}
	}
	return biomes.get(biome_name, biomes["plains"])

func _is_position_in_starting_area(x: int, z: int) -> bool:
	"""Перевірити чи позиція знаходиться в стартовій зоні"""
	var half_size = starting_area_size / 2
	return abs(x) <= half_size and abs(z) <= half_size
