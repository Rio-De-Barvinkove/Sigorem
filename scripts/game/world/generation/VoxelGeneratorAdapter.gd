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
# Параметри для різноманітного рельєфу
var height_amplitude := 50  # Амплітуда висоти для різноманітності
var base_height := 30  # Базовий рівень
var max_height := 120  # Максимальна висота
var biome_scale := 500.0  # Великі біоми для плавних переходів

# Фіксований seed для відтворюваності генерації
@export var world_seed: int = 1337

# Діагностика
var has_printed_diagnostic = false

# SDF channel for smooth terrain (VoxelMesherTransvoxel)
const CHANNEL_SDF = VoxelBuffer.CHANNEL_SDF
# TYPE channel для сумісності (якщо потрібно)
const CHANNEL_TYPE = VoxelBuffer.CHANNEL_TYPE

# Block type IDs (для майбутнього використання)
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
	push_warning("[GEN] VoxelGeneratorAdapter initialized: base_height=%d, height_amplitude=%d, max_height=%d, world_seed=%d" % [base_height, height_amplitude, max_height, world_seed])

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
	# VoxelMesherTransvoxel використовує SDF канал
	return 1 << CHANNEL_SDF

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int):
	var size := out_buffer.get_size()
	var size_x := size.x
	var size_y := size.y
	var size_z := size.z

	# Перевірка чи буфер валідний
	if size.x == 0 or size.y == 0 or size.z == 0:
		push_error("VoxelGeneratorAdapter: Invalid buffer size!")
		return

	# VoxelTerrain (без LOD) завжди викликає з lod=0
	# Координати вже в правильному масштабі світу

	# ДІАГНОСТИКА: виводимо інформацію про перший виклик (безумовно)
	if not has_printed_diagnostic:
		push_warning("[GEN] _generate_block CALLED: origin=%s, size=%s, lod=%d, base_height=%d, height_amplitude=%d, max_height=%d" % [origin, size, lod, base_height, height_amplitude, max_height])
		has_printed_diagnostic = true

	# Створюємо RNG один раз для всього блоку (детерміністичний)
	var rng = RandomNumberGenerator.new()

	# Проходимо по всіх вокселях в блоці
	# Для VoxelTerrain координати вже в правильному масштабі світу
	for x in range(0, size_x, 1):
		var world_x = origin.x + x
		for z in range(0, size_z, 1):
			var world_z = origin.z + z

			# Координати в правильному масштабі світу
			var noise_x = float(world_x)
			var noise_z = float(world_z)

			# Отримуємо біом для цієї координати
			var biome_data = _get_biome_at_position(noise_x, noise_z)

			# Отримуємо висоту поверхні
			var surface_height_float = _get_height_at(noise_x, noise_z, biome_data)
			var surface_height = int(surface_height_float + 0.5)

			# ДІАГНОСТИКА: виводимо значення для першого стовпчика (тільки один раз)
			if world_x == 0 and world_z == 0 and origin.y == 0:
				push_warning("[GEN] First column: world_x=%d, world_z=%d, noise_x=%.2f, noise_z=%.2f, surface_height=%d (float=%.2f), base_height=%d, height_amplitude=%d, max_height=%d" % [world_x, world_z, noise_x, noise_z, surface_height, surface_height_float, base_height, height_amplitude, max_height])

			# Генеруємо SDF значення для кожного Y рівня в цьому стовпчику
			# SDF (Signed Distance Field): позитивне = повітря, негативне = тверде
			for y in range(0, size_y, 1):
				var world_y = origin.y + y
				var sdf_value: float = 1.0  # За замовчуванням повітря (позитивне)

				# Перевірка чи ця позиція в стартовій зоні
				var in_starting_area = enable_starting_area and _is_position_in_starting_area(world_x, world_z)

				if in_starting_area:
					# Стартова зона - плоска платформа
					var platform_height = float(starting_area_height)
					sdf_value = platform_height - world_y
				else:
					# Звичайна генерація світу з SDF
					# SDF = відстань від поверхні (позитивне = вище поверхні, негативне = нижче)
					var height_diff = surface_height_float - world_y
					
					# Базове SDF значення (відстань від поверхні)
					sdf_value = height_diff
					
					# Додаємо плавність для мікровокселів (smooth transitions)
					# Використовуємо шум для додавання деталей
					var detail_noise = micro_noise.get_noise_3d(noise_x * 0.1, world_y * 0.1, noise_z * 0.1) * 0.5
					sdf_value += detail_noise
					
					# Для печер: якщо шум негативний, збільшуємо SDF (створюємо порожнину)
					if world_y < surface_height - 5:
						var cave_value = cave_noise.get_noise_3d(
							noise_x * 0.2,
							world_y * 0.2,
							noise_z * 0.2
						)
						if cave_value < -0.3:
							# Збільшуємо SDF для створення порожнини
							sdf_value += (cave_value + 0.3) * 5.0

				# Встановлюємо SDF значення (негативне = тверде, позитивне = повітря)
				out_buffer.set_voxel_f(sdf_value, x, y, z, CHANNEL_SDF)
	
	# Оптимізація: стискаємо однорідні канали (з референсної гри)
	out_buffer.compress_uniform_channels()

func _get_height_at(x: float, z: float, biome_data: Dictionary) -> float:
	var height_modifier = biome_data.get("height_modifier", 0.0)
	var surface_roughness = biome_data.get("surface_roughness", 1.0)
	
	# Координати вже масштабовані для правильного шуму (поділені на lod_factor)
	# Використовуємо їх безпосередньо для шуму
	var x_scaled = x
	var z_scaled = z
	
	# Багатошаровий шум для створення плато
	# Макро-рельєф (70% впливу) - великі плавні форми, створюють плато
	var macro_height = macro_noise.get_noise_2d(x_scaled, z_scaled) * height_amplitude * 0.7
	
	# Основний шум (25% впливу) - середні пагорби
	var main_height = noise.get_noise_2d(x_scaled, z_scaled) * height_amplitude * 0.25
	
	# Мікро-деталі (5% впливу) - мінімальні нерівності
	var micro_height = micro_noise.get_noise_2d(x_scaled, z_scaled) * height_amplitude * 0.05
	
	# Комбінуємо шари
	var combined_height = macro_height + main_height + micro_height
	
	# Застосовуємо модифікатори біому
	# height_modifier: -0.2 (desert) до 2.5 (mountains)
	var final_height = combined_height * surface_roughness * (1.0 + height_modifier) + base_height
	
	# Обмежуємо максимальну висоту
	return clamp(final_height, 0.0, max_height)

func _get_biome_at_position(x: float, z: float) -> Dictionary:
	var scale = max(0.001, biome_scale)
	
	# Координати вже масштабовані для правильного шуму (поділені на lod_factor)
	# Використовуємо їх безпосередньо для шуму
	var x_scaled = x
	var z_scaled = z
	
	# Отримуємо температуру та вологість
	var temperature = temperature_noise.get_noise_2d(x_scaled / (scale * 1.5), z_scaled / (scale * 1.5))
	var humidity = humidity_noise.get_noise_2d(x_scaled / (scale * 1.2), z_scaled / (scale * 1.2))
	var biome_value = biome_noise.get_noise_2d(x_scaled / scale, z_scaled / scale)
	
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
			"height_modifier": 2.5,  # Значний вплив для гір
			"surface_roughness": 1.5  # Більша нерівність для гір
		}
	}
	return biomes.get(biome_name, biomes["plains"])

func _is_position_in_starting_area(x: float, z: float) -> bool:
	"""Перевірити чи позиція знаходиться в стартовій зоні"""
	var half_size = starting_area_size / 2
	return abs(x) <= half_size and abs(z) <= half_size
