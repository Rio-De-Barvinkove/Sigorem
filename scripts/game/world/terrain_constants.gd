extends Resource
class_name TerrainConstants
## Глобальні константи для воксельної системи терайну

# Розміри чанків
const CHUNK_SIZE: int = 62  ## Внутрішній розмір чанка (з mesher.h)
const REGION_SIZE: int = 32  ## 32x32 чанки в регіоні (для збереження)

# Таймери та інтервали
const AUTO_SAVE_INTERVAL: float = 300.0  ## Автозбереження кожні 5 хвилин
const PERFORMANCE_LOG_THRESHOLD: int = 10000  ## Логувати тільки якщо час > 10ms

# Ліміти обробки
const DEFAULT_CHUNKS_PER_FRAME: int = 2  ## Скільки чанків обробляти за кадр
const MAX_MODIFICATIONS_PER_FRAME: int = 200  ## Максимум модифікацій для batch

# Дефолтні значення терайну
const DEFAULT_VOXEL_SCALE: float = 0.1  ## Розмір вокселя в метрах
const DEFAULT_VIEW_DISTANCE: int = 4  ## Радіус в чанках
const DEFAULT_POOL_SIZE: int = 500  ## Розмір пулу для вокселів

# Матеріали
const MATERIAL_AIR: int = 0  ## Повітря/порожнеча
const MATERIAL_STONE: int = 1  ## Камінь
const MATERIAL_GROUND: int = 2  ## Грунт/трава

# Формат збереження
const SAVE_VERSION: String = "1.0"
const COMPRESSED_HEADER: String = "VOXDOT_CHUNK_V1_COMPRESSED\n"

## Конвертувати світові координати в координати чанка
static func world_to_chunk(world_pos: Vector3, voxel_scale: float) -> Vector3:
	var chunk_world_size = CHUNK_SIZE * voxel_scale
	return Vector3(
		floor(world_pos.x / chunk_world_size),
		floor(world_pos.y / chunk_world_size),
		floor(world_pos.z / chunk_world_size)
	)

## Конвертувати координати чанка в координати регіону
static func chunk_to_region(chunk_coords: Vector3) -> Vector3:
	return Vector3(
		floor(chunk_coords.x / REGION_SIZE),
		0,  # Y не використовується для регіонів
		floor(chunk_coords.z / REGION_SIZE)
	)

## Перевірити чи координати в межах радіусу
static func is_in_radius(center: Vector3, point: Vector3, radius: int) -> bool:
	var delta = point - center
	var dist_sq = delta.x * delta.x + delta.z * delta.z  # Тільки XZ відстань
	return dist_sq <= radius * radius

