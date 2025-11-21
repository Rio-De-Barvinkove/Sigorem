@tool
extends VoxelStreamScript
class_name VoxelStreamAdapter

# Адаптер для потокового завантаження/збереження воксельних даних

func _init():
	resource_name = "VoxelStreamAdapter"

func _get_used_channels_mask() -> int:
	var mask = 1 << VoxelBuffer.CHANNEL_TYPE
	# print("Used channels mask: ", mask, " (CHANNEL_TYPE = ", VoxelBuffer.CHANNEL_TYPE, ")")
	return mask

func _load_voxel_block(out_buffer: VoxelBuffer, position: Vector3i, lod: int) -> int:
	var file_path = "user://voxel_world/block_%d_%d_%d_lod%d.dat" % [position.x, position.y, position.z, lod]

	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var data = file.get_buffer(file.get_length())
			file.close()

			# Завантажуємо дані через PackedByteArray
			var result = out_buffer.deserialize(data)
			if result == OK:
				return 0  # Чанк знайдено та завантажено
			else:
				push_error("VoxelStreamAdapter: Error deserializing block: " + file_path)
				return 1  # Помилка десеріалізації
		else:
			push_error("VoxelStreamAdapter: Error opening file: " + file_path)
			return 1  # Помилка завантаження
	else:
		# Чанк не знайдено - потрібно генерувати
		return 1

func _save_voxel_block(buffer: VoxelBuffer, position: Vector3i, lod: int) -> void:
	var dir_path = "user://voxel_world"
	var file_path = "user://voxel_world/block_%d_%d_%d_lod%d.dat" % [position.x, position.y, position.z, lod]

	# Створюємо директорію якщо не існує
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		# Серіалізуємо буфер у PackedByteArray
		var data = buffer.serialize()
		file.store_buffer(data)
		file.close()
	else:
		push_error("VoxelStreamAdapter: Error saving block: " + file_path)

func _get_block_size() -> int:
	return 16

func _get_lod_count() -> int:
	return 3
