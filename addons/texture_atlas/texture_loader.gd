@tool
extends EditorScript

func _run():
	var textures_path = "res://assets/textures/terrain"
	var meshlib_path = "res://resources/terrain_meshlib.tres"
	
	var mesh_library = MeshLibrary.new()
	var id_counter = 0
	
	var dir = DirAccess.open(textures_path)
	if dir:
		dir.list_dir_begin()
		add_textures_from_dir(dir, textures_path, mesh_library, id_counter)
		
		ResourceSaver.save(mesh_library, meshlib_path)
		print("MeshLibrary saved to %s" % meshlib_path)
	else:
		print("Could not open directory: " + textures_path)

func add_textures_from_dir(dir: DirAccess, path: String, mesh_lib: MeshLibrary, id_counter: int):
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				add_textures_from_dir(sub_dir, full_path, mesh_lib, id_counter)
		elif file_name.ends_with(".png") or file_name.ends_with(".svg"):
			var texture = load(full_path)
			if texture:
				var material = StandardMaterial3D.new()
				material.albedo_texture = texture
				
				var mesh = BoxMesh.new()
				mesh.surface_set_material(0, material)
				
				mesh_lib.create_item(id_counter)
				mesh_lib.set_item_mesh(id_counter, mesh)
				
				print("Added %s as item %d" % [full_path, id_counter])
				id_counter += 1
		
		file_name = dir.get_next()
