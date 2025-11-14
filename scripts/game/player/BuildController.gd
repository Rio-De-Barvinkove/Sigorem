extends Node

var build_mode = false
var selected_block_id = 0 # ID from MeshLibrary

@export_group("Creative Mode Settings")
@export var enable_area_breaking = true
@export var break_radius = 2  # Радіус ламання блоків (1 = 3x3, 2 = 5x5 тощо)
@export var enable_xray_mode = false

var grid_map: GridMap
var camera: Camera3D
var ghost_mesh: MeshInstance3D
var xray_material: StandardMaterial3D

func _ready():
	# Create a semi-transparent material for the ghost block
	var ghost_material = StandardMaterial3D.new()
	ghost_material.albedo_color = Color(1, 1, 1, 0.5)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	ghost_mesh = MeshInstance3D.new()
	ghost_mesh.material_override = ghost_material
	add_child(ghost_mesh)
	ghost_mesh.hide()
	
	# X-ray материал для підсвітки блоків
	xray_material = StandardMaterial3D.new()
	xray_material.albedo_color = Color(0.2, 1.0, 0.2, 0.3)  # Зелений напівпрозорий
	xray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	xray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Світиться
	xray_material.disable_receive_shadows = true

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
	# Перемикання X-ray режиму (клавіша X)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == Key.KEY_X:
			enable_xray_mode = not enable_xray_mode
			_apply_xray_mode()
			print("BuildController: X-ray mode ", "увімкнено" if enable_xray_mode else "вимкнено")
	
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
				
				if enable_area_breaking:
					# Лама блоки в області
					_break_blocks_in_area(destroy_pos, break_radius)
				else:
					# Лама один блок
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

func _break_blocks_in_area(center: Vector3i, radius: int):
	"""Ламає блоки в області навколо центру"""
	var broken_count = 0
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var pos = center + Vector3i(x, y, z)
				if grid_map.get_cell_item(pos) != -1:
					grid_map.set_cell_item(pos, -1)
					broken_count += 1
	print("Destroyed ", broken_count, " blocks in area around ", center)

func _apply_xray_mode():
	"""Застосовує або знімає X-ray материал з GridMap"""
	if not get_grid_map():
		return
	
	# TODO: GridMap не підтримує material_override
	# Для X-ray режиму потрібно змінювати матеріали в MeshLibrary
	# або використовувати shader на всіх блоках
	print("X-ray mode: feature not yet implemented for GridMap")
