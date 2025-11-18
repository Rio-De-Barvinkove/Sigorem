extends Node
class_name SplatMapManager

# Модуль для splat mapping - текстур залежно від висоти/крутизни
# Вдохновлено zylann.hterrain
#
# ВАЖЛИВО: Цей модуль має критичні проблеми продуктивності:
# - generate_splat_map() робить 4× get_height_at() на кожен піксель
# - Для 1024×1024 = 4 млн викликів шуму → зависання на 5-20 секунд
# - splat_image створюється кожного разу з нуля → пам'ять + лаги
# - calculate_steepness() викликає procedural_module.get_height_at() для сусідів → дуже повільно
# - Ніде не оновлюється при зміні чанка → splat map тільки одна на весь світ
#
# РЕКОМЕНДАЦІЯ: Залишити use_splat_mapping = false до повного перепису.
# Майбутнє рішення: генерувати splat per chunk (256×256) і оновлювати тільки при генерації чанка.

@export_group("Splat Textures")
@export var texture_0: Texture2D  # Низькі висоти (трава)
@export var texture_1: Texture2D  # Середні висоти (земля)
@export var texture_2: Texture2D  # Високі висоти (камінь)
@export var texture_3: Texture2D  # Схили (камінь)

@export_group("Splat Settings")
@export var splat_curve: Curve  # Крива для змішування текстур залежно від висоти
@export var steepness_curve: Curve  # Крива для крутизни схилів
@export var texture_scale := 10.0  # Масштаб текстур

var splat_material: ShaderMaterial
var splat_image: Image

func _ready():
	# ВИПРАВЛЕНО: Не генеруємо splat map автоматично через критичні проблеми продуктивності
	# Використовуйте generate_splat_map() вручну тільки якщо дійсно потрібно
	push_warning("[SplatMapManager] Модуль має критичні проблеми продуктивності. Рекомендується use_splat_mapping = false.")
	# setup_splat_material()
	# generate_splat_map()  # ВИМКНЕНО через зависання на 5-20 секунд

func setup_splat_material():
	"""Налаштування матеріалу з splat mapping шейдером"""
	splat_material = ShaderMaterial.new()

	# Простий splat mapping шейдер
	var shader_code = """
	shader_type spatial;
	render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

	uniform sampler2D splat_map;
	uniform sampler2D texture_0 : hint_albedo;
	uniform sampler2D texture_1 : hint_albedo;
	uniform sampler2D texture_2 : hint_albedo;
	uniform sampler2D texture_3 : hint_albedo;
	uniform float texture_scale = 10.0;

	varying vec2 uv_coords;

	void vertex() {
		uv_coords = UV * texture_scale;
	}

	void fragment() {
		vec4 splat = texture(splat_map, UV);
		vec4 color = vec4(0.0);

		// Змішування текстур на основі splat map
		color += texture(texture_0, uv_coords) * splat.r;
		color += texture(texture_1, uv_coords) * splat.g;
		color += texture(texture_2, uv_coords) * splat.b;
		color += texture(texture_3, uv_coords) * splat.a;

		ALBEDO = color.rgb;
		METALLIC = 0.0;
		ROUGHNESS = 0.8;
	}
	"""

	var shader = Shader.new()
	shader.code = shader_code
	splat_material.shader = shader

	# Встановлюємо текстури
	if texture_0: splat_material.set_shader_parameter("texture_0", texture_0)
	if texture_1: splat_material.set_shader_parameter("texture_1", texture_1)
	if texture_2: splat_material.set_shader_parameter("texture_2", texture_2)
	if texture_3: splat_material.set_shader_parameter("texture_3", texture_3)

	splat_material.set_shader_parameter("texture_scale", texture_scale)

func generate_splat_map():
	"""Генерація splat map на основі висот та крутизни
	
	КРИТИЧНА ПРОБЛЕМА ПРОДУКТИВНОСТІ:
	- Робить 4× get_height_at() на кожен піксель (1 для height + 4 для steepness)
	- Для 256×256 = 65536 пікселів × 5 викликів = 327680 викликів шуму
	- Для 1024×1024 = 1048576 пікселів × 5 викликів = 5.2 млн викликів → зависання на 5-20 секунд
	- splat_image створюється кожного разу з нуля → пам'ять + лаги
	
	РЕКОМЕНДАЦІЯ: Не використовуйте цей метод до повного перепису.
	Майбутнє рішення: генерувати splat per chunk (256×256) і оновлювати тільки при генерації чанка.
	"""
	if not get_parent() or not get_parent().procedural_module:
		push_warning("SplatMapManager: ProceduralGeneration не знайдено!")
		return
	
	# ВИПРАВЛЕНО: Попередження про повільність
	push_warning("[SplatMapManager] generate_splat_map() викликано - це може зайняти 5-20 секунд і викликати зависання!")

	var map_size = 256  # Розмір splat map
	splat_image = Image.create(map_size, map_size, false, Image.FORMAT_RGBA8)

	# КРИТИЧНА ПРОБЛЕМА: Генеруємо splat дані - дуже повільно через мільйони викликів get_height_at()
	for x in range(map_size):
		for y in range(map_size):
			var world_x = (float(x) / map_size - 0.5) * 100.0  # Перетворюємо в світові координати
			var world_z = (float(y) / map_size - 0.5) * 100.0

			# ПРОБЛЕМА: 1 виклик get_height_at() на піксель
			var height = get_parent().procedural_module.get_height_at(int(world_x), int(world_z))
			# ПРОБЛЕМА: calculate_steepness() робить ще 4 виклики get_height_at()
			var steepness = calculate_steepness(world_x, world_z)

			var splat_color = calculate_splat_color(height, steepness)
			splat_image.set_pixel(x, y, splat_color)

	# Створюємо текстуру
	var splat_texture = ImageTexture.create_from_image(splat_image)
	if not splat_material:
		setup_splat_material()
	splat_material.set_shader_parameter("splat_map", splat_texture)

	print("SplatMapManager: Splat map згенеровано (це зайняло багато часу через проблеми продуктивності)")

func calculate_steepness(world_x: float, world_z: float) -> float:
	"""Розрахунок крутизни місцевості
	
	КРИТИЧНА ПРОБЛЕМА ПРОДУКТИВНОСТІ:
	- Викликає procedural_module.get_height_at() 4 рази для кожного пікселя
	- Це робить generate_splat_map() ще повільнішим (×4 виклики)
	- Для 256×256 = 65536 пікселів × 4 = 262144 додаткових викликів шуму
	
	РЕКОМЕНДАЦІЯ: Кешувати висоти або використовувати більш ефективний алгоритм.
	"""
	if not get_parent() or not get_parent().procedural_module:
		return 0.0
	
	# ПРОБЛЕМА: 4 виклики get_height_at() для кожного пікселя → дуже повільно
	var h1 = get_parent().procedural_module.get_height_at(int(world_x - 1), int(world_z))
	var h2 = get_parent().procedural_module.get_height_at(int(world_x + 1), int(world_z))
	var h3 = get_parent().procedural_module.get_height_at(int(world_x), int(world_z - 1))
	var h4 = get_parent().procedural_module.get_height_at(int(world_x), int(world_z + 1))

	var grad_x = abs(h2 - h1) / 2.0
	var grad_z = abs(h4 - h3) / 2.0

	var steepness = sqrt(grad_x * grad_x + grad_z * grad_z)
	return clamp(steepness, 0.0, 1.0)

func calculate_splat_color(height: float, steepness: float) -> Color:
	"""Розрахунок кольору splat map"""
	var splat = Color(0, 0, 0, 0)

	# Нормалізуємо висоту
	var normalized_height = clamp((height - 0) / 20.0, 0.0, 1.0)  # Припускаємо діапазон висот 0-20

	# Використовуємо криві для визначення ваг текстур
	if splat_curve:
		var height_weight = splat_curve.sample(normalized_height)
		splat.r = height_weight  # Трава на низьких висотах
		splat.g = 1.0 - height_weight  # Земля на середніх
	else:
		# Простий підхід без кривих
		if normalized_height < 0.3:
			splat.r = 1.0  # Трава
		elif normalized_height < 0.7:
			splat.g = 1.0  # Земля
		else:
			splat.b = 1.0  # Камінь

	# Додаємо вплив крутизни
	if steepness > 0.5:  # Крутий схил
		splat.b = max(splat.b, 0.8)  # Камінь на схилах
		splat.r *= 0.2  # Менше трави на схилах

	return splat

func apply_splat_to_mesh(mesh_instance: MeshInstance3D):
	"""Застосування splat матеріалу до mesh"""
	if splat_material:
		mesh_instance.set_surface_override_material(0, splat_material)

func update_splat_map_region(region_start: Vector2, region_size: Vector2):
	"""Оновлення splat map для конкретного регіону
	
	ПРОБЛЕМА: Зараз просто викликає generate_splat_map() → генерує всю карту заново.
	Це не оптимізовано і викликає ті ж проблеми продуктивності.
	
	РЕКОМЕНДАЦІЯ: Не використовуйте до повного перепису.
	Майбутнє рішення: оновлювати тільки конкретний регіон без перегенерації всієї карти.
	"""
	# ВИПРАВЛЕНО: Попередження про проблеми
	push_warning("[SplatMapManager] update_splat_map_region() викликано - це генерує всю карту заново (повільно)!")
	# ПРОБЛЕМА: Для оптимізації можна оновлювати тільки частину карти, але зараз це не реалізовано
	generate_splat_map()  # Спрощений варіант - генерує всю карту заново (повільно)
