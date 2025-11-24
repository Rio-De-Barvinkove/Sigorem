@tool
extends VoxelStreamScript
class_name VoxelStreamAdapter

# Адаптер для потокового завантаження/збереження воксельних даних

func _init():
	resource_name = "VoxelStreamAdapter"

func _get_used_channels_mask() -> int:
	# VoxelMesherTransvoxel використовує SDF канал
	var mask = 1 << VoxelBuffer.CHANNEL_SDF
	return mask

func _load_voxel_block(out_buffer: VoxelBuffer, position: Vector3i, lod: int) -> int:
	# VoxelTerrain завжди викликає з lod=0, але зберігаємо lod в імені файлу для сумісності
	var file_path = "user://voxel_world/block_%d_%d_%d_lod%d.dat" % [position.x, position.y, position.z, lod]

	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var file_data = file.get_buffer(file.get_length())
			file.close()

			# Розпаковуємо дані (якщо стиснуті)
			# Ініціалізуємо data як file_data на випадок порожнього файлу або помилки розпакування
			var data: PackedByteArray = file_data
			if file_data.size() > 0:
				# Спробуємо розпакувати (якщо стиснуто DEFLATE)
				# decompress_dynamic() підтримує тільки BROTLI, GZIP, DEFLATE
				var decompressed = file_data.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
				# Якщо розпакування вдалося, використовуємо розпаковані дані
				if not decompressed.is_empty():
					data = decompressed
				# Якщо розпакування не вдалося (старий формат без стиснення або інший формат), data вже = file_data

			# Завантажуємо дані через PackedByteArray
			var result = out_buffer.deserialize(data)
			if result == OK:
				return 2  # RESULT_BLOCK_FOUND - чанк знайдено та завантажено
			else:
				push_error("VoxelStreamAdapter: Error deserializing block: " + file_path)
				return 0  # RESULT_ERROR - помилка десеріалізації
		else:
			push_error("VoxelStreamAdapter: Error opening file: " + file_path)
			return 0  # RESULT_ERROR - помилка завантаження
	else:
		# Чанк не знайдено - потрібно генерувати
		return 1  # RESULT_BLOCK_NOT_FOUND - VoxelLodTerrain запустить генератор

func _save_voxel_block(buffer: VoxelBuffer, position: Vector3i, lod: int) -> void:
	# VoxelTerrain завжди викликає з lod=0, але зберігаємо lod в імені файлу для сумісності
	var dir_path = "user://voxel_world"
	var file_path = "user://voxel_world/block_%d_%d_%d_lod%d.dat" % [position.x, position.y, position.z, lod]

	# Створюємо директорію якщо не існує
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		# Серіалізуємо буфер у PackedByteArray
		var data = buffer.serialize()
		# Стискаємо дані для економії місця (тільки якщо дані достатньо великі)
		# Використовуємо DEFLATE, оскільки decompress_dynamic() підтримує тільки BROTLI, GZIP, DEFLATE
		var compressed_data: PackedByteArray
		if data.size() > 1024:  # Стискаємо тільки великі блоки
			compressed_data = data.compress(FileAccess.COMPRESSION_DEFLATE)
			# Якщо стиснення не дало виграшу, зберігаємо оригінал
			if compressed_data.size() >= data.size():
				compressed_data = data
		else:
			compressed_data = data
		file.store_buffer(compressed_data)
		file.close()
	else:
		push_error("VoxelStreamAdapter: Error saving block: " + file_path)

func _get_block_size() -> int:
	return 16

func _get_lod_count() -> int:
	# VoxelTerrain не використовує LOD, але метод може викликатися
	return 0
