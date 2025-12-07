extends Node
class_name BuildController

## Build Controller for Voxdot
## Handles block placement and destruction

var build_mode: bool = false
var selected_material: int = 1  # Material ID for placement

@export_group("Build Settings")
@export var build_size: float = 0.3  # Size of placed/removed voxels
@export var max_reach_distance: float = 20.0

@export_group("Creative Mode Settings")
@export var enable_area_breaking: bool = true
@export var break_radius: float = 0.5

# References
var voxdot_terrain: Node  # VoxdotTerrain
var voxdot_controller: Node  # VoxdotController  
var camera: Camera3D
var ghost_mesh: MeshInstance3D

func _ready():
	_create_ghost_mesh()
	await get_tree().process_frame
	_find_terrain()

func _create_ghost_mesh():
	"""Create a semi-transparent preview mesh"""
	var ghost_material = StandardMaterial3D.new()
	ghost_material.albedo_color = Color(1, 1, 1, 0.4)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	ghost_mesh = MeshInstance3D.new()
	ghost_mesh.material_override = ghost_material
	
	var sphere = SphereMesh.new()
	sphere.radius = build_size
	sphere.height = build_size * 2
	ghost_mesh.mesh = sphere
	
	add_child(ghost_mesh)
	ghost_mesh.hide()
	
func _find_terrain():
	"""Find VoxdotTerrain in the scene"""
	# Try VoxdotDemo scene
	var demo = get_tree().get_root().get_node_or_null("VoxdotDemo")
	if demo:
		voxdot_terrain = demo.get_node_or_null("VoxdotTerrain")
		voxdot_controller = demo.get_node_or_null("VoxdotController")
	
	# Fallback: search entire tree
	if not voxdot_terrain:
		voxdot_terrain = _find_node_by_class("VoxdotTerrain")
	
	if voxdot_terrain:
		print("[BuildController] Found VoxdotTerrain")
	else:
		push_warning("[BuildController] VoxdotTerrain not found")

func _find_node_by_class(class_name_str: String) -> Node:
	for node in get_tree().get_root().get_children():
		if node.get_class() == class_name_str:
			return node
		var found = _find_child_by_class(node, class_name_str)
		if found:
			return found
	return null

func _find_child_by_class(parent: Node, class_name_str: String) -> Node:
	for child in parent.get_children():
		if child.get_class() == class_name_str:
			return child
		var found = _find_child_by_class(child, class_name_str)
		if found:
			return found
	return null

func get_camera() -> Camera3D:
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	return camera

func _unhandled_input(event):
	# Toggle Build Mode (B key)
	if event.is_action_pressed("build_mode"):
		build_mode = !build_mode
		if build_mode:
			ghost_mesh.show()
			_show_build_info()
		else:
			ghost_mesh.hide()
		print("[BuildController] Build mode: ", build_mode)
	
	if not build_mode:
		return
	
	# Material selection (1-4 keys)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				selected_material = 1
				print("[BuildController] Selected material: 1")
			KEY_2:
				selected_material = 2
				print("[BuildController] Selected material: 2")
			KEY_3:
				selected_material = 3
				print("[BuildController] Selected material: 3")
			KEY_4:
				selected_material = 0  # Air (for erasing)
				print("[BuildController] Selected: Air (erase)")
			KEY_BRACKETLEFT:
				build_size = max(0.1, build_size - 0.1)
				_update_ghost_mesh_size()
				print("[BuildController] Build size: ", build_size)
			KEY_BRACKETRIGHT:
				build_size = min(2.0, build_size + 0.1)
				_update_ghost_mesh_size()
				print("[BuildController] Build size: ", build_size)
	
	# Mouse actions
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_place_voxels()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_remove_voxels()

func _update_ghost_mesh_size():
	"""Update ghost mesh to match current build size"""
	if ghost_mesh and ghost_mesh.mesh is SphereMesh:
		var sphere = ghost_mesh.mesh as SphereMesh
		sphere.radius = build_size
		sphere.height = build_size * 2

func _physics_process(_delta):
	if not build_mode:
		return
	
	var hit_result = _raycast_terrain()
	if hit_result:
		var pos = hit_result.position + hit_result.normal * build_size
		ghost_mesh.global_position = pos
		ghost_mesh.show()
		
		var mat = ghost_mesh.material_override as StandardMaterial3D
		if mat:
			if selected_material == 0:
				mat.albedo_color = Color(1, 0, 0, 0.4)  # Red for erase
			else:
				mat.albedo_color = Color(0.2, 0.8, 0.2, 0.4)  # Green for place
	else:
		ghost_mesh.hide()

func _raycast_terrain() -> Dictionary:
	"""Raycast from camera to find terrain hit point"""
	var cam = get_camera()
	if not cam:
		return {}
		
		var mouse_pos = get_viewport().get_mouse_position()
		var from = cam.project_ray_origin(mouse_pos)
	var to = from + cam.project_ray_normal(mouse_pos) * max_reach_distance
	
		var space_state = get_parent().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
	return space_state.intersect_ray(query)
		
func _place_voxels():
	"""Place voxels using Voxdot API"""
	if not voxdot_terrain:
		push_warning("[BuildController] No VoxdotTerrain found")
		return
	
	var hit = _raycast_terrain()
	if not hit:
		return
	
	var world_pos = hit.position + hit.normal * build_size
	
	# Use Voxdot place_edit: (size, world_pos, material, shape)
	# shape: 0 = sphere, 1 = cube
	voxdot_terrain.place_edit(
		Vector3(build_size, build_size, build_size),
		world_pos,
		selected_material,
		0  # sphere
	)
	print("[BuildController] Placed voxels at ", world_pos)

func _remove_voxels():
	"""Remove voxels using Voxdot API"""
	if not voxdot_terrain:
		push_warning("[BuildController] No VoxdotTerrain found")
		return
	
	var hit = _raycast_terrain()
	if not hit:
		return
	
	var world_pos = hit.position - hit.normal * build_size * 0.5
	var radius = break_radius if enable_area_breaking else build_size
	
	# material = 0 means air (remove)
	voxdot_terrain.place_edit(
		Vector3(radius, radius, radius),
		world_pos,
		0,  # air
		0   # sphere
	)
	print("[BuildController] Removed voxels at ", world_pos)

func _show_build_info():
	"""Display build mode info"""
	print("=== Build Mode (Voxdot) ===")
	print("LMB: Place | RMB: Remove")
	print("1-3: Materials | 4: Eraser")
	print("[ ]: Adjust size")
	print("B: Exit build mode")
