# Типи і константи для системи генерації світу

# Стандартні розміри чанків (синхронізовано з TerrainGenerator)
const DEFAULT_CHUNK_SIZE := Vector2i(32, 32)
const DEFAULT_CHUNK_RADIUS := 3

# Стандартні параметри висот (синхронізовано з TerrainGenerator)
const DEFAULT_HEIGHT_AMPLITUDE := 32
const DEFAULT_BASE_HEIGHT := 16
const DEFAULT_MAX_HEIGHT := 128

# Граничні значення для налаштувань
const MIN_CHUNK_SIZE := Vector2i(16, 16)
const MAX_CHUNK_SIZE := Vector2i(128, 128)
const MIN_CHUNK_RADIUS := 3
const MAX_CHUNK_RADIUS := 20

# Типи блоків (можна розширити)
enum BlockType {
	AIR = -1,
	GRASS = 0,
	DIRT = 1,
	STONE = 2,
	SAND = 3,
	WATER = 4,
	WOOD_LOG = 5,
	LEAVES = 6
}

# Типи біомів
enum BiomeType {
	PLAINS,
	FOREST,
	DESERT,
	MOUNTAINS,
	TUNDRA,
	SWAMP
}

# Структури для зберігання даних чанків
class ChunkData:
	var position: Vector2i
	var blocks: Dictionary  # Vector3i -> BlockType
	var is_generated: bool = false
	var last_accessed: float
	
	func _init(pos: Vector2i):
		position = pos
		last_accessed = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]

# Структура для метаданих світу
class WorldMetadata:
	var seed: int
	var created_at: String
	var last_played: String
	var world_name: String
	var chunk_size: Vector2i
	var version: String = "1.0"
	
	func to_dict() -> Dictionary:
		return {
			"seed": seed,
			"created_at": created_at,
			"last_played": last_played,
			"world_name": world_name,
			"chunk_size": chunk_size,
			"version": version
		}
	
	static func from_dict(data: Dictionary) -> WorldMetadata:
		var metadata = WorldMetadata.new()
		metadata.seed = data.get("seed", 0)
		metadata.created_at = data.get("created_at", "")
		metadata.last_played = data.get("last_played", "")
		metadata.world_name = data.get("world_name", "Unnamed World")
		metadata.chunk_size = data.get("chunk_size", DEFAULT_CHUNK_SIZE)
		metadata.version = data.get("version", "1.0")
		return metadata

# Утиліти для роботи з координатами
class CoordinateUtils:
	
	static func world_to_chunk(world_pos: Vector3i, chunk_size: Vector2i) -> Vector2i:
		return Vector2i(world_pos.x / chunk_size.x, world_pos.z / chunk_size.y)
	
	static func chunk_to_world(chunk_pos: Vector2i, chunk_size: Vector2i) -> Vector3i:
		return Vector3i(chunk_pos.x * chunk_size.x, 0, chunk_pos.y * chunk_size.y)
	
	static func get_chunk_bounds(chunk_pos: Vector2i, chunk_size: Vector2i) -> Rect2i:
		var start = chunk_to_world(chunk_pos, chunk_size)
		return Rect2i(start.x, start.z, chunk_size.x, chunk_size.y)

# Конфігурація генерації
class GenerationConfig:
	var use_procedural: bool = true
	var use_chunking: bool = true
	var use_structures: bool = false
	var use_vegetation: bool = false
	var noise_seed: int = 0
	var noise_frequency: float = 0.05
	var height_amplitude: int = DEFAULT_HEIGHT_AMPLITUDE
	var base_height: int = DEFAULT_BASE_HEIGHT
	var max_height: int = DEFAULT_MAX_HEIGHT
	var chunk_size: Vector2i = DEFAULT_CHUNK_SIZE
	var chunk_radius: int = DEFAULT_CHUNK_RADIUS
	
	func to_dict() -> Dictionary:
		return {
			"use_procedural": use_procedural,
			"use_chunking": use_chunking,
			"use_structures": use_structures,
			"use_vegetation": use_vegetation,
			"noise_seed": noise_seed,
			"noise_frequency": noise_frequency,
			"height_amplitude": height_amplitude,
			"base_height": base_height,
			"max_height": max_height,
			"chunk_size": chunk_size,
			"chunk_radius": chunk_radius
		}
	
	static func from_dict(data: Dictionary) -> GenerationConfig:
		var config = GenerationConfig.new()
		config.use_procedural = data.get("use_procedural", true)
		config.use_chunking = data.get("use_chunking", true)
		config.use_structures = data.get("use_structures", false)
		config.use_vegetation = data.get("use_vegetation", false)
		config.noise_seed = data.get("noise_seed", 0)
		config.noise_frequency = data.get("noise_frequency", 0.05)
		config.height_amplitude = data.get("height_amplitude", DEFAULT_HEIGHT_AMPLITUDE)
		config.base_height = data.get("base_height", DEFAULT_BASE_HEIGHT)
		config.max_height = data.get("max_height", DEFAULT_MAX_HEIGHT)
		config.chunk_size = data.get("chunk_size", DEFAULT_CHUNK_SIZE)
		config.chunk_radius = data.get("chunk_radius", DEFAULT_CHUNK_RADIUS)
		return config
