@tool
extends VoxelGeneratorScript
class_name VoxelGeneratorSmooth

## Smooth terrain generator (SDF-based)
## Creates smooth terrain using Signed Distance Field

# Noise generators (same as blocky generator for consistency)
var _continent_noise: FastNoiseLite
var _mountain_noise: FastNoiseLite
var _hill_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _cave_noise: FastNoiseLite

# Terrain parameters (same as blocky generator)
@export var world_seed: int = 1337
@export var base_height: float = 40.0
@export var max_height: float = 150.0

# Noise scales
@export var continent_scale: float = 600.0
@export var mountain_scale: float = 150.0
@export var hill_scale: float = 60.0
@export var detail_scale: float = 15.0

# Amplitude weights
@export var continent_weight: float = 0.35
@export var mountain_weight: float = 0.4
@export var hill_weight: float = 0.2
@export var detail_weight: float = 0.05

# Cave parameters
@export var cave_scale: float = 25.0
@export var cave_threshold: float = 0.65
@export var cave_min_depth: float = 8.0

# SDF parameters
@export var sdf_scale: float = 1.0  # How sharp the surface is

# Blocky/Smooth mixing parameters
@export var blocky_steepness_threshold: float = 0.3  # Steepness above which terrain becomes blocky
@export var blocky_voxel_size: float = 1.0  # Size of blocky voxels (for quantization)
@export var blocky_mix_factor: float = 0.5  # How much blocky vs smooth (0 = all smooth, 1 = all blocky)

# Debug
var _debug_printed := false

func _init():
	resource_name = "SmoothTerrainGenerator"
	_setup_noise()

func _setup_noise():
	# Same noise setup as blocky generator for consistency
	_continent_noise = FastNoiseLite.new()
	_continent_noise.seed = world_seed
	_continent_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continent_noise.frequency = 1.0 / continent_scale
	_continent_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_continent_noise.fractal_octaves = 3
	_continent_noise.fractal_lacunarity = 2.0
	_continent_noise.fractal_gain = 0.5
	
	_mountain_noise = FastNoiseLite.new()
	_mountain_noise.seed = world_seed + 1000
	_mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mountain_noise.frequency = 1.0 / mountain_scale
	_mountain_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_mountain_noise.fractal_octaves = 5
	_mountain_noise.fractal_lacunarity = 2.0
	_mountain_noise.fractal_gain = 0.6
	
	_hill_noise = FastNoiseLite.new()
	_hill_noise.seed = world_seed + 2000
	_hill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_hill_noise.frequency = 1.0 / hill_scale
	_hill_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hill_noise.fractal_octaves = 4
	_hill_noise.fractal_lacunarity = 2.0
	_hill_noise.fractal_gain = 0.5
	
	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = world_seed + 3000
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 1.0 / detail_scale
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail_noise.fractal_octaves = 3
	_detail_noise.fractal_lacunarity = 2.5
	_detail_noise.fractal_gain = 0.6
	
	_cave_noise = FastNoiseLite.new()
	_cave_noise.seed = world_seed + 4000
	_cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cave_noise.frequency = 1.0 / cave_scale
	_cave_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_cave_noise.fractal_octaves = 2
	
	push_warning("[SmoothGenerator] Initialized: seed=%d, base=%.0f, max=%.0f" % [world_seed, base_height, max_height])

func _get_used_channels_mask() -> int:
	# SMOOTH terrain uses CHANNEL_SDF
	return 1 << VoxelBuffer.CHANNEL_SDF

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int):
	var size := out_buffer.get_size()
	var lod_scale := 1 << lod
	
	if not _debug_printed:
		push_warning("[SmoothGenerator] First block: origin=%s, size=%s, lod=%d" % [origin, size, lod])
		_debug_printed = true
	
	# Generate SDF values with mixed smooth/blocky terrain
	for z in size.z:
		var world_z := origin.z + z * lod_scale
		var fz := float(world_z)
		
		for x in size.x:
			var world_x := origin.x + x * lod_scale
			var fx := float(world_x)
			
			# Calculate terrain height at this column
			var surface_height := _get_terrain_height(fx, fz)
			
			# Calculate steepness (gradient) at this point
			var steepness := _get_steepness(fx, fz)
			
			# Determine if this area should be blocky or smooth
			var is_blocky := steepness > blocky_steepness_threshold
			
			for y in size.y:
				var world_y := origin.y + y * lod_scale
				var fy := float(world_y)
				
				var sdf_value: float
				
				# Generate both smooth and blocky SDF
				var smooth_sdf = _generate_smooth_sdf(fx, fy, fz, surface_height)
				var blocky_sdf = _generate_blocky_sdf(fx, fy, fz, surface_height)
				
				# Mix based on steepness and mix_factor
				var blocky_weight := 0.0
				if is_blocky:
					# Steep areas: use blocky
					blocky_weight = 1.0
				else:
					# Flat areas: use smooth, but allow some blocky via mix_factor
					blocky_weight = blocky_mix_factor * 0.3  # Less blocky on flat areas
				
				# Interpolate between smooth and blocky
				sdf_value = lerp(smooth_sdf, blocky_sdf, blocky_weight)
				
				out_buffer.set_voxel_f(sdf_value, x, y, z, VoxelBuffer.CHANNEL_SDF)
	
	out_buffer.compress_uniform_channels()

func _get_terrain_height(x: float, z: float) -> float:
	# Same height calculation as blocky generator
	var continent := _continent_noise.get_noise_2d(x, z)
	continent = (continent + 1.0) * 0.5
	continent = continent * continent
	
	var mountain := _mountain_noise.get_noise_2d(x, z)
	mountain = abs(mountain)
	mountain = mountain * mountain * 1.5
	
	var hill := _hill_noise.get_noise_2d(x, z)
	hill = (hill + 1.0) * 0.5
	
	var detail := _detail_noise.get_noise_2d(x, z)
	
	var height_factor := 0.0
	height_factor += continent * continent_weight
	height_factor += mountain * mountain_weight
	height_factor += hill * hill_weight
	height_factor += detail * detail_weight
	
	var height_range := max_height - base_height
	return base_height + height_factor * height_range

func _get_steepness(x: float, z: float) -> float:
	"""Calculate terrain steepness (gradient) at position"""
	# Sample height at nearby points to calculate gradient
	var sample_distance := 2.0
	var height_here := _get_terrain_height(x, z)
	var height_x := _get_terrain_height(x + sample_distance, z)
	var height_z := _get_terrain_height(x, z + sample_distance)
	
	# Calculate gradient magnitude
	var dx := (height_x - height_here) / sample_distance
	var dz := (height_z - height_here) / sample_distance
	var gradient := sqrt(dx * dx + dz * dz)
	
	# Normalize to 0-1 range (assuming max gradient is around 1.0)
	return clamp(gradient, 0.0, 1.0)

func _generate_smooth_sdf(x: float, y: float, z: float, surface_height: float) -> float:
	"""Generate smooth SDF value"""
	var distance_to_surface := y - surface_height
	
	# Add cave noise for underground variation
	if y < surface_height - cave_min_depth:
		var cave := _cave_noise.get_noise_3d(x, y, z)
		if cave > cave_threshold:
			# Make caves by pushing surface up
			distance_to_surface += (cave - cave_threshold) * 10.0
	
	# Convert to SDF range (-127 to 127)
	return clamp(distance_to_surface * sdf_scale, -127.0, 127.0)

func _generate_blocky_sdf(x: float, y: float, z: float, surface_height: float) -> float:
	"""Generate blocky SDF value through quantization"""
	# Quantize position to create discrete "voxel" boundaries
	var quantized_x: float = floor(x / blocky_voxel_size) * blocky_voxel_size
	var quantized_z: float = floor(z / blocky_voxel_size) * blocky_voxel_size
	var quantized_y: float = floor(y / blocky_voxel_size) * blocky_voxel_size
	
	# Get height at quantized position
	var quantized_height: float = _get_terrain_height(quantized_x, quantized_z)
	var quantized_surface: float = floor(quantized_height / blocky_voxel_size) * blocky_voxel_size
	
	# Calculate distance to quantized surface
	var distance_to_surface: float = y - quantized_surface
	
	# Make it more discrete (sharp transitions)
	# Use step function to create hard boundaries
	if abs(distance_to_surface) < blocky_voxel_size * 0.5:
		# Near surface - make it solid
		distance_to_surface = -blocky_voxel_size * 0.3
	else:
		# Far from surface - make it air
		distance_to_surface = abs(distance_to_surface) * sign(distance_to_surface)
	
	# Convert to SDF range (-127 to 127)
	return clamp(distance_to_surface * sdf_scale * 2.0, -127.0, 127.0)

