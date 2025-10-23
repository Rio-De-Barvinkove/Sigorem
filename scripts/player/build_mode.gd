extends Node

var build_mode = false
var selected_block_id = 0 # ID from MeshLibrary

@onready var grid_map = get_node("/root/World/GridMap") # Assuming world is the root
@onready var camera = get_viewport().get_camera_3d()

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

func _unhandled_input(event):
	if event.is_action_pressed("build_mode"): # Add to Input Map
		build_mode = !build_mode
		if build_mode:
			ghost_mesh.mesh = grid_map.mesh_library.get_item_mesh(selected_block_id)
			ghost_mesh.show()
		else:
			ghost_mesh.hide()

	if build_mode and event is InputEventMouseButton and event.is_pressed():
		var mouse_pos = get_viewport().get_mouse_position()
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 1000
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)
		
		if result:
			if event.button_index == MOUSE_BUTTON_LEFT:
				# Place block
				var place_pos = grid_map.local_to_map(result.position - result.normal * 0.1)
				grid_map.set_cell_item(place_pos, selected_block_id)
				GameEvents.emit_signal("block_placed", place_pos, selected_block_id)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				# Destroy block
				var destroy_pos = grid_map.local_to_map(result.position + result.normal * 0.1)
				grid_map.set_cell_item(destroy_pos, -1) # -1 clears the cell
				GameEvents.emit_signal("block_destroyed", destroy_pos)

func _physics_process(delta):
	if build_mode:
		var mouse_pos = get_viewport().get_mouse_position()
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 1000
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)

		if result:
			var target_pos = grid_map.map_to_local(grid_map.local_to_map(result.position - result.normal * 0.1))
			ghost_mesh.global_transform.origin = target_pos
		else:
			ghost_mesh.hide()
