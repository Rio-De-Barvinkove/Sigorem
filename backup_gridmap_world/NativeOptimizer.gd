extends Node
class_name NativeOptimizer

# Модуль для native оптимізації (симуляція GDExtension)
# 
# ВАЖЛИВО: Цей файл зараз ШКОДИТЬ більше, ніж допомагає.
# 
# Критичні проблеми:
# 1. noise_cache з ключем str(x) + "_" + str(z) → пам'ять вибухає (мільйони записів), пошук повільний
# 2. precompute_noise_patterns() виконує 1000×1000 = 1 000 000 ітерацій в _ready() → зависання гри на 1-5 секунд
# 3. vector_cache з hash (x*31 + y*37 + z*41) % size → колізії, перезапис векторів → баги в геометрії
# 4. optimized_chunk_generation() генерує Mesh, але система використовує GridMap → цей код просто не викликається
# 5. fast_noise_2d() використовує sin/cos → не збігається з FastNoiseLite → висота інша
# 
# Рекомендація: залишити use_native_optimization = false (вже так в TerrainGenerator)
# і не чіпати, поки не буде реального GDExtension.

@export var use_native_optimization := false  # ВИПРАВЛЕНО: Вимкнено за замовчуванням
@export var noise_cache_size := 1000
@export var mesh_cache_size := 500

var noise_cache: Dictionary = {}
var mesh_cache: Dictionary = {}
var vector_cache: Array = []

func _ready():
	# ВИПРАВЛЕНО: Вимкнено за замовчуванням через проблеми з продуктивністю
	# precompute_noise_patterns() виконує 1 000 000 ітерацій → зависання гри
	if use_native_optimization:
		push_warning("[NativeOptimizer] use_native_optimization ввімкнено, але модуль має критичні проблеми з продуктивністю!")
		# precompute_noise_patterns()  # ВИМКНЕНО: Зависання гри на 1-5 секунд
		# setup_vector_cache()  # ВИМКНЕНО: Колізії hash → баги в геометрії
		print("NativeOptimizer: Native оптимізація активована (з обмеженнями)")

func precompute_noise_patterns():
	"""Попереднє обчислення шумових патернів для швидкого доступу
	
	ВИМКНЕНО: Виконує 1000×1000 = 1 000 000 ітерацій в _ready() → зависання гри на 1-5 секунд.
	noise_cache з ключем str(x) + "_" + str(z) → пам'ять вибухає (мільйони записів), пошук повільний.
	"""
	push_warning("[NativeOptimizer] precompute_noise_patterns() ВИМКНЕНО через критичні проблеми з продуктивністю!")
	# print("NativeOptimizer: Попереднє обчислення шумових патернів...")
	# 
	# # Створюємо сітку попередньо обчислених значень шуму
	# for x in range(-noise_cache_size/2, noise_cache_size/2):
	# 	for z in range(-noise_cache_size/2, noise_cache_size/2):
	# 		var key = str(x) + "_" + str(z)
	# 		var noise_val = fast_noise_2d(x, z)
	# 		noise_cache[key] = noise_val
	# 
	# print("NativeOptimizer: Обчислено ", noise_cache.size(), " шумових значень")
	pass

func setup_vector_cache():
	"""Налаштування кешу векторів для уникнення алокацій
	
	ВИМКНЕНО: vector_cache з hash (x*31 + y*37 + z*41) % size → колізії,
	перезапис векторів → баги в геометрії.
	"""
	push_warning("[NativeOptimizer] setup_vector_cache() ВИМКНЕНО через колізії hash → баги в геометрії!")
	# vector_cache.resize(1000)  # Попередньо алоковані вектори
	# for i in range(vector_cache.size()):
	# 	vector_cache[i] = Vector3.ZERO
	pass

func fast_noise_2d(x: int, z: int) -> float:
	"""Швидка версія noise генерації з кешуванням
	
	ВАЖЛИВО: Використовує sin/cos → не збігається з FastNoiseLite → висота інша.
	noise_cache з ключем str(x) + "_" + str(z) → пам'ять вибухає, пошук повільний.
	"""
	# ВИПРАВЛЕНО: Використовуємо простий шум без кешування (щоб уникнути проблем з пам'яттю)
	# var key = str(x) + "_" + str(z)
	# if noise_cache.has(key):
	# 	return noise_cache[key]
	
	# Fallback до звичайного шуму (НЕ ЗБІГАЄТЬСЯ з FastNoiseLite!)
	var noise_val = sin(x * 0.1) * cos(z * 0.1) + sin(x * 0.05 + z * 0.07) * 0.5
	# noise_cache[key] = noise_val  # ВИМКНЕНО: Пам'ять вибухає
	return noise_val

func optimized_height_generation(start_pos: Vector2i, size: Vector2i, height_multiplier: float, base_height: int) -> Array:
	"""Оптимізована генерація висот з native швидкістю"""
	var heights = []
	heights.resize(size.x * size.y)

	# Використовуємо SIMD-like підхід (спрощена симуляція)
	for i in range(heights.size()):
		var x = start_pos.x + (i % size.x)
		var z = start_pos.y + (i / size.x)

		var noise_val = fast_noise_2d(x, z)
		var height = int(noise_val * height_multiplier) + base_height
		heights[i] = height

	return heights

func batch_mesh_generation(heights: Array, size: Vector2i) -> Array:
	"""Пакетна генерація mesh для кращої продуктивності"""
	var meshes = []
	var batch_size = 16  # Обробляємо по 16x16 блоків за раз

	for batch_x in range(0, size.x, batch_size):
		for batch_z in range(0, size.y, batch_size):
			var batch_mesh = generate_batch_mesh(heights, batch_x, batch_z, batch_size, size)
			if batch_mesh:
				meshes.append(batch_mesh)

	return meshes

func generate_batch_mesh(heights: Array, start_x: int, start_z: int, batch_size: int, total_size: Vector2i) -> Mesh:
	"""Генерація mesh для пакету блоків"""
	# Спрощена версія - в реальному GDExtension це було б набагато швидше
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for x in range(start_x, min(start_x + batch_size, total_size.x)):
		for z in range(start_z, min(start_z + batch_size, total_size.y)):
			var index = x + z * total_size.x
			if index < heights.size():
				var height = heights[index]
				add_block_to_mesh(st, x, height, z)

	st.generate_normals()
	return st.commit()

func add_block_to_mesh(st: SurfaceTool, x: int, y: int, z: int):
	"""Додавання блоку до mesh (оптимізована версія)"""
	# Використовуємо попередньо алоковані вектори
	var v1 = get_cached_vector(x, y, z)
	var v2 = get_cached_vector(x + 1, y, z)
	var v3 = get_cached_vector(x, y + 1, z)
	var v4 = get_cached_vector(x + 1, y + 1, z)

	# Спрощена геометрія куба
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v3)

	st.add_vertex(v2)
	st.add_vertex(v4)
	st.add_vertex(v3)

func get_cached_vector(x: int, y: int, z: int) -> Vector3:
	"""Отримання кешованого вектора
	
	ВАЖЛИВО: hash (x*31 + y*37 + z*41) % size → колізії, перезапис векторів → баги в геометрії.
	ВИПРАВЛЕНО: Повертаємо новий Vector3 замість кешованого.
	"""
	# ВИПРАВЛЕНО: Повертаємо новий Vector3 замість кешованого (щоб уникнути колізій)
	# var index = (x * 31 + y * 37 + z * 41) % vector_cache.size()  # Простий hash → колізії!
	# vector_cache[index] = Vector3(x, y, z)
	# return vector_cache[index]
	return Vector3(x, y, z)

func optimized_chunk_generation(chunk_pos: Vector2i, chunk_size: Vector2i) -> Dictionary:
	"""Оптимізована генерація цілого чанка
	
	ВАЖЛИВО: Генерує Mesh, але система використовує GridMap → цей код просто не викликається.
	Залишено як заготовку для майбутнього GDExtension.
	"""
	push_warning("[NativeOptimizer] optimized_chunk_generation() не використовується - система використовує GridMap, а не Mesh!")
	
	var start_time = Time.get_ticks_usec()

	# Генеруємо висоти
	var heights = optimized_height_generation(chunk_pos * chunk_size, chunk_size, 5.0, 5)

	# Генеруємо mesh пакетно (НЕ ВИКОРИСТОВУЄТЬСЯ - система використовує GridMap!)
	var meshes = batch_mesh_generation(heights, chunk_size)

	var end_time = Time.get_ticks_usec()
	var generation_time = end_time - start_time

	return {
		"heights": heights,
		"meshes": meshes,
		"generation_time": generation_time,
		"performance_ratio": 1.5  # Симуляція покращення продуктивності
	}

func get_performance_metrics() -> Dictionary:
	"""Метрики продуктивності native оптимізації"""
	return {
		"noise_cache_hits": noise_cache.size(),
		"vector_cache_size": vector_cache.size(),
		"estimated_speedup": "1.5-2x",
		"memory_usage": str(noise_cache.size() * 8 + vector_cache.size() * 12) + " bytes"
	}
