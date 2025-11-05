# Керування генерацією терейну

## Як TerrainGenerator взаємодіє з GridMap

`TerrainGenerator` є центральним менеджером, який координує всі модулі генерації. Він має пряме посилання на `GridMap` через змінну `target_gridmap`.

### Архітектура:

1. **WorldGenerator (GridMap)** → має `TerrainGenerator` як дочірній вузол
2. **TerrainGenerator** → координує всі модулі:
   - `ProceduralGeneration` - базова процедурна генерація
   - `ChunkManager` - управління чанками
   - `OptimizationManager` - оптимізація продуктивності
   - і інші модулі

3. **Модулі** → безпосередньо викликають `gridmap.set_cell_item()` для встановлення блоків

## Як змінювати генерацію

### Через інспектор Godot:

1. Відкрийте сцену `world.tscn`
2. Виберіть вузол `GridMap` (або дочірній вузол `TerrainGenerator`, якщо він створений)
3. В панелі **Inspector** ви побачите всі `@export` параметри:

#### Основні налаштування:
- `target_gridmap` - посилання на GridMap (встановлюється автоматично)
- `player` - посилання на гравця (для chunking)

#### Модулі генерації:
- `use_procedural_generation` - вмикає/вимикає базову процедурну генерацію
- `use_chunking` - вмикає/вимикає систему чанків
- `use_structures` - генерація структур (WFC)
- `use_vegetation` - генерація рослинності
- `use_optimization` - оптимізація продуктивності
- і інші...

#### Параметри процедурної генерації:
- `noise` - FastNoiseLite для генерації шуму
- `chunk_size` - розмір чанка (за замовчуванням 50x50)
- `chunk_radius` - радіус генерації чанків (за замовчуванням 5)
- `height_amplitude` - амплітуда висоти (за замовчуванням 5)
- `base_height` - базова висота (за замовчуванням 5)

#### Параметри chunking:
- `enable_chunk_culling` - вмикає/вимикає видалення далеких чанків
- `max_chunk_distance` - максимальна відстань для чанків (за замовчуванням 100.0)

### Через OptimizationManager:

- `max_generation_time_per_frame` - ліміт часу генерації на кадр (мс)
- `max_initial_generation_time` - ліміт часу для початкової генерації (мс)
- `log_performance_warnings` - вмикає/вимикає логи продуктивності
- `enable_initial_generation_override` - дозволити тривалу генерацію на старті

## Типові проблеми та рішення

### Порожній екран після генерації:

1. **Перевірте MeshLibrary**: GridMap має мати встановлений `mesh_library` з `BlockRegistry`
2. **Перевірте позицію камери**: камера має дивитися на згенерований терейн
3. **Перевірте позицію гравця**: гравець має бути на терейні або над ним
4. **Збільште ліміт часу**: якщо багато "Генерація перервана", збільште `max_initial_generation_time`

### Низька продуктивність:

1. Зменште `chunk_radius` (наприклад, з 5 до 3)
2. Вимкніть `use_vegetation` та інші складні модулі
3. Увімкніть `use_optimization` та налаштуйте `OptimizationManager`
4. Зменште `chunk_size` (наприклад, з 50x50 до 25x25)

### Багато логів:

1. Вимкніть `log_performance_warnings` в `OptimizationManager`
2. Переконайтеся, що `is_initial_generation` правильно працює

## Приклад налаштування для швидкого тестування:

```
use_procedural_generation = true
use_chunking = true
use_optimization = true
use_vegetation = false
use_structures = false
chunk_radius = 3
chunk_size = Vector2i(25, 25)
max_initial_generation_time = 1000.0
log_performance_warnings = false
```

