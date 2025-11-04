extends GridMap

# Старий WorldGenerator - тепер просто обгортка для нового TerrainGenerator
# Зберігається для сумісності, але використовує новий модульний підхід

@export var terrain_generator: TerrainGenerator

func _ready():
	if not terrain_generator:
		# Створюємо новий TerrainGenerator якщо не встановлений
		terrain_generator = TerrainGenerator.new()
		terrain_generator.target_gridmap = self
		add_child(terrain_generator)
		print("WorldGenerator: Створено новий TerrainGenerator")

	# Налаштовуємо базові параметри
	if terrain_generator:
		terrain_generator.use_procedural_generation = true
		terrain_generator.use_chunking = false  # За замовчуванням без chunking для сумісності
		terrain_generator.noise = FastNoiseLite.new()
		terrain_generator.noise.seed = randi()
		terrain_generator.noise.frequency = 0.05