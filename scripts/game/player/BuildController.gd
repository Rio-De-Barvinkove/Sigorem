extends Node

var build_mode = false
var selected_block_id = 1 # Start with Stone (1)

@export_group("Creative Mode Settings")
@export var enable_area_breaking = true
@export var break_radius = 2
@export var enable_xray_mode = false

var voxel_terrain: Node # VoxelTerrain
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
	# Default cube mesh for ghost
	ghost_mesh.mesh = BoxMesh.new()
	add_child(ghost_mesh)
	ghost_mesh.hide()
	
	# X-ray (not fully supported on VoxelTerrain yet without custom shader)
	xray_material = StandardMaterial3D.new()
	xray_material.albedo_color = Color(0.2, 1.0, 0.2, 0.3)
	xray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	xray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func get_voxel_terrain():
	if not is_instance_valid(voxel_terrain):
		# Try to find VoxelTerrain in the scene
		voxel_terrain = get_tree().get_root().find_child("VoxelTerrain", true, false)
	return voxel_terrain

# Removed GridMap support - now using VoxelTerrain only

func get_camera():
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	return camera

func _unhandled_input(event):
	# Toggle Build Mode
	if event.is_action_pressed("build_mode"):
		build_mode = !build_mode
		print("Build mode: ", build_mode)
		if build_mode:
			ghost_mesh.show()
			print("Build mode enabled")
		else:
			ghost_mesh.hide()

	# Cycle blocks (basic implementation)
	if build_mode and event is InputEventKey and event.pressed:
		if event.keycode >= Key.KEY_1 and event.keycode <= Key.KEY_4:
			selected_block_id = event.keycode - Key.KEY_0
			print("Selected block: ", selected_block_id)

	if build_mode and event is InputEventMouseButton and event.is_pressed():
		var cam = get_camera()
		if not cam: return

		var vt = null
		var terrain = get_voxel_terrain()
		if terrain:
			vt = terrain.get_voxel_tool()

		var mouse_pos = get_viewport().get_mouse_position()
		var from = cam.project_ray_origin(mouse_pos)
		var to = from + cam.project_ray_normal(mouse_pos) * 1000
		var space_state = get_parent().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)

		if result:
			if event.button_index == MOUSE_BUTTON_LEFT:
				# Place block (blocky terrain uses TYPE channel)
				if vt:
					vt.channel = VoxelBuffer.CHANNEL_TYPE
					vt.mode = VoxelTool.MODE_SET
					var place_pos = (result.position + result.normal * 0.5).floor()
					vt.set_voxel(place_pos, selected_block_id)
					print("Placed block ID: ", selected_block_id)

			elif event.button_index == MOUSE_BUTTON_RIGHT:
				# Destroy block (set to air = 0)
				if vt:
					vt.channel = VoxelBuffer.CHANNEL_TYPE
					vt.mode = VoxelTool.MODE_SET
					var destroy_pos = (result.position - result.normal * 0.5).floor()
					vt.set_voxel(destroy_pos, 0)  # 0 = AIR
					print("Destroyed block")

func _physics_process(_delta):
	if build_mode:
		var cam = get_camera()
		if not cam: return
		
		var mouse_pos = get_viewport().get_mouse_position()
		var from = cam.project_ray_origin(mouse_pos)
		var to = from + cam.project_ray_normal(mouse_pos) * 1000
		var space_state = get_parent().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)
		
		if result:
			# Ghost mesh positioning
			# Snap to grid?
			var pos = result.position + result.normal * 0.5 # Offset half block size
			# Snap to 1.0 grid
			pos = pos.floor() + Vector3(0.5, 0.5, 0.5)
			ghost_mesh.global_position = pos
			ghost_mesh.show()
		else:
			ghost_mesh.hide()
