@tool
extends EditorScript

# Скрипт для автоматичного створення VoxelBlockyLibrary з текстур Set 4 All та separate
# Заміна atlas підходу - використовує окремі текстури через material_override

func _run():
	print("=== Створюємо VoxelBlockyLibrary з Set 4 All та separate ===")
	
	var library = VoxelBlockyLibrary.new()
	
	# 0: Air (null)
	library.add_model(null)
	print("Додано Air (index 0)")
	
	# Базові блоки для генератора (відповідають VoxelGeneratorAdapter.gd)
	var base_blocks = {
		"stone": "res://assets/textures/Set 2 128x128/Stone/Stone_11-128x128.png",
		"dirt": "res://assets/textures/Set 2 128x128/Dirt/Dirt_02-128x128.png",
		"grass": "res://assets/textures/Set 4 All/Grass/Grass_01_Green_2.png",
		"rock": "res://assets/textures/Set 4 All/Rockface/Rock_Grey_01.png"
	}
	
	var block_index = 1  # Починаємо з 1 (0 = Air)
	
	# Додаємо базові блоки
	for block_name in base_blocks.keys():
		var texture_path = base_blocks[block_name]
		var model = create_cube_model(block_name.capitalize(), texture_path)
		if model:
			library.add_model(model)
			print("Додано базовий блок: %s (index %d)" % [block_name, block_index])
			block_index += 1
	
	# Додаємо текстури з Set 4 All - всі категорії для максимального вибору
	var terrain_categories = [
		"Stones", "Dirt", "Grass", "Rockface", "Sand", "Gravel", 
		"Snow", "Pebbles", "Cobble Stone",
		"Bricks", "Concrete", "Wood", "Metal", "Tiles", "Wall",
		"Water", "Foliage", "Glass", "Roofing", "Plaster Wall",
		"Painted Wall", "Windows", "Doors", "Debris", "Decorations",
		"Patterns", "Paper", "Fabric"
	]
	var set4_path = "res://assets/textures/Set 4 All"
	
	print("\n=== Сканування Set 4 All для терейну ===")
	for category in terrain_categories:
		var category_path = set4_path + "/" + category
		var dir = DirAccess.open(category_path)
		if dir:
			var added = scan_category_for_textures(library, category_path, category, block_index)
			block_index += added
			print("Додано %d текстур з категорії %s" % [added, category])
		else:
			print("Пропущено категорію %s (не знайдено)" % category)
	
	# Зберігаємо бібліотеку
	var save_path = "res://assets/voxel_library.tres"
	var error = ResourceSaver.save(library, save_path)
	
	if error == OK:
		print("\n✅ VoxelBlockyLibrary успішно збережено: %s" % save_path)
		print("Всього блоків: %d (0=Air, 1-4=базові, 5+=додаткові)" % block_index)
	else:
		print("❌ Помилка збереження: %d" % error)

func create_cube_model(name: String, texture_path: String) -> VoxelBlockyModelCube:
	"""Створення VoxelBlockyModelCube з текстурою"""
	var texture = load(texture_path) as Texture2D
	if not texture:
		print("Помилка: не вдалося завантажити текстуру: %s" % texture_path)
		return null
	
	# Створюємо матеріал з текстурою
	var material = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.8
	material.metallic = 0.0
	
	# Створюємо VoxelBlockyModelCube
	var model = VoxelBlockyModelCube.new()
	model.resource_name = name
	model.material_override_0 = material
	
	return model

func scan_category_for_textures(library: VoxelBlockyLibrary, category_path: String, category_name: String, start_index: int) -> int:
	"""Рекурсивне сканування категорії текстур та додавання їх до бібліотеки"""
	return scan_directory_recursive(library, category_path, category_name)

func scan_directory_recursive(library: VoxelBlockyLibrary, dir_path: String, prefix: String) -> int:
	"""Рекурсивне сканування директорії з текстурами"""
	var dir = DirAccess.open(dir_path)
	if not dir:
		return 0
	
	var added_count = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = dir_path + "/" + file_name
		
		# Якщо це директорія - рекурсивно скануємо
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			var sub_prefix = prefix + "_" + file_name.to_lower().replace(" ", "_")
			added_count += scan_directory_recursive(library, full_path, sub_prefix)
		# Якщо це PNG файл - додаємо до бібліотеки
		elif file_name.ends_with(".png") and not file_name.ends_with(".import"):
			var block_name = prefix + "_" + file_name.replace(".png", "").replace(" ", "_").to_lower()
			
			var model = create_cube_model(block_name, full_path)
			if model:
				library.add_model(model)
				added_count += 1
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return added_count
