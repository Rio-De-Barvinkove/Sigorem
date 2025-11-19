extends VoxelStreamScript
class_name VoxelStreamAdapter

# Адаптер для потокового завантаження/збереження воксельних даних

func _init():
	resource_name = "VoxelStreamAdapter"

func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE

func _load_voxel_block(out_buffer: VoxelBuffer, position: Vector3i, lod: int) -> int:
	# Повертаємо 1 щоб вказати, що блок не знайдено і потрібно генерувати
	# Генератор заповнить буфер автоматично
	return 1

func _save_voxel_block(buffer: VoxelBuffer, position: Vector3i, lod: int) -> void:
	# Тут можна реалізувати збереження блоків на диск
	# Зараз просто ігноруємо - дані зберігаються в пам'яті
	pass

func _get_block_size() -> int:
	return 16

func _get_lod_count() -> int:
	return 5
