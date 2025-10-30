extends Node

var build_mode = false
var selected_block_id = 0 # ID from MeshLibrary

var grid_map: GridMap
var camera: Camera3D
var ghost_mesh: MeshInstance3D

func _ready():
	# Create a semi-transparent material for the ghost block
	var ghost_material = StandardMaterial3D.new()
	ghost_material.albedo_color = Color(1, 1, 1, 0.5)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	ghost_mesh = MeshInstance3D.new()
	ghost_mesh.material_override = ghost_material
	add_child(ghost_mesh)
	ghost_mesh.hide()

func get_grid_map():
	if not is_instance_valid(grid_map):
		var world_node = get_tree().get_root().get_node_or_null("World")
		if world_node:
			grid_map = world_node.get_node_or_null("GridMap")
	return grid_map

func get_camera():
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	return camera

func _unhandled_input(event):
	if event.is_action_pressed("build_mode"):
		build_mode = !build_mode
		print("Build mode: ", build_mode)
		
		if build_mode:
			var mesh_lib = BlockRegistry.get_mesh_library()
			if mesh_lib and mesh_lib.get_item_list().size() > selected_block_id:
				ghost_mesh.mesh = mesh_lib.get_item_mesh(selected_block_id)
				ghost_mesh.show()
				print("Build mode enabled")
			else:
				print("No mesh library or invalid block id")
		else:
			ghost_mesh.hide()

	if build_mode and event is InputEventMouseButton and event.is_pressed():
		if not get_grid_map() or not get_camera():
			return
		var mouse_pos = get_viewport().get_mouse_position()
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 1000
		var space_state = get_parent().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)
		
		if result:
			if event.button_index == MOUSE_BUTTON_LEFT:
				# Place block ON the surface (+ normal)
				var place_pos = grid_map.local_to_map(result.position + result.normal * 0.1)
				
				# Перевірка чи блок вже існує
				if grid_map.get_cell_item(place_pos) != -1:
					print("Block already exists at: ", place_pos)
					return
				
				# Перевірка чи MeshLibrary готовий
				if not grid_map.mesh_library:
					print("Error: GridMap MeshLibrary is null!")
					return
				
				var mesh_lib_item_count = grid_map.mesh_library.get_item_list().size()
				if selected_block_id >= mesh_lib_item_count:
					print("Error: Invalid block ID ", selected_block_id, ". Available: ", mesh_lib_item_count)
					return
				
				grid_map.set_cell_item(place_pos, selected_block_id)
				print("Placed block at: ", place_pos, " with mesh_index: ", selected_block_id)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				# Destroy block FROM the surface (- normal)
				var destroy_pos = grid_map.local_to_map(result.position - result.normal * 0.1)
				grid_map.set_cell_item(destroy_pos, -1)
				print("Destroyed block at: ", destroy_pos)

func _physics_process(_delta):
	if build_mode:
		if not get_grid_map() or not get_camera():
			return
		
		# Перевірка чи MeshLibrary встановлений
		if not grid_map.mesh_library:
			return
		
		var mouse_pos = get_viewport().get_mouse_position()
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 1000
		var space_state = get_parent().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)

		if result:
			# Ghost mesh shows placement position (+ normal)
			var target_pos = grid_map.map_to_local(grid_map.local_to_map(result.position + result.normal * 0.1))
			ghost_mesh.global_transform.origin = target_pos
			ghost_mesh.show()
		else:
			ghost_mesh.hide()


