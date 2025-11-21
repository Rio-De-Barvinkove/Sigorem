extends Node
# Остаточний реєстр блоків (на базі простої реалізації)

signal block_registered(block_id: String)
signal blocks_loaded()

var blocks = {}
var block_mesh_library: MeshLibrary = null
var id_to_mesh_index = {}
var next_mesh_index = 0

func _ready():
	block_mesh_library = MeshLibrary.new()
	_load_default_blocks()

func _load_default_blocks():
	# Завантажуємо текстури з папки assets/textures/separate/
	_load_texture_blocks()
	
	# Завантажуємо текстури з папки assets/textures/Set 4 All/
	_load_set4_blocks()
	
	# Fallback блоки (якщо текстури не завантажились)
	if blocks.is_empty():
		_create_simple_block("grass", Color(0.4, 0.8, 0.2))
		_create_simple_block("dirt", Color(0.55, 0.27, 0.07))
		_create_simple_block("stone", Color(0.5, 0.5, 0.5))
	
	emit_signal("blocks_loaded")

func _load_texture_blocks():
	"""Завантаження блоків з текстурних файлів"""
	# Block Types - розпізнані текстури з коментарями
	var block_types = {
		# === DARK STONE / ROCK ===
		"dark_stone_01": {"texture": "texture_16px 1.png", "comment": "Темно-синій камінь/руда"},
		"dark_stone_02": {"texture": "texture_16px 2.png", "comment": "Темно-сірий камінь з тріщинами"},
		"dark_stone_03": {"texture": "texture_16px 3.png", "comment": "Темно-синьо-сірий камінь"},
		"dark_stone_04": {"texture": "texture_16px 4.png", "comment": "Темно-синьо-сірий камінь (варіант 2)"},
		"dark_stone_05": {"texture": "texture_16px 5.png", "comment": "Дуже темний камінь/базальт/обсидіан"},
		"dark_stone_06": {"texture": "texture_16px 6.png", "comment": "Темно-фіолетово-сірий камінь/руда"},
		"dark_stone_07": {"texture": "texture_16px 7.png", "comment": "Темно-сірий грубий камінь"},
		"dark_stone_08": {"texture": "texture_16px 8.png", "comment": "Темно-сірий камінь/бруківка"},
		"dark_stone_09": {"texture": "texture_16px 9.png", "comment": "Темно-синьо-сірий камінь (варіант 3)"},
		"dark_stone_10": {"texture": "texture_16px 11.png", "comment": "Темно-синій камінь з шестикутними формами"},
		"dark_stone_11": {"texture": "texture_16px 12.png", "comment": "Темно-синьо-сірий камінь (варіант 4)"},
		"dark_stone_12": {"texture": "texture_16px 13.png", "comment": "Темно-синьо-сірий камінь (варіант 5)"},
		"dark_stone_13": {"texture": "texture_16px 19.png", "comment": "Дуже темний камінь/вугілля/зола"},
		"dark_stone_14": {"texture": "texture_16px 20.png", "comment": "Однорідний темно-сірий камінь"},
		"dark_stone_15": {"texture": "texture_16px 24.png", "comment": "Темно-сірий камінь з світлішими плямами"},
		"dark_stone_16": {"texture": "texture_16px 25.png", "comment": "Темно-сірий грубий камінь (варіант 2)"},
		"dark_stone_17": {"texture": "texture_16px 30.png", "comment": "Темно-сірий камінь (варіант 3)"},
		"dark_stone_18": {"texture": "texture_16px 110.png", "comment": "Темно-сірий камінь (варіант 4)"},
		"dark_stone_19": {"texture": "texture_16px 120.png", "comment": "Темно-сірий камінь (варіант 5)"},
		"dark_stone_20": {"texture": "texture_16px 160.png", "comment": "Темно-синьо-сірий камінь з мінеральними вкрапленнями"},
		"dark_stone_21": {"texture": "texture_16px 180.png", "comment": "Темно-синьо-сірий камінь (варіант 6)"},
		"dark_stone_22": {"texture": "texture_16px 187.png", "comment": "Темно-сірий камінь (варіант 7)"},
		
		# === DIRT / SOIL ===
		"dirt_01": {"texture": "texture_16px 14.png", "comment": "Темно-коричнева земля/ґрунт"},
		"dirt_02": {"texture": "texture_16px 15.png", "comment": "Коричнева земля з варіаціями"},
		"dirt_03": {"texture": "texture_16px 130.png", "comment": "Коричнева земля (розмита)"},
		
		# === CLAY ===
		"clay_01": {"texture": "texture_16px 30.png", "comment": "Коричнева глина з округлими формами"},
		"clay_02": {"texture": "texture_16px 100.png", "comment": "Червоно-коричнева глина з горизонтальними шарами"},
		
		# === STONE / COBBLESTONE ===
		"stone_01": {"texture": "texture_16px 16.png", "comment": "Сірий камінь з шестикутним патерном"},
		"stone_02": {"texture": "texture_16px 17.png", "comment": "Сірий камінь з округлими камінцями/бруківка"},
		"stone_03": {"texture": "texture_16px 18.png", "comment": "Світло-сині квадрати/плитка"},
		"stone_04": {"texture": "texture_16px 21.png", "comment": "Сірий камінь з дрібною зернистістю"},
		"stone_05": {"texture": "texture_16px 22.png", "comment": "Темно-сірий камінь зі світлішими плямами"},
		"stone_06": {"texture": "texture_16px 23.png", "comment": "Темно-сірий грубий камінь"},
		"stone_07": {"texture": "texture_16px 140.png", "comment": "Нейтральний сірий камінь"},
		
		# === BRICK ===
		"brick_01": {"texture": "texture_16px 50.png", "comment": "Темно-синя цегла"},
		"brick_02": {"texture": "texture_16px 60.png", "comment": "Червоно-коричнева цегла"},
		
		# === MOSSY STONE ===
		"mossy_stone": {"texture": "texture_16px 70.png", "comment": "Сірий камінь з мохом (зелені плями)"},
		
		# === METAL / INDUSTRIAL ===
		"metal_grate": {"texture": "texture_16px 16.png", "comment": "Металева решітка/сітка"},
		"metal_dark": {"texture": "texture_16px 90.png", "comment": "Темна металева панель/підсилений матеріал"},
		"metal_industrial": {"texture": "texture_16px 150.png", "comment": "Промислова металева решітка"},
		
		# === WOOD / WOVEN ===
		"wood_woven": {"texture": "texture_16px 19.png", "comment": "Плетена деревина/кошик"},
		"wood_basket": {"texture": "texture_16px 140.png", "comment": "Плетений кошик/плетіння"},
		
		# === ORE / GEMS ===
		"ore_gem": {"texture": "texture_16px 110.png", "comment": "Діаманти/кристали на темному фоні"},
		"ore_gold": {"texture": "texture_16px 120.png", "comment": "Золота руда (жовті/золоті вкраплення)"},
		
		# === MAGICAL / TECH ===
		"magical_ore": {"texture": "texture_16px 160.png", "comment": "Магічна руда (помаранчево-жовті світні лінії)"},
		"tech_block": {"texture": "texture_16px 170.png", "comment": "Технологічний блок (фіолетово-бірюзовий)"},
		"magical_block": {"texture": "texture_16px 180.png", "comment": "Магічний блок (фіолетово-бірюзовий патерн)"},
		
		# === SPECIAL / DECORATIVE ===
		"target_pattern": {"texture": "texture_16px 40.png", "comment": "Цільовий патерн (концентричні квадрати)"},
		"water_blue": {"texture": "texture_16px 130.png", "comment": "Вода (синій колір, розмита)"},
		
		# === ADDITIONAL TEXTURES (Batch 1: 10, 26-29, 31-39, 41-57) ===
		"dark_stone_23": {"texture": "texture_16px 10.png", "comment": "Темно-синьо-сірий камінь (варіант 8)"},
		"dark_stone_24": {"texture": "texture_16px 26.png", "comment": "Темно-сірий камінь/руда (варіант 8)"},
		"stone_08": {"texture": "texture_16px 27.png", "comment": "Сірий камінь з дрібними плямами"},
		"dark_stone_25": {"texture": "texture_16px 28.png", "comment": "Темно-сірий камінь з варіаціями"},
		"dark_stone_26": {"texture": "texture_16px 29.png", "comment": "Дуже темний камінь/базальт (варіант 2)"},
		"dark_stone_27": {"texture": "texture_16px 31.png", "comment": "Темно-сірий камінь з коричневими відтінками"},
		"grass_moss": {"texture": "texture_16px 32.png", "comment": "Зелено-сірий мох/трава"},
		"mossy_stone_02": {"texture": "texture_16px 33.png", "comment": "Сірий камінь з мохом/рослинністю"},
		"stone_09": {"texture": "texture_16px 34.png", "comment": "Сірий камінь з рельєфом"},
		"stone_10": {"texture": "texture_16px 35.png", "comment": "Темно-сірий камінь з шестикутним патерном"},
		"dirt_04": {"texture": "texture_16px 36.png", "comment": "Коричнево-помаранчева земля/глина"},
		"dark_stone_28": {"texture": "texture_16px 37.png", "comment": "Темно-синій камінь з округлими формами"},
		"dirt_05": {"texture": "texture_16px 38.png", "comment": "Темно-коричнева земля/глина"},
		"dark_stone_29": {"texture": "texture_16px 39.png", "comment": "Темно-синій камінь з шестикутним патерном"},
		"stone_11": {"texture": "texture_16px 41.png", "comment": "Сірий камінь з рельєфом/текстурою"},
		"crystal_teal": {"texture": "texture_16px 42.png", "comment": "Бірюзово-зелений кристал/вода"},
		"stone_12": {"texture": "texture_16px 43.png", "comment": "Сірий камінь з плямами"},
		"stone_13": {"texture": "texture_16px 44.png", "comment": "Сірий камінь з рельєфом (варіант 2)"},
		"dark_stone_30": {"texture": "texture_16px 45.png", "comment": "Темно-синій камінь з рельєфом"},
		"dark_stone_31": {"texture": "texture_16px 46.png", "comment": "Темно-синій камінь з рельєфом (варіант 2)"},
		"stone_14": {"texture": "texture_16px 47.png", "comment": "Сірий камінь з рельєфом (варіант 3)"},
		"stone_15": {"texture": "texture_16px 48.png", "comment": "Сірий камінь з рельєфом (варіант 4)"},
		"stone_16": {"texture": "texture_16px 49.png", "comment": "Сірий камінь з рельєфом (варіант 5)"},
		"stone_17": {"texture": "texture_16px 51.png", "comment": "Сірий камінь з рельєфом (варіант 6)"},
		"stone_cracked": {"texture": "texture_16px 52.png", "comment": "Тріснутий камінь/руда"},
		"stone_damaged": {"texture": "texture_16px 53.png", "comment": "Пошкоджений камінь з тріщинами"},
		"grass_dark": {"texture": "texture_16px 54.png", "comment": "Темна трава/мох"},
		"stone_18": {"texture": "texture_16px 55.png", "comment": "Сірий камінь з рельєфом (варіант 7)"},
		"stone_19": {"texture": "texture_16px 56.png", "comment": "Сірий камінь з рельєфом (варіант 8)"},
		"stone_20": {"texture": "texture_16px 57.png", "comment": "Сірий камінь з рельєфом (варіант 9)"},
		
		# === ADDITIONAL TEXTURES (Batch 2: 58-59, 61-69, 71-89) ===
		"brick_dark_blue": {"texture": "texture_16px 58.png", "comment": "Темно-синя цегла з рельєфом"},
		"brick_red_01": {"texture": "texture_16px 59.png", "comment": "Червоно-коричнева цегла"},
		"brick_dark_blue_grey": {"texture": "texture_16px 61.png", "comment": "Темно-синьо-сіра цегла"},
		"brick_red_02": {"texture": "texture_16px 62.png", "comment": "Червоно-коричнева цегла (варіант 2)"},
		"brick_red_03": {"texture": "texture_16px 63.png", "comment": "Червоно-коричнева цегла (варіант 3)"},
		"brick_red_04": {"texture": "texture_16px 64.png", "comment": "Червоно-коричнева цегла (варіант 4)"},
		"brick_red_05": {"texture": "texture_16px 65.png", "comment": "Червоно-коричнева цегла (варіант 5)"},
		"brick_red_06": {"texture": "texture_16px 66.png", "comment": "Червоно-коричнева цегла (варіант 6)"},
		"brick_red_07": {"texture": "texture_16px 67.png", "comment": "Червоно-коричнева цегла (варіант 7)"},
		"brick_red_08": {"texture": "texture_16px 68.png", "comment": "Червоно-коричнева цегла (варіант 8)"},
		"brick_red_09": {"texture": "texture_16px 69.png", "comment": "Червоно-коричнева цегла (варіант 9)"},
		"brick_red_10": {"texture": "texture_16px 71.png", "comment": "Червоно-коричнева цегла (варіант 10)"},
		"brick_grey_01": {"texture": "texture_16px 72.png", "comment": "Сіра цегла/камінь"},
		"brick_grey_02": {"texture": "texture_16px 73.png", "comment": "Сіра цегла/камінь (варіант 2)"},
		"brick_grey_03": {"texture": "texture_16px 74.png", "comment": "Сіра цегла/камінь (варіант 3)"},
		"mossy_brick_01": {"texture": "texture_16px 75.png", "comment": "Сіра цегла/камінь з мохом"},
		"mossy_brick_02": {"texture": "texture_16px 76.png", "comment": "Сіра цегла/камінь з мохом (варіант 2)"},
		"mossy_brick_03": {"texture": "texture_16px 77.png", "comment": "Сіра цегла/камінь з мохом (варіант 3)"},
		"mossy_brick_04": {"texture": "texture_16px 78.png", "comment": "Сіра цегла/камінь з мохом (варіант 4)"},
		"mossy_brick_05": {"texture": "texture_16px 79.png", "comment": "Сіра цегла/камінь з мохом (варіант 5)"},
		"brick_dark_blue_02": {"texture": "texture_16px 80.png", "comment": "Темно-синя цегла"},
		"brick_brown": {"texture": "texture_16px 81.png", "comment": "Коричнева цегла/деревина"},
		"brick_blue_grey_01": {"texture": "texture_16px 82.png", "comment": "Синьо-сіра цегла"},
		"brick_blue_grey_02": {"texture": "texture_16px 83.png", "comment": "Синьо-сіра цегла (варіант 2)"},
		"brick_red_orange": {"texture": "texture_16px 84.png", "comment": "Червоно-помаранчева цегла"},
		"brick_dark_blue_grey_02": {"texture": "texture_16px 85.png", "comment": "Темно-синьо-сіра цегла (варіант 2)"},
		"brick_dark_blue_grey_03": {"texture": "texture_16px 86.png", "comment": "Темно-синьо-сіра цегла (варіант 3)"},
		"brick_red_damaged": {"texture": "texture_16px 87.png", "comment": "Червоно-помаранчева цегла з пошкодженнями"},
		"brick_red_orange_02": {"texture": "texture_16px 88.png", "comment": "Червоно-помаранчева цегла (варіант 2)"},
		"brick_blue_grey_damaged": {"texture": "texture_16px 89.png", "comment": "Синьо-сіра цегла з пошкодженнями"},
		
		# === ADDITIONAL TEXTURES (Batch 3: 91-99, 101-109, 111-119, 121-124) ===
		"tech_magical_01": {"texture": "texture_16px 91.png", "comment": "Технологічна/магічна текстура (темно-синій з помаранчевими пікселями)"},
		"ore_dark_blue_red": {"texture": "texture_16px 92.png", "comment": "Темно-синя руда з червоно-коричневими вкрапленнями"},
		"ore_dark_blue_grey_red": {"texture": "texture_16px 93.png", "comment": "Темно-синьо-сіра руда з червоно-коричневими вкрапленнями"},
		"ore_blue_red_orange": {"texture": "texture_16px 94.png", "comment": "Синьо-сіра руда з червоно-помаранчевими вкрапленнями"},
		"water_teal_green": {"texture": "texture_16px 95.png", "comment": "Бірюзово-зелена вода/кристал"},
		"water_teal_green_02": {"texture": "texture_16px 96.png", "comment": "Бірюзово-зелена вода/кристал (варіант 2)"},
		"grass_teal_grid": {"texture": "texture_16px 97.png", "comment": "Зелена трава/мох з сіткою"},
		"grass_pixelated": {"texture": "texture_16px 98.png", "comment": "Піксельована зелена трава/мох"},
		"wood_paper_grid": {"texture": "texture_16px 99.png", "comment": "Деревина/папір з сіткою (жовто-помаранчеві плями)"},
		"stone_metal_blue_grey": {"texture": "texture_16px 101.png", "comment": "Сірий камінь/метал (синьо-сірий)"},
		"wood_beige_brown": {"texture": "texture_16px 102.png", "comment": "Бежева деревина/папір"},
		"wood_beige_yellow": {"texture": "texture_16px 103.png", "comment": "Бежева деревина/папір (жовтуватий)"},
		"wood_beige_dark": {"texture": "texture_16px 104.png", "comment": "Бежева деревина/папір (темний)"},
		"wood_brown_pixelated": {"texture": "texture_16px 105.png", "comment": "Піксельована коричнева деревина"},
		"wood_brown_blue_grey": {"texture": "texture_16px 106.png", "comment": "Коричнева деревина з синьо-сірими плямами"},
		"wood_brown_blue_grey_02": {"texture": "texture_16px 107.png", "comment": "Коричнева деревина з синьо-сірими плямами (варіант 2)"},
		"wood_brown_blue_grey_03": {"texture": "texture_16px 108.png", "comment": "Коричнева деревина з синьо-сірими плямами (варіант 3)"},
		"wood_brown_blue_grey_04": {"texture": "texture_16px 109.png", "comment": "Коричнева деревина з синьо-сірими плямами (варіант 4)"},
		"wood_brown_vertical": {"texture": "texture_16px 111.png", "comment": "Коричнева деревина з вертикальними смугами"},
		"wood_brown_warm": {"texture": "texture_16px 112.png", "comment": "Тепла коричнева деревина"},
		"wood_brown_dark": {"texture": "texture_16px 113.png", "comment": "Темна коричнева деревина"},
		"wood_brown_orange": {"texture": "texture_16px 114.png", "comment": "Коричнево-помаранчева деревина"},
		"wood_brown_pattern": {"texture": "texture_16px 115.png", "comment": "Коричнева деревина з патерном"},
		"brick_grey_dark": {"texture": "texture_16px 121.png", "comment": "Темна сіра цегла/камінь"},
		"stone_grey_mottled": {"texture": "texture_16px 122.png", "comment": "Сірий камінь з плямами"},
		"stone_grey_horizontal": {"texture": "texture_16px 123.png", "comment": "Сірий камінь з горизонтальними смугами"},
		"stone_grey_blurred": {"texture": "texture_16px 124.png", "comment": "Розмитий сірий камінь"},
		
		# === ADDITIONAL TEXTURES (Batch 4: 125-129, 131-139, 141-159) ===
		"paper_text_01": {"texture": "texture_16px 125.png", "comment": "Розмитий текст/папір (сірий)"},
		"paper_text_02": {"texture": "texture_16px 126.png", "comment": "Розмитий текст/папір (сірий варіант 2)"},
		"gem_dark_purple": {"texture": "texture_16px 127.png", "comment": "Темно-фіолетові/індиго гем-подібні об'єкти"},
		"stone_grey_holes": {"texture": "texture_16px 128.png", "comment": "Сірий камінь з отворами/пошкодженнями"},
		"stone_grey_camouflage": {"texture": "texture_16px 129.png", "comment": "Сірий камінь з темно-зеленими плямами (камуфляж)"},
		"crystal_light_blue": {"texture": "texture_16px 131.png", "comment": "Світло-блакитні світні кристали на темно-сірому фоні"},
		"brick_grey_glowing_blue": {"texture": "texture_16px 132.png", "comment": "Сірий цегляний фон зі світло-блакитними світніми формами"},
		"ore_gold_02": {"texture": "texture_16px 133.png", "comment": "Золота руда на темно-сірому камені"},
		"stone_grey_orange_brown": {"texture": "texture_16px 134.png", "comment": "Сірий камінь з помаранчево-коричневими плямами"},
		"stone_grey_beige": {"texture": "texture_16px 135.png", "comment": "Сірий камінь зі світло-коричневими/бежевими формами"},
		"stone_grey_red": {"texture": "texture_16px 136.png", "comment": "Сірий камінь з червоними формами"},
		"brick_grey_blue_spots": {"texture": "texture_16px 137.png", "comment": "Сірий цегляний фон з синіми плямами"},
		"stone_grey_green_squares": {"texture": "texture_16px 138.png", "comment": "Сірий камінь зі світло-зеленими квадратами"},
		"gold_corners": {"texture": "texture_16px 139.png", "comment": "Золоті L-подібні елементи на темно-коричневому фоні"},
		"gold_bricks": {"texture": "texture_16px 141.png", "comment": "Золоті світні прямокутники на темно-коричневому фоні"},
		"tech_blue_lines": {"texture": "texture_16px 142.png", "comment": "Блакитні лінії/схема на темно-блакитному фоні"},
		"water_blue_horizontal": {"texture": "texture_16px 143.png", "comment": "Блакитні горизонтальні смуги (вода)"},
		"water_blue_grid": {"texture": "texture_16px 144.png", "comment": "Блакитна сітка/хвилясті лінії (вода)"},
		"water_blue_net": {"texture": "texture_16px 145.png", "comment": "Блакитна сітка на темно-блакитному фоні"},
		"water_teal_waves": {"texture": "texture_16px 146.png", "comment": "Бірюзові хвилясті лінії (вода)"},
		"water_blue_various": {"texture": "texture_16px 147.png", "comment": "Блакитні хвилі/різні відтінки блакитного (вода)"},
		"water_blue_stars": {"texture": "texture_16px 148.png", "comment": "Блакитні зірочки/хрестики на темно-блакитному фоні"},
		"water_blue_dark": {"texture": "texture_16px 149.png", "comment": "Темно-блакитна вода"},
		"water_blue_light": {"texture": "texture_16px 151.png", "comment": "Світло-блакитна вода з горизонтальними смугами"},
		"water_blue_waves": {"texture": "texture_16px 152.png", "comment": "Блакитні хвилі/різні відтінки блакитного (вода варіант 2)"},
		"water_teal_chevron": {"texture": "texture_16px 153.png", "comment": "Бірюзові шеврони/зигзаги (вода)"},
		"water_blue_sky": {"texture": "texture_16px 154.png", "comment": "Світло-блакитна вода/небо"},
		"water_blue_ripples": {"texture": "texture_16px 155.png", "comment": "Блакитні хвилі/різні відтінки блакитного (вода варіант 3)"},
		"fire_orange_yellow": {"texture": "texture_16px 156.png", "comment": "Вогонь (помаранчево-жовтий градієнт)"},
		"fire_red_orange": {"texture": "texture_16px 157.png", "comment": "Вогонь (червоно-помаранчевий)"},
		"magical_red_blue": {"texture": "texture_16px 158.png", "comment": "Магічна текстура (червоно-блакитна)"},
		"magical_orange_yellow": {"texture": "texture_16px 159.png", "comment": "Магічна текстура (помаранчево-жовта)"},
		
		# === ADDITIONAL TEXTURES (Batch 5: 161-169, 171-179, 181-189, 191-199) ===
		"honey_golden_orange": {"texture": "texture_16px 161.png", "comment": "Золото-помаранчева текстура (мед/соти)"},
		"fire_orange_grid": {"texture": "texture_16px 162.png", "comment": "Помаранчева/коричнева сітка з світніми квадратами"},
		"fire_orange_yellow_blurred": {"texture": "texture_16px 163.png", "comment": "Помаранчево-жовта розмита текстура (вогонь/тепло)"},
		"fire_orange_brown_blurred": {"texture": "texture_16px 164.png", "comment": "Помаранчева/коричнева розмита текстура"},
		"fire_vertical": {"texture": "texture_16px 165.png", "comment": "Помаранчево-жовта вертикальна текстура (вогонь)"},
		"magical_dark_purple_orange": {"texture": "texture_16px 166.png", "comment": "Темно-фіолетовий фон з помаранчевими/жовтими світніми плямами"},
		"magical_dark_blue_orange": {"texture": "texture_16px 167.png", "comment": "Темно-синій/фіолетовий фон з помаранчевими/червоними світніми плямами"},
		"magical_dark_blue_orange_02": {"texture": "texture_16px 168.png", "comment": "Темно-синій/фіолетовий фон з помаранчевими/червоними світніми плямами (варіант 2)"},
		"magical_dark_purple_brown_orange": {"texture": "texture_16px 169.png", "comment": "Темно-фіолетовий/коричневий фон з помаранчевими/червоними світніми плямами"},
		"magical_network_orange": {"texture": "texture_16px 171.png", "comment": "Темно-фіолетовий/коричневий фон з помаранчевими/червоними мережами"},
		"magical_network_orange_02": {"texture": "texture_16px 172.png", "comment": "Темно-фіолетовий/коричневий фон з помаранчевими/червоними мережами (варіант 2)"},
		"magical_hexagon_orange": {"texture": "texture_16px 173.png", "comment": "Темно-фіолетовий/коричневий фон з помаранчевими/червоними шестикутниками"},
		"lava_cracks": {"texture": "texture_16px 174.png", "comment": "Темно-фіолетовий/коричневий фон з помаранчевими/жовтими тріщинами (лава)"},
		"fire_orange_brown_network": {"texture": "texture_16px 175.png", "comment": "Помаранчева/коричнева розмита сітка"},
		"magical_red_blurred": {"texture": "texture_16px 176.png", "comment": "Темно-червона розмита текстура"},
		"magical_red_blurred_02": {"texture": "texture_16px 177.png", "comment": "Темно-червона розмита текстура (варіант 2)"},
		"tech_blue_vertical": {"texture": "texture_16px 178.png", "comment": "Темно-синій/сірий фон зі світло-блакитними вертикальними смугами"},
		"tech_blue_vertical_02": {"texture": "texture_16px 179.png", "comment": "Темно-синій/сірий фон зі світло-блакитними вертикальними смугами (варіант 2)"},
		"fabric_blue_woven": {"texture": "texture_16px 181.png", "comment": "Темно-синя тканина/плетіння"},
		"fabric_blue_quilted": {"texture": "texture_16px 182.png", "comment": "Темно-синя стегана тканина"},
		"fabric_blue_brown": {"texture": "texture_16px 183.png", "comment": "Темно-синя/коричнева тканина"},
		"fabric_blue_soft": {"texture": "texture_16px 184.png", "comment": "Темно-синя м'яка тканина"},
		"fabric_dark_grey": {"texture": "texture_16px 185.png", "comment": "Темно-сіра тканина"},
		"water_teal_organic": {"texture": "texture_16px 186.png", "comment": "Бірюзово-зелена органічна текстура (вода)"},
		"water_teal_soft": {"texture": "texture_16px 188.png", "comment": "Бірюзова м'яка текстура (вода)"},
		"water_teal_dark": {"texture": "texture_16px 189.png", "comment": "Темно-бірюзова вода"},
		"magical_purple_teal": {"texture": "texture_16px 191.png", "comment": "Темно-фіолетовий фон з бірюзовими лініями"},
		"magical_pink_purple": {"texture": "texture_16px 192.png", "comment": "Рожево-фіолетова піксельована текстура"},
		"magical_pink_purple_02": {"texture": "texture_16px 193.png", "comment": "Рожево-фіолетова піксельована текстура (варіант 2)"},
		"magical_purple_brown": {"texture": "texture_16px 194.png", "comment": "Темно-фіолетова/коричнева розмита текстура"},
		"magical_purple_dark": {"texture": "texture_16px 195.png", "comment": "Темно-фіолетовий/чорний фон"},
		"magical_purple_nebula": {"texture": "texture_16px 196.png", "comment": "Темно-фіолетова туманність"},
		"magical_purple_crescent": {"texture": "texture_16px 197.png", "comment": "Темно-фіолетовий фон зі світніми півмісяцями"},
		"magical_purple_spiral": {"texture": "texture_16px 198.png", "comment": "Фіолетова спіраль"},
		"magical_blue_gem": {"texture": "texture_16px 199.png", "comment": "Блакитні світні геми на темному фоні"},
		
		# === ADDITIONAL TEXTURES (Batch 6: 200-234) ===
		"magical_energy_orange": {"texture": "texture_16px 200.png", "comment": "Піксельована абстрактна текстура з помаранчевими/жовтими/фіолетовими кольорами (магічна/енергія)"},
		"crystal_ice_blue": {"texture": "texture_16px 201.png", "comment": "Блакитний кристал/лід з білим відблиском"},
		"wood_beige_coral": {"texture": "texture_16px 202.png", "comment": "Розмита текстура з бежевими/кораловими вертикальними формами"},
		"wood_beige_peach": {"texture": "texture_16px 203.png", "comment": "Розмита бежева/персикова текстура"},
		"wood_orange_brown_grid": {"texture": "texture_16px 204.png", "comment": "Розмита помаранчева/коричнева текстура з сіткою"},
		"wood_orange_brown_blurred": {"texture": "texture_16px 205.png", "comment": "Розмита помаранчево-коричнева текстура"},
		"wood_light_brown_spots": {"texture": "texture_16px 206.png", "comment": "Розмита світло-коричнева текстура з плямами"},
		"wood_orange_amber_horizontal": {"texture": "texture_16px 207.png", "comment": "Розмита помаранчева/амбер текстура з горизонтальними смугами"},
		"wood_beige_horizontal_01": {"texture": "texture_16px 208.png", "comment": "Розмита бежева текстура з горизонтальними смугами"},
		"wood_beige_horizontal_02": {"texture": "texture_16px 209.png", "comment": "Розмита бежева текстура з горизонтальними смугами (варіант 2)"},
		"wood_beige_horizontal_03": {"texture": "texture_16px 210.png", "comment": "Розмита бежева текстура з горизонтальними смугами (варіант 3)"},
		"wood_beige_diagonal": {"texture": "texture_16px 211.png", "comment": "Розмита бежева текстура з діагональними смугами"},
		"wood_beige_orange_diagonal": {"texture": "texture_16px 212.png", "comment": "Розмита бежева/помаранчева текстура з діагональними смугами"},
		"wood_brown_wavy": {"texture": "texture_16px 213.png", "comment": "Коричнева текстура з горизонтальними хвилястими лініями (деревина)"},
		"wood_brown_chevron": {"texture": "texture_16px 214.png", "comment": "Коричнева текстура з шевронами/зигзагами"},
		"wood_orange_brown_diagonal": {"texture": "texture_16px 215.png", "comment": "Розмита помаранчева/коричнева текстура з діагональними лініями"},
		"wood_orange_gradient": {"texture": "texture_16px 216.png", "comment": "Помаранчева текстура з вертикальним градієнтом та патернами"},
		"wood_orange_brown_tiles": {"texture": "texture_16px 217.png", "comment": "Помаранчева/коричнева текстура з діагональними плитками"},
		"wood_brown_horizontal_blurred": {"texture": "texture_16px 218.png", "comment": "Розмита коричнева текстура з горизонтальними смугами"},
		"wood_brown_concentric": {"texture": "texture_16px 219.png", "comment": "Коричневі концентричні квадрати"},
		"wood_brown_dark_blurred": {"texture": "texture_16px 220.png", "comment": "Розмита темно-коричнева текстура"},
		"wood_brown_concentric_gradient": {"texture": "texture_16px 221.png", "comment": "Коричневі концентричні квадрати з градієнтом"},
		"wood_brown_vertical_02": {"texture": "texture_16px 222.png", "comment": "Розмита коричнева текстура з вертикальними смугами"},
		"wood_brown_concentric_02": {"texture": "texture_16px 223.png", "comment": "Коричневі концентричні квадрати (варіант 2)"},
		"wood_brown_concentric_03": {"texture": "texture_16px 224.png", "comment": "Коричневі концентричні квадрати (варіант 3)"},
		"wood_brown_concentric_04": {"texture": "texture_16px 225.png", "comment": "Коричневі концентричні квадрати (варіант 4)"},
		"wood_brown_mottled": {"texture": "texture_16px 226.png", "comment": "Розмита коричнева текстура з плямами"},
		"wood_brown_concentric_05": {"texture": "texture_16px 227.png", "comment": "Коричневі концентричні квадрати (варіант 5)"},
		"wood_brown_concentric_06": {"texture": "texture_16px 228.png", "comment": "Коричневі концентричні квадрати (варіант 6)"},
		"wood_brown_concentric_07": {"texture": "texture_16px 229.png", "comment": "Коричневі концентричні квадрати (варіант 7)"},
		"wood_brown_concentric_08": {"texture": "texture_16px 230.png", "comment": "Коричневі концентричні квадрати (варіант 8)"},
		"wood_brown_concentric_09": {"texture": "texture_16px 231.png", "comment": "Коричневі концентричні квадрати (варіант 9)"},
		"wood_brown_concentric_10": {"texture": "texture_16px 232.png", "comment": "Коричневі концентричні квадрати (варіант 10)"},
		"wood_brown_concentric_11": {"texture": "texture_16px 233.png", "comment": "Коричневі концентричні квадрати (варіант 11)"},
		"wood_brown_concentric_12": {"texture": "texture_16px 234.png", "comment": "Коричневі концентричні квадрати (варіант 12)"},
		
		# === ADDITIONAL TEXTURES (Batch 7: 235-269) ===
		"wood_brown_vertical_blurred_01": {"texture": "texture_16px 235.png", "comment": "Розмита коричнева текстура з вертикальними смугами (деревина)"},
		"wood_brown_pill_shapes": {"texture": "texture_16px 236.png", "comment": "Розмита коричнева текстура з округлими формами (деревина)"},
		"wood_brown_vertical_blurred_02": {"texture": "texture_16px 237.png", "comment": "Розмита коричнева текстура з вертикальними смугами (деревина варіант 2)"},
		"wood_brown_vertical_blurred_03": {"texture": "texture_16px 238.png", "comment": "Розмита коричнева текстура з вертикальними смугами (деревина варіант 3)"},
		"wood_dark_green_olive": {"texture": "texture_16px 239.png", "comment": "Розмита темно-зелена/оливкова текстура з плямами"},
		"wood_brown_grid_gradient": {"texture": "texture_16px 240.png", "comment": "Коричнева текстура з сіткою/градієнтом"},
		"wood_orange_vertical_blurred": {"texture": "texture_16px 241.png", "comment": "Розмита помаранчева текстура з вертикальними формами"},
		"wood_orange_brown_dark_shapes": {"texture": "texture_16px 242.png", "comment": "Розмита помаранчева/коричнева текстура з темними вертикальними формами"},
		"brick_brown_blurred": {"texture": "texture_16px 243.png", "comment": "Розмита коричнева цегляна текстура"},
		"brick_dark_brown": {"texture": "texture_16px 244.png", "comment": "Темно-коричнева цегла"},
		"brick_brown_02": {"texture": "texture_16px 245.png", "comment": "Коричнева цегла (варіант 2)"},
		"wood_light_brown": {"texture": "texture_16px 246.png", "comment": "Світло-коричнева деревина/цегла"},
		"wood_brown_planks_01": {"texture": "texture_16px 247.png", "comment": "Коричнева деревина/цегла (варіант 2)"},
		"wood_brown_planks_02": {"texture": "texture_16px 248.png", "comment": "Коричнева деревина/цегла (варіант 3)"},
		"brick_light_brown": {"texture": "texture_16px 249.png", "comment": "Світло-коричнева цегла"},
		"brick_brown_03": {"texture": "texture_16px 250.png", "comment": "Коричнева цегла (варіант 2)"},
		"brick_orange_brown_01": {"texture": "texture_16px 251.png", "comment": "Помаранчева/коричнева цегла"},
		"brick_orange_brown_02": {"texture": "texture_16px 252.png", "comment": "Помаранчева/коричнева цегла (варіант 2)"},
		"brick_red_brown_01": {"texture": "texture_16px 253.png", "comment": "Червоно-коричнева цегла"},
		"brick_red_brown_02": {"texture": "texture_16px 254.png", "comment": "Червоно-коричнева цегла (варіант 2)"},
		"wood_paper_brown_orange": {"texture": "texture_16px 255.png", "comment": "Розмита коричнева/помаранчева текстура (папір/деревина)"},
		"wood_orange_brown_vertical": {"texture": "texture_16px 256.png", "comment": "Розмита помаранчева/коричнева текстура з вертикальними смугами"},
		"crate_wood_vertical": {"texture": "texture_16px 257.png", "comment": "Піксельована коричнева текстура з вертикальними планками (ящик)"},
		"crate_wood_vertical_02": {"texture": "texture_16px 258.png", "comment": "Піксельована коричнева текстура з вертикальними планками (ящик варіант 2)"},
		"crate_wood_x_01": {"texture": "texture_16px 259.png", "comment": "Піксельована деревяна ящик з X-подібними планками"},
		"crate_wood_x_02": {"texture": "texture_16px 260.png", "comment": "Піксельована деревяна ящик з X-подібними планками (варіант 2)"},
		"crate_wood_x_03": {"texture": "texture_16px 261.png", "comment": "Піксельована деревяна ящик з X-подібними планками (варіант 3)"},
		"crate_wood_x_04": {"texture": "texture_16px 262.png", "comment": "Піксельована деревяна ящик з X-подібними планками (варіант 4)"},
		"crate_wood_x_05": {"texture": "texture_16px 263.png", "comment": "Піксельована деревяна ящик з X-подібними планками (варіант 5)"},
		"crate_wood_x_06": {"texture": "texture_16px 264.png", "comment": "Піксельована деревяна ящик з X-подібними планками (варіант 6)"},
		"bookshelf_books": {"texture": "texture_16px 265.png", "comment": "Розмита книжкова полиця з книгами"},
		"crate_wood_x_07": {"texture": "texture_16px 266.png", "comment": "Піксельована деревяна ящик з X-подібними планками (варіант 7)"},
		"crate_wood_x_08": {"texture": "texture_16px 267.png", "comment": "Піксельована деревяна ящик з X-подібними планками (варіант 8)"},
		"crate_wood_x_09": {"texture": "texture_16px 268.png", "comment": "Піксельована деревяна ящик з X-подібними планками (варіант 9)"},
		"bookshelf_books_02": {"texture": "texture_16px 269.png", "comment": "Розмита книжкова полиця з книгами (варіант 2)"},
		
		# === ADDITIONAL TEXTURES (Batch 8: 270-304) ===
		"bookshelf_books_03": {"texture": "texture_16px 270.png", "comment": "Книжкова полиця з книгами (2 полиці)"},
		"bookshelf_books_04": {"texture": "texture_16px 271.png", "comment": "Книжкова полиця з книгами (2 полиці, варіант 2)"},
		"wood_barrel_metal_band": {"texture": "texture_16px 272.png", "comment": "Деревяна поверхня з металевою смугою та заклепками (бочка/двері)"},
		"wood_chest_metal_bands": {"texture": "texture_16px 273.png", "comment": "Деревяна поверхня з металевими смугами та кільцем-ручкою (сундук/двері)"},
		"frame_brown_square": {"texture": "texture_16px 274.png", "comment": "Розмита коричнева квадратна рамка"},
		"camouflage_dark_green_blue": {"texture": "texture_16px 275.png", "comment": "Розмита темно-зелена/темно-синя текстура (камуфляж)"},
		"camouflage_dark_green_blue_02": {"texture": "texture_16px 276.png", "comment": "Розмита темно-зелена/темно-синя текстура (камуфляж варіант 2)"},
		"texture_yellow_green_olive": {"texture": "texture_16px 277.png", "comment": "Розмита жовто-зелена текстура (оливкова)"},
		"texture_green_ribbed": {"texture": "texture_16px 278.png", "comment": "Зелена текстура з вертикальними ребрами"},
		"texture_green_horizontal_stripes": {"texture": "texture_16px 279.png", "comment": "Зелена текстура з горизонтальними смугами (градієнт)"},
		"texture_green_diagonal_stripes": {"texture": "texture_16px 280.png", "comment": "Зелена текстура з діагональними смугами"},
		"texture_green_diagonal_stars": {"texture": "texture_16px 281.png", "comment": "Зелена текстура з діагональними смугами та зірочками"},
		"texture_green_yellow_symmetric": {"texture": "texture_16px 282.png", "comment": "Зелена/жовта симетрична текстура з помаранчевими акцентами"},
		"texture_gold_vertical_red_brown": {"texture": "texture_16px 283.png", "comment": "Золота вертикальна текстура з червоно-коричневими лініями"},
		"texture_green_yellow_stars": {"texture": "texture_16px 284.png", "comment": "Зелена текстура з жовтими зірочками"},
		"texture_green_light_spots": {"texture": "texture_16px 285.png", "comment": "Розмита зелена текстура з світлими плямами"},
		"texture_green_pink_beige_spots": {"texture": "texture_16px 286.png", "comment": "Розмита зелена текстура з рожево-бежевими плямами"},
		"texture_green_quilted": {"texture": "texture_16px 287.png", "comment": "Темно-зелена текстура з квадратами (підбита/стегана)"},
		"texture_green_blurred_01": {"texture": "texture_16px 288.png", "comment": "Розмита зелена текстура з плямами"},
		"texture_green_blurred_02": {"texture": "texture_16px 289.png", "comment": "Розмита зелена текстура з квадратами (варіант 2)"},
		"texture_green_dark_blurred": {"texture": "texture_16px 290.png", "comment": "Розмита темно-зелена текстура"},
		"flower_purple_pixelated": {"texture": "texture_16px 291.png", "comment": "Піксельовані фіолетові квіти з зеленим листям"},
		"flower_purple_pixelated_02": {"texture": "texture_16px 292.png", "comment": "Піксельовані фіолетові квіти з зеленим листям (варіант 2)"},
		"texture_green_squares_pixelated": {"texture": "texture_16px 293.png", "comment": "Піксельовані зелені квадрати на чорному фоні"},
		"texture_green_blocks_pixelated": {"texture": "texture_16px 294.png", "comment": "Піксельовані зелені блоки на чорному фоні"},
		"texture_green_scales": {"texture": "texture_16px 295.png", "comment": "Зелена текстура з лусками/блоками"},
		"texture_green_crosses": {"texture": "texture_16px 296.png", "comment": "Темно-зелені хрестики на чорному фоні"},
		"texture_green_checkerboard": {"texture": "texture_16px 297.png", "comment": "Розмита зелена/чорна шахівниця"},
		"texture_green_clover_pixelated": {"texture": "texture_16px 298.png", "comment": "Піксельована зелена текстура з чотирилистниками"},
		"texture_green_leaves_pixelated": {"texture": "texture_16px 299.png", "comment": "Піксельовані зелені листки на темно-зеленому фоні"},
		"texture_green_camouflage_blurred": {"texture": "texture_16px 300.png", "comment": "Розмита зелена камуфляжна текстура"},
		"texture_green_teal_abstract": {"texture": "texture_16px 301.png", "comment": "Розмита зелена/бірюзова абстрактна текстура"},
		"texture_fire_orange_red": {"texture": "texture_16px 302.png", "comment": "Розмита помаранчево-червона текстура (вогонь/вугіль)"},
		"texture_green_pixelated_pattern": {"texture": "texture_16px 303.png", "comment": "Піксельована зелена текстура з патерном"},
		"texture_green_tiles": {"texture": "texture_16px 304.png", "comment": "Темно-зелені плитки/квадрати з градієнтом"},
		
		# === ADDITIONAL TEXTURES (Batch 9: 305-334) ===
		"texture_teal_quilted": {"texture": "texture_16px 305.png", "comment": "Темно-бірюзова текстура з квадратами (підбита/стегана)"},
		"texture_green_scales_01": {"texture": "texture_16px 306.png", "comment": "Зелена текстура з лусками/блоками (градієнт)"},
		"texture_green_scales_02": {"texture": "texture_16px 307.png", "comment": "Зелена текстура з лусками/блоками (варіант 2)"},
		"texture_green_blocks_blurred": {"texture": "texture_16px 308.png", "comment": "Розмита зелена текстура з блоками"},
		"texture_green_curves_01": {"texture": "texture_16px 309.png", "comment": "Зелена текстура з S-подібними кривими (світні)"},
		"texture_green_curves_02": {"texture": "texture_16px 310.png", "comment": "Зелена текстура з S-подібними кривими (варіант 2)"},
		"texture_green_octagons": {"texture": "texture_16px 311.png", "comment": "Зелена текстура з восьмикутниками"},
		"strawberry_pixelated": {"texture": "texture_16px 312.png", "comment": "Піксельована полуниця"},
		"strawberry_texture": {"texture": "texture_16px 313.png", "comment": "Червона текстура з жовто-помаранчевими крапками (полуниця)"},
		"texture_green_white_dark_rect": {"texture": "texture_16px 314.png", "comment": "Зелена/біла текстура з темним прямокутником"},
		"texture_green_gradient_blurred": {"texture": "texture_16px 315.png", "comment": "Розмита зелена текстура (градієнт)"},
		"texture_yellow_orange_white_square": {"texture": "texture_16px 316.png", "comment": "Розмита жовто-помаранчева текстура з білим квадратом"},
		"texture_yellow_solid": {"texture": "texture_16px 317.png", "comment": "Жовта текстура"},
		"texture_orange_dark_spots": {"texture": "texture_16px 318.png", "comment": "Розмита помаранчева текстура з темними плямами"},
		"texture_orange_dark_shapes": {"texture": "texture_16px 319.png", "comment": "Розмита помаранчева текстура з темними формами (сетка)"},
		"texture_orange_blurred": {"texture": "texture_16px 320.png", "comment": "Розмита помаранчева текстура"},
		"texture_green_orange_horizontal": {"texture": "texture_16px 321.png", "comment": "Розмита зелена/помаранчева текстура (горизонтальний поділ)"},
		"texture_brown_beige_horizontal": {"texture": "texture_16px 322.png", "comment": "Розмита коричнева/бежева текстура (горизонтальний поділ)"},
		"texture_green_yellow_grid": {"texture": "texture_16px 323.png", "comment": "Зелена текстура з жовтими крапками (сітка)"},
		"texture_green_diagonal_stars_02": {"texture": "texture_16px 324.png", "comment": "Зелена текстура з діагональними лініями та зірочками"},
		"tree_pixelated": {"texture": "texture_16px 325.png", "comment": "Піксельоване дерево"},
		"texture_green_vertical_gradient": {"texture": "texture_16px 326.png", "comment": "Зелена текстура з вертикальними смугами (градієнт)"},
		"leaf_green_pixelated": {"texture": "texture_16px 327.png", "comment": "Піксельований зелений листок"},
		"texture_green_vertical_stripes": {"texture": "texture_16px 328.png", "comment": "Розмита зелена текстура з вертикальними смугами"},
		"texture_green_yellow_vertical": {"texture": "texture_16px 329.png", "comment": "Розмита зелена/жовта текстура з вертикальними смугами"},
		"texture_green_symmetric": {"texture": "texture_16px 330.png", "comment": "Розмита симетрична зелена текстура"},
		"strawberry_texture_seeds": {"texture": "texture_16px 331.png", "comment": "Червона текстура з жовто-помаранчевими насінинами (полуниця)"},
		"texture_red_blurred_shapes": {"texture": "texture_16px 332.png", "comment": "Розмита червона текстура з світлими формами"},
		"texture_red_green_pixelated": {"texture": "texture_16px 333.png", "comment": "Піксельована червоно-зелена текстура"},
		"texture_green_vertical_blurred": {"texture": "texture_16px 334.png", "comment": "Розмита зелена текстура з вертикальними смугами (варіант 2)"},
		
		# === ADDITIONAL TEXTURES (Batch 10: 335-364) ===
		"texture_light_green_orange_spots": {"texture": "texture_16px 335.png", "comment": "Розмита текстура з зеленими та помаранчевими плямами на світлому фоні"},
		"texture_golden_concentric": {"texture": "texture_16px 336.png", "comment": "Розмита золота текстура з концентричними формами"},
		"texture_beige_brown_spots": {"texture": "texture_16px 337.png", "comment": "Розмита бежева текстура з коричневими плямами"},
		"dirt_grass_pixelated": {"texture": "texture_16px 338.png", "comment": "Піксельована земля з травою"},
		"mushroom_red_pixelated": {"texture": "texture_16px 339.png", "comment": "Піксельований червоний гриб"},
		"texture_beige_blurred": {"texture": "texture_16px 340.png", "comment": "Розмита бежева текстура"},
		"texture_brown_dark_spots": {"texture": "texture_16px 341.png", "comment": "Розмита коричнева текстура з темними плямами"},
		"texture_brown_solid": {"texture": "texture_16px 342.png", "comment": "Однотонна коричнева текстура"},
		"texture_orange_gradient_blurred": {"texture": "texture_16px 343.png", "comment": "Розмита помаранчева текстура з градієнтом"},
		"texture_paw_prints_pixelated": {"texture": "texture_16px 344.png", "comment": "Піксельована текстура з відбитками лап/чотирилистниками"},
		"texture_beige_checkerboard_blurred": {"texture": "texture_16px 345.png", "comment": "Розмита шахівниця бежева"},
		"texture_grey_blurred": {"texture": "texture_16px 346.png", "comment": "Розмита сіра текстура"},
		"texture_glowing_blocks_pixelated": {"texture": "texture_16px 347.png", "comment": "Піксельована текстура з 4 світніми блоками"},
		"chocolate_waffle_texture": {"texture": "texture_16px 348.png", "comment": "Текстура шоколаду/вафлі"},
		"chocolate_bar_01": {"texture": "texture_16px 349.png", "comment": "Текстура шоколаду (2x2 квадрати)"},
		"chocolate_bar_02": {"texture": "texture_16px 350.png", "comment": "Текстура шоколаду (варіант 2)"},
		"texture_dark_brown_blurred": {"texture": "texture_16px 351.png", "comment": "Розмита темно-коричнева текстура"},
		"texture_concentric_squares_01": {"texture": "texture_16px 352.png", "comment": "Концентричні квадрати (коричневі)"},
		"texture_concentric_squares_02": {"texture": "texture_16px 353.png", "comment": "Концентричні квадрати (варіант 2)"},
		"tunnel_pixelated": {"texture": "texture_16px 354.png", "comment": "Піксельований тунель з жовто-помаранчевим центром"},
		"button_red_pixelated": {"texture": "texture_16px 355.png", "comment": "Піксельований червоний квадрат у коричневій рамці"},
		"waves_aquarius_pixelated": {"texture": "texture_16px 356.png", "comment": "Піксельовані хвилі (Aquarius символ)"},
		"texture_brown_beige_stripes": {"texture": "texture_16px 357.png", "comment": "Горизонтальні смуги коричневі/бежеві"},
		"icon_c_hexagon_pixelated": {"texture": "texture_16px 358.png", "comment": "Піксельована іконка \"C\" в шестикутнику"},
		"texture_concentric_squares_beige": {"texture": "texture_16px 359.png", "comment": "Концентричні квадрати (бежеві)"},
		"heart_pixelated": {"texture": "texture_16px 360.png", "comment": "Піксельоване серце"},
		"texture_square_in_square_beige": {"texture": "texture_16px 361.png", "comment": "Квадрат у квадраті (бежевий)"},
		"icon_octagon_pixelated": {"texture": "texture_16px 362.png", "comment": "Восьмикутник з світлим центром"},
		"texture_orange_polygons_blurred": {"texture": "texture_16px 363.png", "comment": "Розмита помаранчева текстура з багатокутниками"},
		"texture_symmetric_brown_beige": {"texture": "texture_16px 364.png", "comment": "Розмита симетрична текстура з коричневими/бежевими тонами"},
		
		# === ADDITIONAL TEXTURES (Batch 11: 365-394) ===
		"chocolate_dripping_pixelated": {"texture": "texture_16px 365.png", "comment": "Піксельована темно-коричнева рідина (шоколад), що стікає"},
		"texture_glowing_orange_gold_pixelated": {"texture": "texture_16px 366.png", "comment": "Піксельована текстура з світніми помаранчево-золотими формами на темному фоні"},
		"texture_glowing_hexagons_blurred": {"texture": "texture_16px 367.png", "comment": "Розмита текстура з світніми шестикутниками на темно-червоно-коричневому фоні"},
		"texture_diamond_quilted": {"texture": "texture_16px 368.png", "comment": "Розмита текстура з діамантовим патерном (підбита/стегана)"},
		"texture_green_yellow_vertical_stripes": {"texture": "texture_16px 369.png", "comment": "Розмита зелено-жовта текстура з вертикальними смугами"},
		"texture_red_orange_vertical_stripes": {"texture": "texture_16px 370.png", "comment": "Розмита червоно-помаранчева текстура з вертикальними смугами"},
		"cookie_chocolate_chips_pixelated": {"texture": "texture_16px 371.png", "comment": "Піксельована текстура печива з шоколадними шматочками"},
		"texture_dark_shapes_teal": {"texture": "texture_16px 372.png", "comment": "Розмита текстура з темними формами на світло-зеленому/бірюзовому фоні"},
		"cracker_pixelated": {"texture": "texture_16px 373.png", "comment": "Піксельована текстура крекера/печива"},
		"bacon_texture_blurred": {"texture": "texture_16px 374.png", "comment": "Розмита текстура бекону (хвилясті смуги)"},
		"texture_horizontal_stripes_multi": {"texture": "texture_16px 375.png", "comment": "Горизонтальні смуги (бежева, золота, синя, золота, коричнева)"},
		"texture_light_geometric_blurred_01": {"texture": "texture_16px 376.png", "comment": "Розмита світла текстура з геометричним патерном"},
		"texture_grey_brown_quilted": {"texture": "texture_16px 377.png", "comment": "Розмита сіро-коричнева текстура з підбитим/стеганим патерном"},
		"texture_dark_grey_quilted": {"texture": "texture_16px 378.png", "comment": "Розмита темно-сіра текстура з підбитим/стеганим патерном"},
		"texture_blue_quilted": {"texture": "texture_16px 379.png", "comment": "Розмита синя текстура з підбитим/стеганим патерном"},
		"texture_teal_quilted_02": {"texture": "texture_16px 380.png", "comment": "Розмита бірюзова текстура з підбитим/стеганим патерном"},
		"texture_green_organic_blurred": {"texture": "texture_16px 381.png", "comment": "Розмита зелена текстура з органічними формами"},
		"texture_red_quilted": {"texture": "texture_16px 382.png", "comment": "Розмита червона текстура з підбитим/стеганим патерном"},
		"texture_orange_quilted": {"texture": "texture_16px 383.png", "comment": "Розмита помаранчева текстура з підбитим/стеганим патерном"},
		"texture_golden_quilted": {"texture": "texture_16px 384.png", "comment": "Розмита золота текстура з підбитим/стеганим патерном"},
		"texture_brown_brick_blurred": {"texture": "texture_16px 385.png", "comment": "Розмита коричнева текстура з цегляним патерном"},
		"texture_brown_solid_blurred": {"texture": "texture_16px 386.png", "comment": "Розмита коричнева текстура (однотонна)"},
		"texture_dark_brown_quilted": {"texture": "texture_16px 387.png", "comment": "Розмита темно-коричнева текстура з підбитим/стеганим патерном"},
		"texture_light_geometric_blurred_02": {"texture": "texture_16px 388.png", "comment": "Розмита світла текстура з геометричним патерном (варіант 2)"},
		"texture_terracotta_solid": {"texture": "texture_16px 389.png", "comment": "Однотонна терракота/червоно-коричнева текстура"},
		"texture_olive_green_solid": {"texture": "texture_16px 390.png", "comment": "Однотонна оливкова/військова зелена текстура"},
		"texture_grey_blue_solid": {"texture": "texture_16px 391.png", "comment": "Однотонна сіро-синя текстура"},
		"texture_beige_orange_grid_blurred": {"texture": "texture_16px 392.png", "comment": "Розмита бежево-помаранчева текстура з сіткою"},
		"texture_blue_grid_blurred": {"texture": "texture_16px 393.png", "comment": "Розмита синя текстура з сіткою"},
		"texture_orange_brown_grid_blurred": {"texture": "texture_16px 394.png", "comment": "Розмита помаранчево-коричнева текстура з сіткою"},
		
		# === ADDITIONAL TEXTURES (Batch 12: 395-424) ===
		"texture_grey_white_quilted": {"texture": "texture_16px 395.png", "comment": "Сіро-біла підбита/стегана текстура"},
		"texture_light_blue_quilted": {"texture": "texture_16px 396.png", "comment": "Світло-блакитна підбита/стегана текстура"},
		"texture_beige_peach_horizontal": {"texture": "texture_16px 397.png", "comment": "Розмита бежево-персикова текстура з горизонтальними смугами"},
		"texture_peach_grid_blurred": {"texture": "texture_16px 398.png", "comment": "Розмита персикова текстура з сіткою"},
		"texture_peach_squares_blurred": {"texture": "texture_16px 399.png", "comment": "Розмита персикова текстура з квадратами"},
		"texture_purple_lights_grid": {"texture": "texture_16px 400.png", "comment": "Розмита текстура з світніми фіолетовими точками на темному фоні"},
		"texture_peach_beige_vertical": {"texture": "texture_16px 401.png", "comment": "Розмита персиково-бежева текстура з вертикальними смугами"},
		"texture_green_horizontal_stripes_02": {"texture": "texture_16px 402.png", "comment": "Розмита зелена текстура з горизонтальними смугами"},
		"texture_blue_grey_woven": {"texture": "texture_16px 403.png", "comment": "Розмита синьо-сіра текстура з плетеним патерном"},
		"texture_red_brown_grid_blurred": {"texture": "texture_16px 404.png", "comment": "Розмита червоно-коричнева текстура з сіткою"},
		"texture_beige_peach_checkerboard": {"texture": "texture_16px 405.png", "comment": "Розмита шахівниця бежево-персикова"},
		"texture_blue_quilted_02": {"texture": "texture_16px 406.png", "comment": "Розмита синя підбита/стегана текстура"},
		"texture_blue_grey_quilted": {"texture": "texture_16px 407.png", "comment": "Розмита синьо-сіра підбита/стегана текстура з плетеним патерном"},
		"texture_brown_grid_blurred": {"texture": "texture_16px 408.png", "comment": "Розмита коричнева текстура з сіткою"},
		"texture_blue_waves_01": {"texture": "texture_16px 409.png", "comment": "Розмита синя текстура з хвилями"},
		"texture_blue_waves_02": {"texture": "texture_16px 410.png", "comment": "Розмита синя текстура з хвилями (варіант 2)"},
		"texture_light_beige_organic": {"texture": "texture_16px 411.png", "comment": "Розмита світла бежева текстура з органічними формами"},
		"texture_beige_brown_blurred": {"texture": "texture_16px 412.png", "comment": "Розмита бежево-коричнева текстура"},
		"texture_black_blurred": {"texture": "texture_16px 413.png", "comment": "Розмита чорна текстура"},
		"texture_light_beige_blurred": {"texture": "texture_16px 414.png", "comment": "Розмита світла бежева текстура"},
		"texture_golden_orange_blurred": {"texture": "texture_16px 415.png", "comment": "Розмита золота/помаранчева текстура"},
		"texture_pink_blurred": {"texture": "texture_16px 416.png", "comment": "Розмита рожева текстура"},
		"texture_golden_grid_blurred": {"texture": "texture_16px 417.png", "comment": "Розмита золота текстура з сіткою"},
		"texture_pink_solid": {"texture": "texture_16px 418.png", "comment": "Однотонна рожева текстура"},
		"texture_orange_waffle_blurred": {"texture": "texture_16px 419.png", "comment": "Розмита помаранчева текстура з сіткою (вафля)"},
		"texture_peach_grid_blurred_02": {"texture": "texture_16px 420.png", "comment": "Розмита персикова текстура з сіткою (варіант 2)"},
		"texture_orange_yellow_grid_blurred": {"texture": "texture_16px 421.png", "comment": "Розмита помаранчево-жовта текстура з сіткою"},
		"texture_orange_dark_spots_vertical": {"texture": "texture_16px 422.png", "comment": "Розмита помаранчева текстура з темними плямами (вертикальні колонки)"},
		"texture_dark_grey_vertical_ridges": {"texture": "texture_16px 423.png", "comment": "Темно-сіра текстура з вертикальними хвилями/ребрами"},
		"texture_blue_vertical_ridges": {"texture": "texture_16px 424.png", "comment": "Сіро-синя текстура з вертикальними ребрами"},
		
		# === ADDITIONAL TEXTURES (Batch 13: 425-454) ===
		"texture_green_yellow_vertical_stripes_02": {"texture": "texture_16px 425.png", "comment": "Розмита зелено-жовта текстура з вертикальними смугами"},
		"texture_dark_blue_vertical_ridges": {"texture": "texture_16px 426.png", "comment": "Темно-синя текстура з вертикальними хвилями/ребрами"},
		"texture_blue_grey_fluted": {"texture": "texture_16px 427.png", "comment": "Сіро-синя текстура з вертикальними смугами (флейтовані)"},
		"texture_yellow_orange_grid_blurred": {"texture": "texture_16px 428.png", "comment": "Розмита жовто-помаранчева текстура з сіткою"},
		"texture_green_grid_blurred": {"texture": "texture_16px 429.png", "comment": "Розмита зелена текстура з сіткою"},
		"texture_red_brown_checkerboard": {"texture": "texture_16px 430.png", "comment": "Розмита червоно-коричнева текстура з сіткою (шахівниця)"},
		"texture_orange_yellow_brown_checkerboard": {"texture": "texture_16px 431.png", "comment": "Розмита помаранчево-жовта/зелено-коричнева текстура з сіткою"},
		"texture_dark_blue_purple_stripes": {"texture": "texture_16px 432.png", "comment": "Розмита темно-синя текстура з фіолетовими смугами"},
		"texture_grey_glowing_points": {"texture": "texture_16px 433.png", "comment": "Розмита сіра текстура з світніми точками"},
		"texture_red_brown_plaid": {"texture": "texture_16px 434.png", "comment": "Розмита червоно-коричнева текстура (плед)"},
		"texture_red_blue_checkerboard": {"texture": "texture_16px 435.png", "comment": "Розмита червоно-синя текстура (шахівниця)"},
		"texture_blue_grid_blurred_02": {"texture": "texture_16px 436.png", "comment": "Розмита синя текстура з сіткою"},
		"texture_red_blue_plaid": {"texture": "texture_16px 437.png", "comment": "Розмита червоно-синя текстура (плед варіант 2)"},
		"texture_orange_yellow_blue_green_plaid": {"texture": "texture_16px 438.png", "comment": "Розмита помаранчево-жовта/синя/зелена текстура (плед)"},
		"texture_blue_white_grid": {"texture": "texture_16px 439.png", "comment": "Розмита синьо-біла текстура з сіткою"},
		"texture_light_blue_dark_shapes": {"texture": "texture_16px 440.png", "comment": "Розмита світло-синя текстура з темними формами"},
		"texture_blue_grey_quilted_02": {"texture": "texture_16px 441.png", "comment": "Розмита синьо-сіра текстура з підбитим/стеганим патерном"},
		"texture_coral_purple_diagonal": {"texture": "texture_16px 442.png", "comment": "Розмита коралово-рожева/фіолетова текстура з діагональними смугами"},
		"texture_blue_grey_diagonal_ridges": {"texture": "texture_16px 443.png", "comment": "Розмита синьо-сіра текстура з діагональними ребрами"},
		"texture_blue_plaid": {"texture": "texture_16px 444.png", "comment": "Розмита синя текстура (плед)"},
		"texture_light_blue_plaid": {"texture": "texture_16px 445.png", "comment": "Розмита світло-синя текстура (плед)"},
		"texture_red_blue_plaid_02": {"texture": "texture_16px 446.png", "comment": "Розмита червоно-синя текстура (плед варіант 3)"},
		"texture_golden_olive_quilted": {"texture": "texture_16px 447.png", "comment": "Розмита золота/оливкова текстура з підбитим/стеганим патерном"},
		"texture_yellow_orange_quilted": {"texture": "texture_16px 448.png", "comment": "Розмита жовто-помаранчева текстура з підбитим/стеганим патерном"},
		"texture_yellow_quilted": {"texture": "texture_16px 449.png", "comment": "Розмита жовта текстура з підбитим/стеганим патерном"},
		"texture_beige_brown_diamond_quilted": {"texture": "texture_16px 450.png", "comment": "Розмита бежево-коричнева текстура з діамантовим патерном"},
		"texture_blue_woven_glowing": {"texture": "texture_16px 451.png", "comment": "Розмита синя текстура з плетеним патерном (світні форми)"},
		"texture_blue_woven_glowing_02": {"texture": "texture_16px 452.png", "comment": "Розмита синя текстура з плетеним патерном (варіант 2)"},
		"texture_dark_blue_glowing_points": {"texture": "texture_16px 453.png", "comment": "Розмита темно-синя текстура з світніми точками"},
		"texture_orange_yellow_grid_4x4": {"texture": "texture_16px 454.png", "comment": "Розмита помаранчево-жовта текстура з сіткою (4x4)"},
		
		# === ADDITIONAL TEXTURES (Batch 14: 455-484) ===
		"texture_beige_blue_diagonal_plaid": {"texture": "texture_16px 455.png", "comment": "Розмита бежево-синя текстура з діагональними смугами (плед/аргайл)"},
		"texture_blue_grey_checkerboard": {"texture": "texture_16px 456.png", "comment": "Розмита синьо-сіра шахівниця"},
		"texture_dark_blue_cyan_points": {"texture": "texture_16px 457.png", "comment": "Темно-синя текстура зі світніми блакитними точками"},
		"texture_red_orange_crosses_pixelated": {"texture": "texture_16px 458.png", "comment": "Розмита піксельована текстура з червоно-помаранчевими хрестами на темно-синьому фоні"},
		"texture_blue_white_diamond_pattern": {"texture": "texture_16px 459.png", "comment": "Синьо-біла текстура з діамантовим патерном"},
		"texture_blue_white_zigzag_pixelated": {"texture": "texture_16px 460.png", "comment": "Піксельована синьо-біла текстура з зигзагом"},
		"texture_concentric_diamonds_red_orange_yellow": {"texture": "texture_16px 461.png", "comment": "Піксельована текстура з концентричними діамантами (червоно-коричнева, помаранчева, жовта, червона, темно-синя)"},
		"texture_concentric_diamonds_red_orange_yellow_02": {"texture": "texture_16px 462.png", "comment": "Піксельована текстура з концентричними діамантами (червоно-коричнева, червона, помаранчева, жовта, червоно-помаранчева)"},
		"texture_concentric_diamonds_red_purple_orange_blue": {"texture": "texture_16px 463.png", "comment": "Піксельована текстура з концентричними діамантами (червона, темно-фіолетово-коричнева, помаранчево-жовта, синя)"},
		"texture_concentric_diamonds_orange_red_green": {"texture": "texture_16px 464.png", "comment": "Піксельована текстура з концентричними діамантами (помаранчева, червона, темно-зелена)"},
		"texture_blue_orange_vertical_stripes": {"texture": "texture_16px 465.png", "comment": "Розмита текстура з вертикальними смугами (синя/червоно-помаранчева)"},
		"texture_blue_flowers_pixelated": {"texture": "texture_16px 466.png", "comment": "Розмита піксельована текстура з квітами/зірками на синьому фоні"},
		"texture_colorful_blocks_pixelated": {"texture": "texture_16px 467.png", "comment": "Розмита піксельована текстура з різнокольоровими блоками (рожева, зелена, бірюзова, блакитна)"},
		"texture_colorful_blocks_pixelated_02": {"texture": "texture_16px 468.png", "comment": "Розмита піксельована текстура з різнокольоровими блоками (різні кольори)"},
		"texture_red_green_crosses_beige": {"texture": "texture_16px 469.png", "comment": "Розмита піксельована текстура з червоними та зеленими хрестами на бежевому фоні"},
		"texture_green_crosses_blurred": {"texture": "texture_16px 470.png", "comment": "Розмита зелена текстура з хрестами/плюсами"},
		"texture_glowing_diamonds_red_teal_orange": {"texture": "texture_16px 471.png", "comment": "Розмита текстура зі світніми діамантами (червоний, бірюзовий, помаранчевий)"},
		"texture_glowing_quatrefoils_orange_red_teal": {"texture": "texture_16px 472.png", "comment": "Розмита текстура зі світніми чотирилистниками (помаранчевий, червоний, бірюзовий)"},
		"texture_green_diamonds_peach": {"texture": "texture_16px 473.png", "comment": "Темно-зелена текстура зі світніми персиковими діамантами"},
		"texture_green_glowing_points": {"texture": "texture_16px 474.png", "comment": "Темно-зелена текстура зі світніми зеленими точками"},
		"texture_beige_brown_spots_02": {"texture": "texture_16px 475.png", "comment": "Розмита бежева текстура з коричневими плямами"},
		"texture_orange_yellow_warm_blurred": {"texture": "texture_16px 476.png", "comment": "Розмита помаранчево-жовта тепла текстура"},
		"texture_orange_vertical_glow": {"texture": "texture_16px 477.png", "comment": "Розмита помаранчева текстура з вертикальним світінням"},
		"texture_beige_cream_blurred": {"texture": "texture_16px 478.png", "comment": "Розмита бежево-кремова текстура"},
		"texture_dark_red_brown_grid": {"texture": "texture_16px 479.png", "comment": "Темно-червоно-коричнева текстура з сіткою"},
		"texture_red_orange_diamonds_glowing": {"texture": "texture_16px 480.png", "comment": "Розмита текстура зі світніми червоно-помаранчевими діамантами (2x2)"},
		"texture_peach_tan_symmetrical": {"texture": "texture_16px 481.png", "comment": "Розмита персиково-бежева симетрична текстура"},
		"texture_orange_brown_vertical_bands": {"texture": "texture_16px 482.png", "comment": "Розмита помаранчево-коричнева текстура з вертикальними смугами"},
		"texture_pumpkin_jack_o_lantern": {"texture": "texture_16px 483.png", "comment": "Розмита текстура гарбуза-ліхтарика (jack-o'-lantern)"},
		"texture_pumpkin_icon_pixelated": {"texture": "texture_16px 484.png", "comment": "Піксельована іконка гарбуза/сонця (жовтий центр, помаранчеві пелюстки, темно-коричнева рамка)"},
		
		# === ADDITIONAL TEXTURES (Batch 15: 485-514) ===
		"pumpkin_pixelated": {"texture": "texture_16px 485.png", "comment": "Піксельований гарбуз (помаранчевий з вертикальними поділами)"},
		"pumpkin_jack_o_lantern_pixelated": {"texture": "texture_16px 486.png", "comment": "Піксельований гарбуз-ліхтарик (з обличчям)"},
		"grid_green_orange_brown": {"texture": "texture_16px 487.png", "comment": "Розмита сітка 3x3 (помаранчево-коричнева з зеленим елементом в центрі)"},
		"texture_orange_brown_symmetrical_panels": {"texture": "texture_16px 488.png", "comment": "Розмита симетрична текстура з помаранчевими панелями на коричневому фоні"},
		"pumpkin_face_pixelated": {"texture": "texture_16px 489.png", "comment": "Піксельоване обличчя гарбуза-ліхтарика (з зубами)"},
		"texture_red_gradient_vertical": {"texture": "texture_16px 490.png", "comment": "Розмита червона текстура з вертикальним градієнтом"},
		"texture_colorful_mosaic_blurred": {"texture": "texture_16px 491.png", "comment": "Розмита піксельована мозаїка з різнокольоровими блоками"},
		"texture_dark_blue_horizontal_streaks": {"texture": "texture_16px 492.png", "comment": "Темно-синя текстура з розмитими горизонтальними смугами"},
		"texture_brown_waffle_grid": {"texture": "texture_16px 493.png", "comment": "Розмита коричнева текстура з сіткою (вафля/плитка 2x2)"},
		"texture_peach_blue_vertical_stripes": {"texture": "texture_16px 494.png", "comment": "Розмита текстура з вертикальними смугами (персикова/блакитна)"},
		"texture_indigo_white_horizontal_stripes": {"texture": "texture_16px 495.png", "comment": "Розмита текстура з горизонтальними смугами (індиго/біла)"},
		"texture_brown_vertical_ribs": {"texture": "texture_16px 496.png", "comment": "Розмита коричнева текстура з вертикальними ребрами"},
		"texture_green_squares_beveled": {"texture": "texture_16px 497.png", "comment": "Зелена текстура зі скосленими квадратами (3D ефект)"},
		"texture_green_hexagons_3d": {"texture": "texture_16px 498.png", "comment": "Розмита зелена текстура з шестикутниками (3D ефект)"},
		"texture_brown_cubes_isometric": {"texture": "texture_16px 499.png", "comment": "Коричнева текстура з ізометричними кубами (тесселяція)"},
		"texture_warm_glowing_grid": {"texture": "texture_16px 500.png", "comment": "Розмита тепла текстура зі світніми квадратами (жовто-помаранчева, зелена)"},
		"texture_orange_brown_diamonds": {"texture": "texture_16px 501.png", "comment": "Розмита помаранчево-коричнева текстура з діамантами"},
		"texture_green_faceted_quilted": {"texture": "texture_16px 502.png", "comment": "Розмита зелена текстура з фацетками (підбита/стегана)"},
		"texture_blue_arrow_pattern": {"texture": "texture_16px 503.png", "comment": "Синьо-блакитна текстура з патерном стрілок/інвертованих T"},
		"texture_orange_diamonds_glowing": {"texture": "texture_16px 504.png", "comment": "Розмита помаранчева текстура зі світніми діамантами"},
		"texture_green_teal_diamonds_quilted": {"texture": "texture_16px 505.png", "comment": "Розмита зелено-бірюзова текстура з діамантами (підбита/стегана)"},
		"texture_purple_quilted": {"texture": "texture_16px 506.png", "comment": "Темно-фіолетова текстура з підбитим/стеганим патерном"},
		"texture_green_quilted_02": {"texture": "texture_16px 507.png", "comment": "Оливково-зелена текстура з підбитим/стеганим патерном"},
		"texture_orange_red_diamonds_warm": {"texture": "texture_16px 508.png", "comment": "Розмита помаранчево-червона текстура з діамантами (тепла)"},
		"texture_yellow_golden_quilted": {"texture": "texture_16px 509.png", "comment": "Розмита золота текстура з підбитим/стеганим патерном"},
		"texture_olive_green_quilted": {"texture": "texture_16px 510.png", "comment": "Оливково-зелена текстура з підбитим/стеганим патерном (варіант 2)"},
		"texture_dark_teal_glowing_crosses": {"texture": "texture_16px 511.png", "comment": "Темно-бірюзова текстура зі світніми хрестами/зірками"},
		"texture_red_tetris_shapes": {"texture": "texture_16px 512.png", "comment": "Червона текстура з розмитими геометричними формами (тетріс-подібні)"},
		"texture_camouflage_desert_pixelated": {"texture": "texture_16px 513.png", "comment": "Піксельований камуфляж (піщаний беж, коричневий, оливковий)"},
		"texture_red_orange_quilted": {"texture": "texture_16px 514.png", "comment": "Розмита червоно-помаранчева текстура з підбитим/стеганим патерном"},
		
		# === ADDITIONAL TEXTURES (Batch 16: 515-544) ===
		"camouflage_digital_green_brown_01": {"texture": "texture_16px 515.png", "comment": "Цифровий камуфляж (зелений, коричневий, піксельований)"},
		"camouflage_digital_green_brown_02": {"texture": "texture_16px 516.png", "comment": "Цифровий камуфляж (зелений, коричневий, варіант 2)"},
		"camouflage_digital_green_brown_03": {"texture": "texture_16px 517.png", "comment": "Цифровий камуфляж (зелений, коричневий, варіант 3)"},
		"camouflage_digital_green_brown_04": {"texture": "texture_16px 518.png", "comment": "Цифровий камуфляж (зелений, коричневий, варіант 4)"},
		"camouflage_digital_green_brown_05": {"texture": "texture_16px 519.png", "comment": "Цифровий камуфляж (зелений, коричневий, варіант 5)"},
		"camouflage_classic_green_brown": {"texture": "texture_16px 520.png", "comment": "Класичний камуфляж (коричневий, зелений, розмитий)"},
		"camouflage_digital_green_brown_06": {"texture": "texture_16px 521.png", "comment": "Цифровий камуфляж (зелений, коричневий, варіант 6)"},
		"camouflage_digital_grey_blue_01": {"texture": "texture_16px 522.png", "comment": "Цифровий камуфляж (сіро-блакитний, міський)"},
		"camouflage_digital_grey_blue_02": {"texture": "texture_16px 523.png", "comment": "Цифровий камуфляж (сіро-блакитний, варіант 2)"},
		"camouflage_digital_lime_olive_red": {"texture": "texture_16px 524.png", "comment": "Цифровий камуфляж (лайм-зелений, оливковий, червоно-коричневий)"},
		"texture_pepperoni_pizza_pixelated": {"texture": "texture_16px 525.png", "comment": "Піксельована текстура (пепероні на піці/леопардовий принт)"},
		"texture_leopard_print_pixelated_01": {"texture": "texture_16px 526.png", "comment": "Піксельований леопардовий принт (варіант 1)"},
		"texture_leopard_print_pixelated_02": {"texture": "texture_16px 527.png", "comment": "Піксельований леопардовий принт (варіант 2)"},
		"texture_leopard_print_blurred": {"texture": "texture_16px 528.png", "comment": "Розмитий леопардовий принт (помаранчевий/фіолетово-коричневий)"},
		"texture_dark_purple_bokeh_warm": {"texture": "texture_16px 529.png", "comment": "Темно-фіолетовий фон зі світніми плямами (bokeh, теплі тони)"},
		"texture_dark_blue_glowing_squares": {"texture": "texture_16px 530.png", "comment": "Темно-синій фон зі світніми квадратами"},
		"texture_dark_purple_bokeh_02": {"texture": "texture_16px 531.png", "comment": "Темно-фіолетовий фон зі світніми плямами (bokeh, варіант 2)"},
		"texture_light_blue_glowing_crosses": {"texture": "texture_16px 532.png", "comment": "Світло-блакитний фон зі світніми хрестами"},
		"landscape_ground_water_snow_pixelated": {"texture": "texture_16px 533.png", "comment": "Піксельований ландшафт (земля, вода/лід, сніг)"},
		"texture_brown_glowing_crosses": {"texture": "texture_16px 534.png", "comment": "Коричневий фон зі світніми хрестами (різні кольори)"},
		"texture_green_yellow_blurred": {"texture": "texture_16px 535.png", "comment": "Розмита зелена текстура з жовтувато-зеленими плямами"},
		"landscape_grass_soil_pixelated": {"texture": "texture_16px 536.png", "comment": "Піксельований ландшафт (трава, земля з камінням)"},
		"texture_golden_yellow_blurred_pattern": {"texture": "texture_16px 537.png", "comment": "Розмита золота текстура з абстрактними формами"},
		"landscape_grass_soil_pixelated_02": {"texture": "texture_16px 538.png", "comment": "Піксельований ландшафт (трава, земля, варіант 2)"},
		"texture_teal_glowing_crosses": {"texture": "texture_16px 539.png", "comment": "Темно-бірюзова текстура зі світніми хрестами"},
		"texture_teal_red_brown_abstract": {"texture": "texture_16px 540.png", "comment": "Абстрактна текстура (бірюзова/червоно-коричнева)"},
		"texture_red_diamonds_blurred": {"texture": "texture_16px 541.png", "comment": "Розмита червоно-коричнева текстура з діамантами"},
		"texture_teal_red_cubes_glowing": {"texture": "texture_16px 542.png", "comment": "Абстрактна текстура (бірюзова/червона зі світніми кубами)"},
		"texture_red_glowing_orbs": {"texture": "texture_16px 543.png", "comment": "Темно-червоний фон зі світніми помаранчевими плямами (bokeh)"},
		"texture_brown_hexagons_blurred": {"texture": "texture_16px 544.png", "comment": "Розмита коричнева текстура з шестикутниками"},
		
		# === ADDITIONAL TEXTURES (Batch 17: 545-574) ===
		"texture_dark_purple_glowing_rectangles": {"texture": "texture_16px 545.png", "comment": "Темно-фіолетовий фон зі світніми прямокутниками (bokeh)"},
		"landscape_grass_soil_minecraft_pixelated": {"texture": "texture_16px 546.png", "comment": "Піксельований ландшафт (трава, земля, Minecraft-стиль)"},
		"texture_dark_purple_bokeh_03": {"texture": "texture_16px 547.png", "comment": "Темно-фіолетовий фон зі світніми плямами (bokeh, варіант 3)"},
		"texture_dark_purple_bokeh_04": {"texture": "texture_16px 548.png", "comment": "Темно-фіолетовий фон зі світніми плямами (bokeh, варіант 4)"},
		"landscape_grass_soil_pixelated_03": {"texture": "texture_16px 549.png", "comment": "Піксельований ландшафт (трава, земля, варіант 3)"},
		"texture_brown_hexagons_pixelated": {"texture": "texture_16px 550.png", "comment": "Піксельована коричнева текстура з шестикутниками/бобами"},
		"texture_brown_soil_pixelated": {"texture": "texture_16px 551.png", "comment": "Піксельована коричнева текстура землі/грунту"},
		"landscape_grass_soil_pixelated_04": {"texture": "texture_16px 552.png", "comment": "Піксельований ландшафт (трава, земля, варіант 4)"},
		"landscape_lava_ground_pixelated": {"texture": "texture_16px 553.png", "comment": "Піксельований ландшафт (лава, земля)"},
		"texture_red_brown_hexagons_blurred": {"texture": "texture_16px 554.png", "comment": "Розмита червоно-коричнева текстура з шестикутниками"},
		"landscape_sky_ground_pixelated": {"texture": "texture_16px 555.png", "comment": "Піксельований ландшафт (небо, земля з шестикутниками)"},
		"texture_brown_octagons_blurred": {"texture": "texture_16px 556.png", "comment": "Розмита коричнева текстура з восьмикутниками"},
		"texture_brown_gradient_blurred": {"texture": "texture_16px 557.png", "comment": "Розмита коричнева текстура з градієнтом (світло-темно)"},
		"landscape_grass_soil_rock_pixelated": {"texture": "texture_16px 558.png", "comment": "Піксельований ландшафт (трава, земля, камінь)"},
		"landscape_fire_ground_pixelated": {"texture": "texture_16px 559.png", "comment": "Піксельований ландшафт (вогонь/лава, земля)"},
		"texture_blue_grey_red_brown_abstract": {"texture": "texture_16px 560.png", "comment": "Абстрактна текстура (синьо-сіра, червоно-коричнева)"},
		"texture_red_brown_hexagons_blurred_02": {"texture": "texture_16px 561.png", "comment": "Розмита червоно-коричнева текстура з шестикутниками (варіант 2)"},
		"texture_red_brown_hexagons_blurred_03": {"texture": "texture_16px 562.png", "comment": "Розмита червоно-коричнева текстура з шестикутниками (варіант 3)"},
		"texture_dark_purple_solid": {"texture": "texture_16px 563.png", "comment": "Однотонна темно-фіолетова текстура"},
		"landscape_blue_white_hexagons_pixelated": {"texture": "texture_16px 564.png", "comment": "Піксельований ландшафт (блакитний, білий, шестикутники)"},
		"texture_blue_hexagons_blurred": {"texture": "texture_16px 565.png", "comment": "Розмита синя текстура з шестикутниками"},
		"texture_blue_pill_shapes_blurred": {"texture": "texture_16px 566.png", "comment": "Розмита синя текстура з округлими формами (пілюлі)"},
		"landscape_white_blue_hexagons_pixelated": {"texture": "texture_16px 567.png", "comment": "Піксельований ландшафт (білий, синій, шестикутники)"},
		"texture_blue_hexagons_blurred_02": {"texture": "texture_16px 568.png", "comment": "Розмита синя текстура з шестикутниками (варіант 2)"},
		"texture_blue_grey_gradient_squares": {"texture": "texture_16px 569.png", "comment": "Розмита синьо-сіра текстура з квадратами (градієнт)"},
		"texture_blue_glowing_squares": {"texture": "texture_16px 570.png", "comment": "Темно-синій фон зі світніми квадратами"},
		"texture_blue_glowing_circles": {"texture": "texture_16px 571.png", "comment": "Темно-синій фон зі світніми кругами (bokeh)"},
		"texture_blue_grey_quilted_gradient": {"texture": "texture_16px 572.png", "comment": "Розмита синьо-сіра текстура з підбитим/стеганим патерном (градієнт)"},
		"texture_blue_gradient_squares": {"texture": "texture_16px 573.png", "comment": "Розмита синя текстура з квадратами (вертикальний градієнт)"},
		"texture_blue_glowing_squares_02": {"texture": "texture_16px 574.png", "comment": "Темно-синій фон зі світніми квадратами (варіант 2)"},
		
		# === ADDITIONAL TEXTURES (Batch 18: 575-604) ===
		"texture_green_blurred_01_v2": {"texture": "texture_16px 575.png", "comment": "Розмита зелена текстура (варіант 1)"},
		"texture_green_blurred_02_v2": {"texture": "texture_16px 576.png", "comment": "Розмита зелена текстура (варіант 2)"},
		"texture_green_blurred_03": {"texture": "texture_16px 577.png", "comment": "Розмита зелена текстура (варіант 3)"},
		"texture_green_blurred_04": {"texture": "texture_16px 578.png", "comment": "Розмита зелена текстура з сіткою (варіант 4)"},
		"texture_green_blurred_05": {"texture": "texture_16px 579.png", "comment": "Розмита зелена текстура (варіант 5)"},
		"landscape_grass_soil_ores_pixelated": {"texture": "texture_16px 580.png", "comment": "Піксельований ландшафт (трава, земля з рудами)"},
		"texture_brown_blue_grey_stars": {"texture": "texture_16px 581.png", "comment": "Розмита коричнева текстура з блакитно-сірими зірками"},
		"texture_brown_blurred_01": {"texture": "texture_16px 582.png", "comment": "Розмита коричнева текстура (варіант 1)"},
		"texture_brown_blurred_02": {"texture": "texture_16px 583.png", "comment": "Розмита коричнева текстура (варіант 2)"},
		"texture_brown_golden_quilted": {"texture": "texture_16px 584.png", "comment": "Розмита коричнева текстура з підбитим/стеганим патерном (золота)"},
		"landscape_sky_ground_ores_pixelated": {"texture": "texture_16px 585.png", "comment": "Піксельований ландшафт (небо, земля з рудами)"},
		"texture_brown_grid_blue_grey_items": {"texture": "texture_16px 586.png", "comment": "Розмита коричнева текстура з сіткою та блакитно-сірими предметами"},
		"icon_glitch_pixelated": {"texture": "texture_16px 587.png", "comment": "Піксельована іконка (глітч/помилка, діагональні білі точки)"},
		"icon_glitch_pixelated_02": {"texture": "texture_16px 588.png", "comment": "Піксельована іконка (глітч/помилка, варіант 2)"},
		"icon_glitch_pixelated_03": {"texture": "texture_16px 589.png", "comment": "Піксельована іконка (глітч/помилка, варіант 3)"},
		"icon_chest_wooden_pixelated": {"texture": "texture_16px 590.png", "comment": "Піксельована іконка дерев'яного сундука"},
		"icon_cabinet_drawers_pixelated": {"texture": "texture_16px 591.png", "comment": "Піксельована іконка шафи/комоди"},
		"icon_crate_wooden_pixelated": {"texture": "texture_16px 592.png", "comment": "Піксельована іконка дерев'яного ящика"},
		"icon_block_gray_pixelated": {"texture": "texture_16px 593.png", "comment": "Піксельована іконка сірого блоку"},
		"icon_inventory_grid_pixelated": {"texture": "texture_16px 594.png", "comment": "Піксельована іконка сітки інвентаря"},
		"icon_crafting_grid_pixelated": {"texture": "texture_16px 595.png", "comment": "Піксельована іконка сітки крафту (3x3)"},
		"icon_shelves_pixelated": {"texture": "texture_16px 596.png", "comment": "Піксельована іконка полиць/компартментів"},
		"icon_fireplace_pixelated": {"texture": "texture_16px 597.png", "comment": "Піксельована іконка каміна з вогнем"},
		"texture_dark_grey_blurred": {"texture": "texture_16px 598.png", "comment": "Розмита темно-сіра текстура"},
		"texture_grey_text_blurred": {"texture": "texture_16px 599.png", "comment": "Розмита сіра текстура з текстом"},
		"icon_lantern_metallic_pixelated": {"texture": "texture_16px 600.png", "comment": "Піксельована іконка металевого ліхтарика"},
		"texture_dark_grey_solid": {"texture": "texture_16px 601.png", "comment": "Однотонна темно-сіра текстура"},
		"icon_target_octagon_pixelated": {"texture": "texture_16px 602.png", "comment": "Піксельована іконка мішені (концентричні восьмикутники)"},
		"texture_metal_grate_pixelated": {"texture": "texture_16px 603.png", "comment": "Піксельована текстура металевої решітки"},
		"icon_biohazard_pixelated": {"texture": "texture_16px 604.png", "comment": "Піксельована іконка біологічної небезпеки"},
		
		# === ADDITIONAL TEXTURES (Batch 19: 605-609) ===
		"icon_bag_red_grey_pixelated": {"texture": "texture_16px 605.png", "comment": "Піксельована іконка сумки/контейнера (червоний, сірий)"},
		"icon_mailbox_red_grey_pixelated": {"texture": "texture_16px 606.png", "comment": "Піксельована іконка поштової скриньки (червоний, сірий)"},
		"texture_blue_yellow_diagonal_stripes": {"texture": "texture_16px 607.png", "comment": "Текстура з діагональними смугами (темно-синій, золотий)"},
		"texture_olive_green_glows": {"texture": "texture_16px 608.png", "comment": "Оливково-зелена текстура зі світніми плямами"},
		"texture_green_brown_camouflage_blurred": {"texture": "texture_16px 609.png", "comment": "Розмита камуфляжна текстура (зелений, коричневий)"},
	}
	
	# Завантажуємо кожен блок
	for block_id in block_types.keys():
		var block_data = block_types[block_id]
		var texture_path = "res://assets/textures/separate/" + block_data.texture
		_create_block_from_texture(block_id, texture_path, block_data.comment)

func _load_set4_blocks():
	"""Автоматичне завантаження блоків з папки Set 4 All"""
	var base_path = "res://assets/textures/Set 4 All"
	_scan_directory_for_textures(base_path, base_path)

func _scan_directory_for_textures(base_path: String, current_path: String):
	"""Рекурсивне сканування директорії для пошуку PNG-текстур"""
	var dir = DirAccess.open(current_path)
	if not dir:
		push_warning("BlockRegistry: Не вдалося відкрити директорію: " + current_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path: String
		if current_path.ends_with("/"):
			full_path = current_path + file_name
		else:
			full_path = current_path + "/" + file_name
		
		if dir.current_is_dir():
			# Рекурсивно скануємо підпапки
			if file_name != "." and file_name != "..":
				var next_path: String
				if current_path.ends_with("/"):
					next_path = current_path + file_name
				else:
					next_path = current_path + "/" + file_name
				_scan_directory_for_textures(base_path, next_path)
		elif file_name.ends_with(".png") and not file_name.ends_with(".import"):
			# Знайдено PNG-текстуру
			var relative_path = full_path.replace(base_path, "")
			# Видаляємо початковий слеш, якщо є
			if relative_path.begins_with("/"):
				relative_path = relative_path.substr(1)
			var block_id = _generate_block_id_from_path(relative_path)
			var comment = _generate_comment_from_filename(file_name)
			# Формуємо правильний шлях для завантаження (використовуємо res://)
			var texture_path = base_path + "/" + relative_path
			_create_block_from_texture(block_id, texture_path, comment)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _generate_block_id_from_path(relative_path: String) -> String:
	"""Генерація унікального ID блоку на основі шляху до текстури"""
	# Замінюємо слеші та розширення на підкреслення
	var id = relative_path.replace("/", "_").replace("\\", "_")
	id = id.replace(".png", "")
	id = id.to_lower()
	# Додаємо префікс для уникнення конфліктів
	return "set4_" + id

func _generate_comment_from_filename(filename: String) -> String:
	"""Генерація коментаря на основі назви файлу"""
	# Прибираємо розширення та замінюємо підкреслення на пробіли
	var comment = filename.replace(".png", "")
	comment = comment.replace("_", " ")
	return comment

func _create_block_from_texture(block_id: String, texture_path: String, comment: String = ""):
	"""Створення блоку з текстури з файлу"""
	var texture = load(texture_path) as Texture2D
	if not texture:
		push_warning("BlockRegistry: Не вдалося завантажити текстуру: " + texture_path)
		return
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	var material = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.8
	material.metallic = 0.0
	mesh.material = material
	
	var shape = BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	
	block_mesh_library.create_item(next_mesh_index)
	var display_name = block_id.capitalize().replace("_", " ") + " Block"
	if comment != "":
		display_name += " (" + comment + ")"
	block_mesh_library.set_item_name(next_mesh_index, display_name)
	block_mesh_library.set_item_mesh(next_mesh_index, mesh)
	block_mesh_library.set_item_shapes(next_mesh_index, [shape, Transform3D.IDENTITY])
	
	id_to_mesh_index[block_id] = next_mesh_index
	blocks[block_id] = {"id": block_id, "texture_path": texture_path, "comment": comment}
	# print("Created block: ", block_id, " (", comment, ") with index: ", next_mesh_index)
	emit_signal("block_registered", block_id)
	next_mesh_index += 1

func _create_simple_block(block_id: String, color: Color):
	"""Створення простого блоку з кольором (fallback)"""
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)  # Розмір блоку точно 1x1x1
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	material.metallic = 0.0
	mesh.material = material
	var shape = BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)  # Колізія теж 1x1x1
	block_mesh_library.create_item(next_mesh_index)
	block_mesh_library.set_item_name(next_mesh_index, block_id.capitalize() + " Block")
	block_mesh_library.set_item_mesh(next_mesh_index, mesh)
	block_mesh_library.set_item_shapes(next_mesh_index, [shape, Transform3D.IDENTITY])
	# Примітка: Тіні контролюються через world.tscn (mesh_cast_shadow = 0)
	id_to_mesh_index[block_id] = next_mesh_index
	blocks[block_id] = {"id": block_id}
	# print("Created block: ", block_id, " with index: ", next_mesh_index)
	next_mesh_index += 1

func get_mesh_library() -> MeshLibrary:
	return block_mesh_library

func get_mesh_index(block_id: String) -> int:
	return id_to_mesh_index.get(block_id, -1)
