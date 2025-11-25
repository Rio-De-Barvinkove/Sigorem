# Інтеграція Voxdot з системою генерації террейну

## Огляд

Проєкт підтримує два генератори террейну:
- **Zylann (VoxelTools)** - GDScript-based, працює зараз
- **Voxdot** - C++ модуль, потребує збірки

## Поточний статус

Voxdot знаходиться в папці `Voxdot-0.7.0/`, але модуль не зібрано. Помилки в логах:
```
ERROR: GDExtension dynamic library not found: 'res://Voxdot-0.7.0/modules/text_server_adv/gdextension_build/text_server_adv.gdextension'
```

Це означає, що Voxdot потребує збірки як частина Godot Engine або як GDExtension.

## Варіанти інтеграції

### Варіант 1: Збірка Voxdot як частина Godot Engine (рекомендовано)

1. **Потрібно зібрати Godot з модулем Voxdot:**
   ```bash
   # В папці Voxdot-0.7.0
   scons target=editor
   # або
   scons target=template_debug
   ```

2. **Або використати готовий бінарник Godot з Voxdot**

3. **Після збірки VoxdotTerrain буде доступний в редакторі**

### Варіант 2: GDExtension (якщо доступний)

Якщо є готовий GDExtension файл для Voxdot:
1. Скопіювати `.gdextension` файл в проєкт
2. Додати в `project.godot`:
   ```
   [autoload]
   VoxdotExtension="*res://path/to/voxdot.gdextension"
   ```

## Використання TerrainManager

`TerrainManager` автоматично визначає доступні генератори та перемикається між ними.

### В сцені:

```gdscript
# Додати TerrainManager як дочірній вузол VoxelWorld
[node name="TerrainManager" type="Node3D" parent="."]
script = ExtResource("path/to/TerrainManager.gd")
terrain_type = 0  # 0 = ZYLANN, 1 = VOXDOT
auto_switch = true  # Автоматично використовувати Voxdot, якщо доступний
```

### В коді:

```gdscript
var terrain_manager = $TerrainManager
var active_terrain = terrain_manager.get_active_terrain()

# Перемикання між генераторами
terrain_manager.switch_terrain(TerrainManager.TerrainType.VOXDOT)

# Перевірка доступності
if terrain_manager.is_voxdot_available():
    print("Voxdot доступний!")
```

## VoxdotTerrainAdapter

Адаптер для роботи з Voxdot через уніфікований інтерфейс:

```gdscript
var voxdot_terrain = get_node("VoxdotTerrain")
var adapter = VoxdotTerrainAdapter.new(voxdot_terrain)

if adapter.is_available():
    adapter.initialize(noise_seed=1337, voxel_scale=0.1)
    adapter.set_noise(noise_resource)
    adapter.add_chunk(Vector3(0, 0, 0))
```

## Порівняння Zylann vs Voxdot

| Функція | Zylann (VoxelTools) | Voxdot |
|---------|---------------------|--------|
| **Мова** | GDScript | C++ |
| **Статус** | ✅ Працює | ⚠️ Потребує збірки |
| **LOD** | ✅ Підтримує | ❓ Не визначено |
| **SDF** | ✅ VoxelMesherTransvoxel | ✅ Нативна підтримка |
| **Продуктивність** | Добра | Краща (C++) |
| **Гнучкість** | Висока (GDScript) | Середня (C++) |

## Наступні кроки

1. **Зібрати Voxdot модуль** або знайти готовий бінарник
2. **Протестувати VoxdotTerrain** після збірки
3. **Налаштувати генерацію** через VoxdotTerrainAdapter
4. **Додати перемикання** між генераторами в UI

## Примітки

- Voxdot працює з SDF (Signed Distance Field), як і наш поточний генератор
- Voxdot має власну систему біомів через `set_biomes()`
- Voxdot використовує `FastNoiseLite` (як і Zylann)
- Voxdot має пул мешів для оптимізації (`mesh_instance_pool`)






