# Voxel Reference Algorithms

Документація алгоритмів та систем з референсного проекту `voxel_game_refference` (Zylann's voxelgame).

---

# Зміст

1. [Blocky Fluid](#1-blocky-fluid)
2. [Blocky Terrain](#2-blocky-terrain)
3. [Blocky Game](#3-blocky-game)
4. [Smooth Terrain](#4-smooth-terrain)
5. [Smooth Materials](#5-smooth-materials)
6. [Multipass Generator](#6-multipass-generator)
7. [Common Utilities](#7-common-utilities)

---

# 1. Blocky Fluid

Симуляція рідини для воксельного террейну з 8 рівнями висоти.

## Архітектура

### Компоненти

1. **VoxelTerrain** з `VoxelMesherBlocky`
2. **VoxelBlockyLibrary** з 8 моделями рідини (water0–water7)
3. Система подвійних черг для оновлення вокселів
4. Шейдер для анімації потоку текстури

### Структура даних

**VoxelBlockyModelFluid:**
- `level` (0–7) — висота рідини в вокселі
- `transparency_index = 2` — індекс прозорості
- `dip_when_flowing_down = true` — нахил моделі при падінні

## Алгоритм симуляції

### Система черг

Подвійна черга для запобігання конфліктів:

```gdscript
_update_queue      # Поточна ітерація обробки
_next_update_queue # Наступна ітерація (накопичується)
```

### Таймер оновлення

- **Інтервал:** `_tick_interval = 0.125` секунд (8 тіків на секунду)

### Логіка оновлення вокселя

**Крок 1: Падіння вниз**
```
Якщо нижче повітря (_air_id):
  Встановити max_level (water7)
  Додати позицію в _next_update_queue
```

**Крок 2: Заповнення нижнього рівня**
```
Якщо нижче рідина з level < max_level:
  Встановити max_level
  Додати позицію в _next_update_queue
```

**Крок 3: Розтікання горизонтально**
```
Якщо level > 0:
  next_level = level - 1
  Для кожного горизонтального сусіда:
    Якщо сусід = повітря або рідина з level < next_level:
      Встановити next_level
      Додати в _next_update_queue
```

### Напрямки сусідів

```gdscript
_horizontal_neighbor_directions = [
  Vector3i(-1, 0, 0),  // Захід
  Vector3i(1, 0, 0),   // Схід
  Vector3i(0, 0, -1),  // Північ
  Vector3i(0, 0, 1),   // Південь
]
```

## Шейдер анімації потоку

### Визначення напрямку

```glsl
angle = src_uv.y * (TAU / 8.0)
flow_dir = vec2(-cos(angle), sin(angle))
```

### Зміщення UV за часом

```glsl
uv += TIME * flow_dir
```

## Обмеження

1. Рідина не видаляється автоматично
2. Немає розрізнення джерела та падаючої води
3. Черга може рости необмежено

---

# 2. Blocky Terrain

Класична Minecraft-style реалізація воксельного террейну.

## Архітектура

### Компоненти

1. **VoxelTerrain** - базовий воксельний террейн
2. **VoxelGeneratorNoise2D** - генератор на основі 2D шуму
3. **VoxelMesherBlocky** - мешер для blocky террейну
4. **VoxelBlockyLibrary** - бібліотека моделей блоків
5. **CharacterController** - контролер персонажа
6. **AvatarInteraction** - система взаємодії (копання/розміщення)
7. **VoxelBoxMover** - система колізій

### Канали даних

- **CHANNEL_TYPE** - тип блоку (AIR=0, SAND=1, DIRT=2)

## Контролер персонажа

### Параметри

```gdscript
@export var speed := 5.0
@export var gravity := 9.8
@export var jump_force := 5.0
```

### Алгоритм руху

```gdscript
func _physics_process(delta: float):
    # Напрямки відносно камери
    var forward = _head.get_transform().basis.z.normalized()
    forward = Plane(Vector3(0, 1, 0), 0).project(forward)
    var right = _head.get_transform().basis.x.normalized()
    
    # Збір вхідних даних
    var motor = Vector3()
    if Input.is_key_pressed(KEY_W):
        motor -= forward
    # ...
    
    motor = motor.normalized() * speed
    _velocity.x = motor.x
    _velocity.z = motor.z
    _velocity.y -= gravity * delta
    
    # Колізії з террейном
    var aabb = AABB(Vector3(-0.4, -0.9, -0.4), Vector3(0.8, 1.8, 0.8))
    motion = _box_mover.get_motion(position, motion, aabb, terrain_node)
    global_translate(motion)
```

## Взаємодія з террейном

### Raycast

```gdscript
func get_pointed_voxel() -> VoxelRaycastResult:
    var origin = _head.get_global_transform().origin
    var forward = -_head.get_transform().basis.z.normalized()
    var hit = _terrain_tool.raycast(origin, forward, 10)
    return hit
```

### Копання

```gdscript
func dig(center: Vector3i):
    _terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
    _terrain_tool.value = 0  # AIR
    _terrain_tool.do_point(center)  # або do_sphere(center, 3)
```

### Розміщення

```gdscript
func place(center: Vector3i):
    var type : int = _inventory[_inventory_index]
    _terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
    _terrain_tool.value = type
    _terrain_tool.do_point(center)
```

### Перевірка колізій при розміщенні

```gdscript
func can_place_voxel_at(pos: Vector3i):
    var params = PhysicsShapeQueryParameters3D.new()
    params.collision_mask = COLLISION_LAYER_AVATAR
    var shape = BoxShape3D.new()
    shape.extents = Vector3(0.5, 0.5, 0.5)
    params.set_shape(shape)
    var hits = space_state.intersect_shape(params)
    return hits.size() == 0
```

---

# 3. Blocky Game

Повноцінна воксельна гра з мультиплеєром, системою блоків, генерацією світу, водою, рослинами, інвентарем та збереженням.

## Архітектура

### Компоненти

1. **BlockyGame** - головний менеджер гри
2. **VoxelTerrain** - воксельний террейн
3. **Blocks** - система блоків
4. **Items** - система предметів
5. **Generator** - генератор світу
6. **Water** - симуляція води
7. **RandomTicks** - випадкові події (рослини)
8. **Player** - контролер персонажа
9. **GUI** - інтерфейс
10. **UPNPHelper** - налаштування UPNP

### Режими роботи

- **SINGLEPLAYER** - одиночна гра
- **CLIENT** - клієнт у мультиплеєрі
- **HOST** - сервер у мультиплеєрі

## Мультиплеєр

### Ініціалізація сервера

```gdscript
func _ready():
    if _network_mode == NETWORK_MODE_HOST:
        var peer := ENetMultiplayerPeer.new()
        peer.create_server(_port, 32, 0, 0, 0)
        
        var synchronizer := VoxelTerrainMultiplayerSynchronizer.new()
        _terrain.add_child(synchronizer)
        
        add_child(RandomTicks.new())
        add_child(WaterUpdater.new())
        _spawn_character(SERVER_PEER_ID, Vector3(0, 64, 0))
```

### Ініціалізація клієнта

```gdscript
elif _network_mode == NETWORK_MODE_CLIENT:
    var peer := ENetMultiplayerPeer.new()
    peer.create_client(_ip, _port, 0, 0, 0, 0)
    
    var synchronizer := VoxelTerrainMultiplayerSynchronizer.new()
    _terrain.add_child(synchronizer)
    _terrain.stream = null  # Клієнт не зберігає дані
```

### VoxelViewer для персонажів

```gdscript
func _spawn_remote_character(peer_id: int, pos: Vector3):
    if _network_mode == NETWORK_MODE_HOST:
        var viewer := VoxelViewer.new()
        viewer.view_distance = 128
        viewer.requires_visuals = false
        viewer.requires_collisions = false
        viewer.set_network_peer_id(peer_id)
        viewer.set_requires_data_block_notifications(true)
        character.add_child(viewer)
```

## Система блоків

### Типи обертання

```gdscript
const ROTATION_TYPE_NONE = 0           # Без обертання
const ROTATION_TYPE_AXIAL = 1          # По осях (log: x, y, z)
const ROTATION_TYPE_Y = 2             # По Y (stairs: nx, px, nz, pz)
const ROTATION_TYPE_CUSTOM_BEHAVIOR = 3  # Кастомна поведінка
```

### Raw Mapping

```gdscript
class RawMapping:
    var block_id := 0
    var variant_index := 0
# Формат: raw_value = block_id | (variant_index << 8)
```

## Генерація світу

```gdscript
func _generate_block(buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int):
    # 1. Генерація висоти через шум
    for z in block_size:
        for x in block_size:
            var height_noise = _heightmap_noise.get_noise_2d(wx, wz)
            var height = int(HeightmapCurve.sample(height_noise))
            
            for y in block_size:
                if wy < height:
                    buffer.set_voxel(DIRT, x, y, z, _CHANNEL)
                elif wy == height:
                    buffer.set_voxel(GRASS, x, y, z, _CHANNEL)
    
    # 2. Генерація дерев
    _generate_trees(buffer, origin_in_voxels)
    
    # 3. Генерація рослин
    _generate_foliage(buffer, origin_in_voxels)
```

## Симуляція води

```gdscript
const MAX_UPDATES_PER_FRAME = 64
const INTERVAL_SECONDS = 0.2

const _spread_directions = [
    Vector3(-1, 0, 0),  # Захід
    Vector3(1, 0, 0),   # Схід
    Vector3(0, 0, -1),  # Північ
    Vector3(0, 0, 1),   # Південь
    Vector3(0, -1, 0)   # Вниз
]

func _process_cell(pos: Vector3):
    for direction in _spread_directions:
        var npos = pos + direction
        var nv = _terrain_tool.get_voxel(npos)
        if nv == Blocks.AIR_ID:
            _fill_with_water(npos)
            schedule(npos)
```

## Random Ticks

```gdscript
const RADIUS = 100
const VOXELS_PER_FRAME = 512

func _process(_unused_delta: float):
    for character in _players_container.get_children():
        var center := character.position.floor()
        var area := AABB(center - Vector3(RADIUS, RADIUS, RADIUS), 
                        2 * Vector3(RADIUS, RADIUS, RADIUS))
        _voxel_tool.run_blocky_random_tick(area, VOXELS_PER_FRAME, 
                                           _random_tick_callback, 16)
```

## Збереження

```gdscript
# VoxelStreamRegionFiles
[sub_resource type="VoxelStreamRegionFiles" id="3"]
directory = "res://blocky_game/save"

func _notification(what: int):
    match what:
        NOTIFICATION_WM_CLOSE_REQUEST:
            _terrain.save_modified_blocks()
```

---

# 4. Smooth Terrain

Гладкий воксельний террейн з SDF, Transvoxel мешингом та triplanar texturing.

## Архітектура

### Компоненти

1. **VoxelLodTerrain** з `VoxelMesherTransvoxel`
2. **VoxelGeneratorNoise2D** з `FastNoiseLite` та `Curve`
3. **SDF Stamper** для розміщення мешів
4. **Interaction System** для редагування
5. **Triplanar Shader** для текстурування

## Генерація террейну

### Генератор шуму

**VoxelGeneratorNoise2D:**
- **Noise:** `FastNoiseLite` з `frequency = 0.002`, `fractal_octaves = 6`
- **Curve:** Модифікація висоти
- **Height range:** `-100.0` до `300.0`

## Шейдер

### Triplanar Texturing

**Vertex Shader:**
```glsl
VERTEX = get_transvoxel_position(VERTEX, CUSTOM0);
v_vertex_pos_model = VERTEX;
v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
```

**Fragment Shader:**
```glsl
NORMAL = get_voxel_normal_view(v_vertex_pos_model, NORMAL, VIEW_MATRIX * MODEL_MATRIX);

// Topness (визначення верхньої грані)
float topness = smoothstep(0.46, 0.54, normal.y);

// Triplanar Blending
vec3 blending = get_triplanar_blend(normal, 8.0);

// Змішування текстур
vec3 top_col = texture_triplanar(u_texture_top, wpos, blending).rgb;
vec3 side_col = texture_triplanar(u_texture_sides, wpos, blending).rgb;
ALBEDO = mix(side_col, top_col, topness);

// LOD Fade
if (get_lod_fade_discard(SCREEN_UV)) {
    discard;
}
```

## SDF Stamper

### VoxelMeshSDF

```gdscript
# Конвертація меша в SDF
mesh_sdf.bake_async()

# Розміщення в террейн
_voxel_tool.stamp_sdf(_mesh_sdf, place_transform, 0.1, _mesh_scale * 0.1)
```

## Система взаємодії

### Два режими редагування

**MODE_SPHERES (KEY_1):**
```gdscript
func do_sphere(center: Vector3, radius: float, add: bool):
    var vt := _terrain.get_voxel_tool()
    if add:
        vt.mode = VoxelTool.MODE_ADD
    else:
        vt.mode = VoxelTool.MODE_REMOVE
    vt.do_sphere(center, radius)
```

**MODE_MESHES (KEY_2):**
- Розміщення мешів через SDF stamping
- Preview меша перед розміщенням

## Оптимізації

- **8 рівнів LOD**
- **Плавні переходи** через `lod_fade_duration`
- `threaded_update_enabled = true`
- `full_load_mode_enabled = true`

---

# 5. Smooth Materials

Малювання текстур на smooth terrain з texture arrays та blending weights.

## Архітектура

### Компоненти

1. **VoxelTerrain** - без LOD
2. **VoxelMesherTransvoxel** з `texturing_mode = 1`
3. **VoxelTool** - для малювання текстур
4. **Shader** - змішування текстур
5. **Texture2DArray** - масив текстур (до 16)

### Канали даних

- **CHANNEL_SDF** - форма террейну
- **CHANNEL_INDICES** - індекси текстур (до 4 на воксель)
- **CHANNEL_WEIGHTS** - ваги змішування (RGBA)

## Алгоритм малювання

```gdscript
_voxel_tool = _terrain.get_voxel_tool()
_voxel_tool.texture_index = 1

# Малювання
_voxel_tool.mode = VoxelTool.MODE_TEXTURE_PAINT
_voxel_tool.channel = VoxelBuffer.CHANNEL_SDF
_voxel_tool.do_sphere(_cursor.position, _brush_radius)
```

### Читання матеріалів

```gdscript
_voxel_tool.channel = VoxelBuffer.CHANNEL_INDICES
var encoded_indices := _voxel_tool.get_voxel(_cursor.position)

_voxel_tool.channel = VoxelBuffer.CHANNEL_WEIGHTS
var encoded_weights := _voxel_tool.get_voxel(_cursor.position)

var indices := VoxelTool.u16_indices_to_vec4i(encoded_indices)
var weights := VoxelTool.u16_weights_to_color(encoded_weights)
```

## Шейдер

### Vertex Shader

```glsl
VERTEX = get_transvoxel_position(VERTEX, CUSTOM0);
v_material_indices = decode_8bit_vec4(CUSTOM1.x);
v_material_weights = decode_8bit_vec4(CUSTOM1.y) / 255.0;
```

### Fragment Shader

```glsl
// Triplanar mapping
vec3 blending = get_triplanar_blend(normal, 1.0);

// Вибірка 4 текстур
vec3 col0 = texture_array_triplanar(u_albedo_array, wpos, blending, v_material_indices.x).rgb;
vec3 col1 = texture_array_triplanar(u_albedo_array, wpos, blending, v_material_indices.y).rgb;
vec3 col2 = texture_array_triplanar(u_albedo_array, wpos, blending, v_material_indices.z).rgb;
vec3 col3 = texture_array_triplanar(u_albedo_array, wpos, blending, v_material_indices.w).rgb;

// Нормалізація ваг
vec4 weights = v_material_weights;
weights /= (weights.x + weights.y + weights.z + weights.w + 0.00001);

// Змішування
vec3 col = col0 * weights.r + col1 * weights.g + col2 * weights.b + col3 * weights.a;
```

## Обмеження

1. Максимум 4 текстури на воксель
2. Максимум 16 текстур в texture array
3. 4 біти на вагу (16 рівнів)
4. 4 біти на індекс (16 можливих текстур)

---

# 6. Multipass Generator

Багатопрохідна генерація воксельного террейну для складних структур.

## Концепція

Генерація виконується в кілька проходів:
- **Pass 0** - базовий террейн (земля, камінь)
- **Pass 1** - структури, що залежать від базового террейну (дерева)
- **Pass N** - додаткові проходи

Кожен прохід має доступ до даних попередніх проходів.

## Налаштування

```gdscript
pass_count = 3
pass_1_extent = 1  # Розширення області для pass 1
pass_2_extent = 1
```

## Алгоритм генерації

### Pass 0: Базовий террейн

```gdscript
func _generate_pass(voxel_tool: VoxelToolMultipassGenerator, pass_index: int):
    if pass_index == 0:
        for gz in range(min_pos.z, max_pos.z):
            for gx in range(min_pos.x, max_pos.x):
                var height := 20.0 * _noise.get_noise_2d(gx, gz)
                voxel_tool.value = STONE
                voxel_tool.do_box(Vector3i(gx, min_pos.y, gz), Vector3i(gx, height, gz))
```

### Pass 1: Генерація дерев

```gdscript
elif pass_index == 1:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(Vector2i(min_pos.x, min_pos.z)) + SEED
    
    for tree_index in 3:
        try_plant_tree(voxel_tool, rng)
```

### Алгоритм посадки дерева

```gdscript
static func try_plant_tree(voxel_tool, rng):
    # 1. Випадкова позиція в чанку
    var tree_pos := min_pos + Vector3i(rng.randi_range(0, chunk_size.x), 0, rng.randi_range(0, chunk_size.z))
    tree_pos.y = max_pos.y - 1
    
    # 2. Пошук поверхні зверху вниз
    while tree_pos.y >= min_pos.y:
        if voxel_tool.get_voxel(tree_pos) == STONE:
            break
        tree_pos.y -= 1
    
    # 3. Генерація листя (5 сфер)
    voxel_tool.value = LEAVES
    for i in 5:
        var center := tree_pos + Vector3i(0, rng.randi_range(leaves_min_y, leaves_max_y), 0)
        voxel_tool.do_sphere(center, rng.randf_range(leaves_min_radius, leaves_max_radius))
    
    # 4. Генерація стовбура
    voxel_tool.value = LOG
    voxel_tool.do_box(tree_pos, tree_pos + Vector3i(0, trunk_height, 0))
```

## VoxelToolMultipassGenerator

### Методи

- `get_main_area_min() -> Vector3i`
- `get_main_area_max() -> Vector3i`
- `get_voxel(pos: Vector3i) -> int` - читання з попередніх проходів
- `do_box(min_pos, max_pos)`
- `do_sphere(center, radius)`
- `do_path(positions, radii)`

### Генерація спіралі

```gdscript
static func generate_spiral(voxel_tool):
    var positions := PackedVector3Array()
    var radii := PackedFloat32Array()
    
    for i in 100:
        var t := i / 100.0
        positions.append(begin_position + Vector3(
            t * length,
            radius * cos(t * twist),
            radius * sin(t * twist)
        ))
        radii.append(lerpf(2.0, 4.0, 0.5 + 0.5 * sin(t * 100.0)))
    
    voxel_tool.do_path(positions, radii)
```

## Переваги

1. Залежність від попередніх даних
2. Правильне розміщення структур
3. Складні багатокомпонентні об'єкти

---

# 7. Common Utilities

Загальні утиліти та компоненти для демо проектів.

## util.gd

### create_wirecube_mesh

Створює wireframe mesh куба.

```gdscript
static func create_wirecube_mesh(color = Color(1,1,1)) -> ArrayMesh:
    # 8 вершин, 12 ребер, PRIMITIVE_LINES
```

### calculate_normals

Обчислює нормалі для вершин меша.

```gdscript
static func calculate_normals(positions, indices) -> PackedVector3Array:
    # Для кожного трикутника:
    #   n = get_triangle_normal(...)
    #   out_normals[i0] += n
    # Нормалізація
```

### get_triangle_normal

```gdscript
static func get_triangle_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
    var u = (a - b).normalized()
    var v = (a - c).normalized()
    return v.cross(u)
```

### get_longest_axis

```gdscript
static func get_longest_axis(v: Vector3) -> int:
    # Повертає Vector3.AXIS_X, AXIS_Y або AXIS_Z
```

### get_direction_id4

Конвертує 2D напрямок в ID з 4 можливих (північ, схід, південь, захід).

```gdscript
static func get_direction_id4(dir: Vector2) -> int:
    return int(4.0 * (dir.rotated(PI / 4.0).angle() + PI) / TAU)
```

### NaN перевірки

```gdscript
static func vec3_has_nan(v: Vector3) -> bool
static func basis_has_nan(b: Basis) -> bool
static func transform_has_nan(t: Transform3D) -> bool
```

## spectator_avatar.gd

Контролер для вільного руху камери.

```gdscript
@export var speed = 10.0

func _physics_process(delta):
    var head = get_node("Camera")
    var forward = -head.transform.basis.z
    var right = head.transform.basis.x
    var up = Vector3(0, 1, 0)
    
    var dir = Vector3()
    if Input.is_key_pressed(KEY_W):
        dir += forward
    # ...
    
    if dir.length() > 0.01:
        dir /= dir.length()
        translate(dir * (speed * delta))
```

## mouse_look.gd

FPS-style контролер миші.

```gdscript
@export var sensitivity = 0.4
@export var min_angle = -90
@export var max_angle = 90

var _yaw = 0
var _pitch = 0

func _unhandled_input(event):
    if event is InputEventMouseMotion:
        _yaw -= motion.x * sensitivity
        _pitch += motion.y * sensitivity
        _pitch = clamp(_pitch, min_angle, max_angle)
        update_rotations()
```

## wireframe_builder.gd

Конвертує трикутний mesh в wireframe.

```gdscript
func build(mesh):
    for each triangle:
        _try_add_edge(i0, i1)
        _try_add_edge(i1, i2)
        _try_add_edge(i2, i0)
    return wireframe_mesh

func _try_add_edge(i0, i1):
    var e = i0 | (i1 << 16)  # Упаковка для унікальності
    if _blacklist.has(e):
        return
    _blacklist[e] = true
    _wireframe_indices.append(i0)
    _wireframe_indices.append(i1)
```

## grid.gd

Генерує 3D сітку для візуалізації.

```gdscript
@export var size = 4
@export var step = 16

func _ready():
    var st = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_LINES)
    
    for i in range(0, size+1):
        for j in range(0, size+1):
            # Вертикальні лінії (Y)
            # Лінії по Z
            # Лінії по X
    
    mesh = st.commit()
```

## Готові сцени

**spectator_avatar.tscn:**
```
SpectatorAvatar (Node3D)
├── Camera (Camera3D) - з mouse_look.gd
└── VoxelViewer - для VoxelLodTerrain
```

**axes.tscn:**
```
Axes (Node3D)
├── X (MeshInstance3D) - червоний
├── Y (MeshInstance3D) - зелений
└── Z (MeshInstance3D) - синій
```

---

# Підсумок

| Система | Тип террейну | Мешер | Особливості |
|---------|--------------|-------|-------------|
| Blocky Fluid | Blocky | VoxelMesherBlocky | Симуляція рідини, 8 рівнів |
| Blocky Terrain | Blocky | VoxelMesherBlocky | Класичний Minecraft-style |
| Blocky Game | Blocky | VoxelMesherBlocky | Мультиплеєр, збереження, інвентар |
| Smooth Terrain | Smooth (SDF) | VoxelMesherTransvoxel | LOD, triplanar, SDF stamping |
| Smooth Materials | Smooth (SDF) | VoxelMesherTransvoxel | Texture painting, blending |
| Multipass Generator | Blocky | VoxelMesherBlocky | Багатопрохідна генерація |

**Ключові класи Voxel Tools:**
- `VoxelTerrain` / `VoxelLodTerrain`
- `VoxelMesherBlocky` / `VoxelMesherTransvoxel`
- `VoxelBlockyLibrary`
- `VoxelTool` / `VoxelToolMultipassGenerator`
- `VoxelBoxMover`
- `VoxelViewer`
- `VoxelMeshSDF`
- `VoxelTerrainMultiplayerSynchronizer`
- `VoxelGeneratorNoise2D` / `VoxelGeneratorMultipassCB`
- `VoxelStreamRegionFiles`

