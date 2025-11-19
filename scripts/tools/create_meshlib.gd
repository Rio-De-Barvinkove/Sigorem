@tool
extends EditorScript

func _run():
	print("=== Створюємо MeshLibrary ===")
	
	var mesh_lib = MeshLibrary.new()
	
	# Grass block (ID 0)
	var grass_mesh = BoxMesh.new()
	grass_mesh.size = Vector3.ONE
	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.3, 0.8, 0.3)  # Зелений
	grass_mesh.surface_set_material(0, grass_mat)
	mesh_lib.create_item(0)
	mesh_lib.set_item_mesh(0, grass_mesh)
	
	# Додаємо колізію для grass
	var grass_shape = BoxShape3D.new()
	grass_shape.size = Vector3.ONE
	mesh_lib.set_item_shapes(0, [grass_shape, Transform3D.IDENTITY])
	
	print("✓ Grass block створено (ID: 0)")
	
	# Dirt block (ID 1)
	var dirt_mesh = BoxMesh.new()
	dirt_mesh.size = Vector3.ONE
	var dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.55, 0.27, 0.07)  # Коричневий
	dirt_mesh.surface_set_material(0, dirt_mat)
	mesh_lib.create_item(1)
	mesh_lib.set_item_mesh(1, dirt_mesh)
	
	# Додаємо колізію для dirt
	var dirt_shape = BoxShape3D.new()
	dirt_shape.size = Vector3.ONE
	mesh_lib.set_item_shapes(1, [dirt_shape, Transform3D.IDENTITY])
	
	print("✓ Dirt block створено (ID: 1)")
	
	# Stone block (ID 2)
	var stone_mesh = BoxMesh.new()
	stone_mesh.size = Vector3.ONE
	var stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.5, 0.5, 0.5)  # Сірий
	stone_mesh.surface_set_material(0, stone_mat)
	mesh_lib.create_item(2)
	mesh_lib.set_item_mesh(2, stone_mesh)
	
	# Додаємо колізію для stone
	var stone_shape = BoxShape3D.new()
	stone_shape.size = Vector3.ONE
	mesh_lib.set_item_shapes(2, [stone_shape, Transform3D.IDENTITY])
	
	print("✓ Stone block створено (ID: 2)")
	
	# Зберігаємо
	var save_path = "res://resources/terrain_meshlib.tres"
	var result = ResourceSaver.save(mesh_lib, save_path)
	
	if result == OK:
		print("✅ MeshLibrary успішно збережено в: " + save_path)
		print("Тепер можете запускати world.tscn!")
	else:
		print("❌ Помилка збереження! Код: " + str(result))
