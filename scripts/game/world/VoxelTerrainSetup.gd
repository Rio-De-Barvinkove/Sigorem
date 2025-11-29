extends VoxelTerrain

# Microvoxel terrain setup script
# Handles VoxelViewer management and terrain configuration

var _viewer: VoxelViewer = null
var _player_ref: Node3D = null

func _enter_tree():
	# Configure terrain for microvoxels
	max_view_distance = 256
	mesh_block_size = 16
	generate_collisions = true

func _ready():
	_setup_viewer()
	call_deferred("_print_diagnostics")

func _setup_viewer():
	# Find player node
	_player_ref = _find_player()
	
	if _player_ref:
		# Create VoxelViewer as child of player for automatic position tracking
		_viewer = VoxelViewer.new()
		_viewer.name = "VoxelViewer"
		_viewer.view_distance = max_view_distance
		_viewer.requires_visuals = true
		_viewer.requires_collisions = true
		_player_ref.add_child(_viewer)
		push_warning("[VoxelTerrain] VoxelViewer created and attached to player: %s" % _player_ref.name)
	else:
		# Fallback: create viewer at origin
		_viewer = VoxelViewer.new()
		_viewer.name = "VoxelViewer"
		_viewer.view_distance = max_view_distance
		_viewer.requires_visuals = true
		_viewer.requires_collisions = false
		add_child(_viewer)
		push_warning("[VoxelTerrain] VoxelViewer created at terrain (no player found)")

func _find_player() -> Node3D:
	# Try to find player in parent scene
	var parent = get_parent()
	if parent:
		var player = parent.get_node_or_null("Player")
		if player and player is Node3D:
			return player
		# Try to find any CharacterBody3D
		for child in parent.get_children():
			if child is CharacterBody3D:
				return child
	return null

func _print_diagnostics():
	push_warning("[VoxelTerrain] === DIAGNOSTICS ===")
	push_warning("[VoxelTerrain] max_view_distance = %d" % max_view_distance)
	push_warning("[VoxelTerrain] mesh_block_size = %d" % mesh_block_size)
	push_warning("[VoxelTerrain] generate_collisions = %s" % generate_collisions)
	
	if generator:
		var gen_name = generator.resource_name if generator.resource_name else generator.get_class()
		push_warning("[VoxelTerrain] Generator: %s" % gen_name)
		
		# Check channel mask
		if generator.has_method("_get_used_channels_mask"):
			var mask = generator._get_used_channels_mask()
			var uses_sdf = (mask & (1 << VoxelBuffer.CHANNEL_SDF)) != 0
			var uses_type = (mask & (1 << VoxelBuffer.CHANNEL_TYPE)) != 0
			push_warning("[VoxelTerrain] Generator channels: SDF=%s, TYPE=%s" % [uses_sdf, uses_type])
	else:
		push_error("[VoxelTerrain] ERROR: No generator!")
	
	if stream:
		push_warning("[VoxelTerrain] Stream: %s" % (stream.resource_name if stream.resource_name else stream.get_class()))
	else:
		push_warning("[VoxelTerrain] Stream: None (generation only)")
	
	if mesher:
		var mesher_type = mesher.get_class()
		var expected_channel = "UNKNOWN"
		
		if mesher is VoxelMesherTransvoxel:
			mesher_type = "VoxelMesherTransvoxel"
			expected_channel = "CHANNEL_SDF"
		elif mesher is VoxelMesherCubes:
			mesher_type = "VoxelMesherCubes"
			expected_channel = "CHANNEL_TYPE or CHANNEL_COLOR"
		elif mesher is VoxelMesherBlocky:
			mesher_type = "VoxelMesherBlocky"
			expected_channel = "CHANNEL_TYPE"
			if mesher.library:
				push_warning("[VoxelTerrain] Library: %s" % mesher.library.resource_path)
			else:
				push_error("[VoxelTerrain] ERROR: No library in VoxelMesherBlocky!")
		
		push_warning("[VoxelTerrain] Mesher: %s (expects %s)" % [mesher_type, expected_channel])
	else:
		push_error("[VoxelTerrain] ERROR: No mesher!")
	
	# VoxelTerrain uses 'material_override' not 'material'
	if has_method("get_material_override"):
		var mat = get_material_override()
		if mat:
			push_warning("[VoxelTerrain] Material: %s" % mat.get_class())
		else:
			push_warning("[VoxelTerrain] Material: None (default)")
	else:
		push_warning("[VoxelTerrain] Material: Check inspector")
	
	if _viewer:
		push_warning("[VoxelTerrain] VoxelViewer: OK (view_distance=%d)" % _viewer.view_distance)
	else:
		push_error("[VoxelTerrain] ERROR: No VoxelViewer!")
	
	push_warning("[VoxelTerrain] === END DIAGNOSTICS ===")
