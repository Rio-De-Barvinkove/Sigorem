extends Node
class_name SafeSpawn

## Створює безпечну платформу для спавну гравця перед основною генерацією.

@export var platform_half_size: Vector3 = Vector3(2.5, 0.4, 2.5) # метри (половина розміру куба)
@export var player_offset: float = 1.0 # підняти гравця над платформою

func ensure_safe_spawn(terrain: VoxdotTerrain, player: Node3D, noise: FastNoiseLite, terrain_height: float, terrain_amplitude: float, voxel_scale: float, material_ground: int) -> void:
	if not terrain or not player or not noise:
		return

	# Вихідна позиція (0,0) у світі
	var spawn_pos := Vector3.ZERO

	# Оцінка висоти терейну за шумом (співпадає з налаштуваннями VoxdotController)
	var terrain_y := terrain_height + noise.get_noise_2d(spawn_pos.x, spawn_pos.z) * terrain_amplitude
	terrain_y = max(terrain_y, 0.0)

	# Центр платформи трохи вище поверхні
	var platform_center := Vector3(spawn_pos.x, terrain_y + platform_half_size.y, spawn_pos.z)

	# Гарантуємо, що чанк для платформи створений
	var chunk_world_size := 62 * voxel_scale
	var chunk_coords := Vector3(
		floor(platform_center.x / chunk_world_size),
		floor(platform_center.y / chunk_world_size),
		floor(platform_center.z / chunk_world_size)
	)
	terrain.add_chunk(chunk_coords, false) # згенерувати чанк

	# Створити плоску платформу (куб з малою висотою), без «стовпа»
	terrain.place_edit(
		Vector3(platform_half_size.x, platform_half_size.y, platform_half_size.z),
		platform_center,
		material_ground,
		1 # cube
	)

	# Поставити гравця над платформою
	player.global_position = platform_center + Vector3(0, platform_half_size.y + player_offset, 0)

