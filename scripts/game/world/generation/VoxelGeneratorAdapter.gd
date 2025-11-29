@tool
extends VoxelGeneratorScript
class_name VoxelGeneratorAdapter

## Blocky terrain generator (Minecraft-style)
## Creates terrain with visible voxel blocks

# Block types
const BLOCK_AIR := 0
const BLOCK_STONE := 1
const BLOCK_DIRT := 2
const BLOCK_GRASS := 3
const BLOCK_SAND := 4
const BLOCK_GRAVEL := 5

# Noise generators
var _continent_noise: FastNoiseLite
var _mountain_noise: FastNoiseLite
var _hill_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _cave_noise: FastNoiseLite

# Terrain parameters
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

# Layer depths
@export var grass_depth: int = 1
@export var dirt_depth: int = 4

# Debug
var _debug_printed := false

func _init():
	resource_name = "BlockyTerrainGenerator"
	_setup_noise()

func _setup_noise():
	# Continent noise - large scale landmasses
	_continent_noise = FastNoiseLite.new()
	_continent_noise.seed = world_seed
	_continent_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continent_noise.frequency = 1.0 / continent_scale
	_continent_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_continent_noise.fractal_octaves = 3
	_continent_noise.fractal_lacunarity = 2.0
	_continent_noise.fractal_gain = 0.5
	
	# Mountain noise - ridged for peaks
	_mountain_noise = FastNoiseLite.new()
	_mountain_noise.seed = world_seed + 1000
	_mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mountain_noise.frequency = 1.0 / mountain_scale
	_mountain_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_mountain_noise.fractal_octaves = 5
	_mountain_noise.fractal_lacunarity = 2.0
	_mountain_noise.fractal_gain = 0.6
	
	# Hill noise
	_hill_noise = FastNoiseLite.new()
	_hill_noise.seed = world_seed + 2000
	_hill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_hill_noise.frequency = 1.0 / hill_scale
	_hill_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hill_noise.fractal_octaves = 4
	_hill_noise.fractal_lacunarity = 2.0
	_hill_noise.fractal_gain = 0.5
	
	# Detail noise
	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = world_seed + 3000
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 1.0 / detail_scale
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail_noise.fractal_octaves = 3
	_detail_noise.fractal_lacunarity = 2.5
	_detail_noise.fractal_gain = 0.6
	
	# Cave noise - 3D
	_cave_noise = FastNoiseLite.new()
	_cave_noise.seed = world_seed + 4000
	_cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cave_noise.frequency = 1.0 / cave_scale
	_cave_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_cave_noise.fractal_octaves = 2
	
	push_warning("[Generator] Initialized: seed=%d, base=%.0f, max=%.0f" % [world_seed, base_height, max_height])

func _get_used_channels_mask() -> int:
	# BLOCKY terrain uses CHANNEL_TYPE for block IDs
	return 1 << VoxelBuffer.CHANNEL_TYPE

func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int):
	var size := out_buffer.get_size()
	var lod_scale := 1 << lod
	
	if not _debug_printed:
		push_warning("[Generator] First block: origin=%s, size=%s, lod=%d" % [origin, size, lod])
		_debug_printed = true
	
	var block_min_y := origin.y
	var block_max_y := origin.y + size.y * lod_scale
	
	# Quick fill for blocks far above terrain - all air
	if block_min_y > max_height + 10:
		out_buffer.fill(BLOCK_AIR, VoxelBuffer.CHANNEL_TYPE)
		return
	
	# Quick fill for blocks far below terrain - all stone
	if block_max_y < 0:
		out_buffer.fill(BLOCK_STONE, VoxelBuffer.CHANNEL_TYPE)
		return
	
	# Generate voxel by voxel
	for z in size.z:
		var world_z := origin.z + z * lod_scale
		var fz := float(world_z)
		
		for x in size.x:
			var world_x := origin.x + x * lod_scale
			var fx := float(world_x)
			
			# Calculate terrain height at this column
			var surface_height := int(_get_terrain_height(fx, fz))
			
			for y in size.y:
				var world_y := origin.y + y * lod_scale
				
				var block_type := _get_block_type(world_x, world_y, world_z, surface_height)
				out_buffer.set_voxel(block_type, x, y, z, VoxelBuffer.CHANNEL_TYPE)
	
	out_buffer.compress_uniform_channels()

func _get_block_type(world_x: int, world_y: int, world_z: int, surface_height: int) -> int:
	# Above surface = air
	if world_y > surface_height:
		return BLOCK_AIR
	
	# Check for caves
	if world_y < surface_height - cave_min_depth:
		var cave := _cave_noise.get_noise_3d(float(world_x), float(world_y), float(world_z))
		if cave > cave_threshold:
			return BLOCK_AIR  # Cave
	
	# Surface layers
	var depth := surface_height - world_y
	
	if depth == 0:
		# Top layer - grass
		return BLOCK_GRASS
	elif depth <= dirt_depth:
		# Under grass - dirt
		return BLOCK_DIRT
	else:
		# Deep underground - stone
		return BLOCK_STONE

func _get_terrain_height(x: float, z: float) -> float:
	# Continent layer - large scale
	var continent := _continent_noise.get_noise_2d(x, z)
	continent = (continent + 1.0) * 0.5  # Normalize to 0-1
	continent = continent * continent  # Smooth falloff
	
	# Mountain layer - ridged for dramatic peaks
	var mountain := _mountain_noise.get_noise_2d(x, z)
	mountain = abs(mountain)
	mountain = mountain * mountain * 1.5
	
	# Hill layer - medium scale variation
	var hill := _hill_noise.get_noise_2d(x, z)
	hill = (hill + 1.0) * 0.5
	
	# Detail layer - small bumps
	var detail := _detail_noise.get_noise_2d(x, z)
	
	# Combine all layers
	var height_factor := 0.0
	height_factor += continent * continent_weight
	height_factor += mountain * mountain_weight
	height_factor += hill * hill_weight
	height_factor += detail * detail_weight
	
	var height_range := max_height - base_height
	return base_height + height_factor * height_range
