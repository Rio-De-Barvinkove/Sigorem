# План стабілізації генерації, UI, папок і ассетів

### 1) Аудит документів (що залишити/оновити/архівувати)

- **docs/terrain_generation_usage.md**: залишити. Оновити розділ з параметрами (seed, frequency, noise type) та додати приклади пресетів. Додати розділ «типові логи при успішній генерації».
- **docs/terrain_generation_implementation_plan.md**: частково неактуальний (надлишкові розділи «вже реалізовано»; критичні пропуски не покриті). Залишити, але переписати під фактичну архітектуру і стан.
- **docs/terrain_assets_analysis.md**: залишити. Додати висновок: беремо підхід GridMap+власна система; WFC — лише для структур.
- **docs/survival_design.md**: залишити без змін (roadmap для майбутнього).
- **assets/textures/atlas_structure.md**: неактуальна структура. Оновити до реальної іменної схеми й дереву каталогів, або перенести в `docs/art_pipeline.md`.
- **README.md, GAME_CONTROLS.md, BUILD_MODE_FIX.md**: залишити. Додати згадку про F10 меню та нові параметри генерації.

### 2) Цільовий вигляд: мікровоксельний терейн + 2.5D HD-2D

- **Геометрія:** орієнтир — Lay of the Land. Логічний шар залишається воксельним (для деструкції, чанків), але видимий терейн будуємо як «мікровоксельний» меш: приховуємо внутрішні грані, робимо скоси, плавні схили, підтримуємо дрібні деталі (брівки, сходи, мости). `GridMap.set_cell_item` використовуємо тільки як тимчасовий fallback; головна мета — перейти на генерацію `ArrayMesh` / `MeshInstance3D` з власного пайплайну (`MeshOptimizer`, `Mesher`).
- **Масштаб блоку:** ціль — 0.25–0.5 м «логічного» кроку, але рендерінг об’єднує їх у більші сегменти (greedy meshing + bevel). Це дасть «мільйони мікровокселів» візуально, не перевантажуючи GPU.
- **Статика та пропси:** пропрацьовуємо бібліотеку ручних моделей (мости, будівлі, дерева) у стилі Lay of the Land, які вставлятимуться процедурно.
- **Камера/стиль:** орієнтир — Octopath Traveler (HD-2D). Камера ізометрична 3/4, глибина різкості, легка «плівкова» розмитість, bloom і піксельні текстури. Рендерінг має виглядати як 2D, хоча це 3D-сцена.
- **Проміжні кроки:** спочатку добудовуємо генерацію мешів і текстурний пайплайн, на другому етапі підключаємо постобробку (DOF, bloom, vignette) і pixel-snapping.
- **Контрольні точки:** (1) переробити `ProceduralGeneration`/`ChunkManager` на генерацію мешів; (2) створити тестову ділянку (міст і берег) для валідації стилю; (3) після затвердження підключати художні ефекти.

### 3) Чому дві папки `scripts/game/world` і `scripts/world` і чи безпечно зносити

- Історичний поділ: нова генерація в `scripts/game/world/generation/*`; старі утиліти/спавнери — у `scripts/world/*`.
- У `scenes/world.tscn` використовується обидва підходи одночасно: GridMap з новим `WorldGenerator.gd` і вузол `WorldObjects` зі старим `scripts/world/world_objects.gd`.
- Конфліктів по виконанню мало (старий спавнер не модифікує GridMap), але це плутає і заважає підтримці.
- Рішення без ризиків: перемістити `scripts/world/*` у `scripts/legacy/world/*`, прибрати вузол `WorldObjects` із сцени (або перепідключити на новий модуль рослинності пізніше). Осиротілі `*.uid` на кшталт `scripts/world/voxel_physics.gd.uid` прибрати.

### 4) Чому «меню не працює» і «світ не міняється» — кореневі причини

- Відсутній BlockRegistry (або не використовується): генератор блокує встановлення ID за назвами блоків.

```gdscript
# ProceduralGeneration.gd
var mesh_index = BlockRegistry.get_mesh_index(block_id)
if mesh_index >= 0:
    gridmap.set_cell_item(Vector3i(x, y, z), mesh_index)
```

- Жорстко прошитий розмір чанка 50×50: UI змінює `chunk_size`, але генератор ігнорує й продовжує 50×50.

```gdscript
# ProceduralGeneration.gd
var chunk_start = chunk_pos * Vector2i(50, 50)
var chunk_size = Vector2i(50, 50)
```

- Chunking не знає про гравця: `TerrainGenerator` має `player`, але він не задається з `WorldGenerator`, тому апдейт чанків по руху може не працювати.

```gdscript
# TerrainGenerator.gd
if use_chunking:
    chunk_module = ChunkManager.new()
    if player:
        chunk_module.player = player
```

- Немає seed/frequency у UI + мізерні логи: неможливо перевірити детермінізм і факт застосування налаштувань.

### 5) Конкретні правки для відновлення керованої генерації

- Fallback без BlockRegistry:
  - Додати функцію `get_mesh_index_for_block(gridmap, block_name)` із пріоритетом: BlockRegistry → пошук у `gridmap.mesh_library` за ім’ям → мапа {grass:0,dirt:1,stone:2} як останній резерв.
  - Замінити прямі виклики `BlockRegistry.get_mesh_index` на цей fallback у `ProceduralGeneration.gd`.
- Підтримка `chunk_size` з UI:
  - У `ProceduralGeneration.generate_chunk()` використати `get_parent().chunk_module.chunk_size` (або `terrain_generator.chunk_size`) замість 50×50.
  - У `ChunkManager.collect_chunk_data/remove_chunk` теж не дублювати 50×50.
- Seed і Noise у UI:
  - У `scenes/ui/world_generation_settings.tscn` додати поля: `Seed` (SpinBox), `Randomize Seed` (Button), `Frequency` (0.001–0.2), `Noise Type`, `Fractal Type`, `Octaves`.
  - У `WorldGenerationSettings.gd` зчитувати/встановлювати `terrain_generator.noise.seed` і пов’язані параметри `FastNoiseLite`.
- Зв’язати гравця з генератором:
  - У `WorldGenerator._setup_terrain_generator()` після створення генератора встановити `terrain_generator.player = get_node("/root/World/Player")`.
- Логування й on-screen debug:
  - Додати `print` у `apply_settings/initialize_modules/generate_initial_terrain` із ключовими параметрами (seed, chunk_size, chunk_radius).
  - У HUD виводити короткий debug рядок (seed, chunks active).
- Прибрати старий вузол із сцени:
  - Тимчасово вимкнути `WorldObjects` у `scenes/world.tscn` (або перевести в `legacy`).

### 6) «Як у майнкрафті» — створення/збереження світів (не пріоритет, але одразу закладемо каркас)

- Екран «Створити світ»: name, seed/randomize, preset.
- Структура на диску: `user://worlds/<world_id>/world.json` (name, seed, created_at, last_played) + `chunks/` (per-chunk data).
- `SaveLoadManager.gd`: збереження чанків (вже існує файл, але треба ув’язати з новими параметрами).
- Екран «Список світів»: Continue/Delete/Rename.

### 7) Повний технічний ревʼю і розукрупнення «бого-файлів» (низький пріоритет)

- Розділити `TerrainGenerator.gd` на: Init/Modules wiring, Runtime control, Editor/tools API.
- Винести константи/типи у `scripts/game/world/types.gd`.
- Прибрати дублювання констант (50×50), централізувати у `ChunkSettings`.
- Впровадити простий `Logger` з категоріями.

### 8) Текстури: HD-2D набір для 2.5D сцени

- Стратегія: base color без PBR, роздільність 128×128 (максимум 256×256 для великих плиток). Орієнтир — Octopath Traveler: плиткові текстури з «намальованими» шумами, дерев'яні балки, мокрі камені. Обов’язково пара варіантів «top»/«side» для блоків, щоб mesher міг комбінувати.
- Базові блоки (tileable):
  - terrain_grass_top, terrain_grass_side
  - terrain_dirt
  - terrain_stone
  - terrain_sand
  - terrain_gravel
  - terrain_snow
  - terrain_ice (напівпрозорий варіант теж)
  - terrain_clay
  - terrain_bedrock
  - wood_log_top, wood_log_side (хвоя/листяний — 2 варіанти)
  - wood_planks_oak, wood_planks_spruce
  - cobblestone, brick
  - glass (з маскою прозорості)
  - water_albedo (та 4-кадровий sheet для легкої анімації — опціонально)
- Руди (overlay на stone, по 1 текстурі-узору):
  - ore_coal, ore_iron, ore_copper, ore_tin, ore_gold
- Рослинність (alpha-cutout для `Sprite3D`/дві площини):
  - grass_clump_01..04
  - flower_red, flower_yellow, flower_blue
  - bush_small_01..02
  - cactus_01..02
  - leaves_cluster_01..02
- Натуральні об’єкти (малі пропси, lowpoly-albedo):
  - rock_small_01..03, stump_01, fallen_log_01
- Іконки для інвентаря (64×64):
  - item_wood, item_stone, item_flint, item_fiber, item_berry
  - tool_stone_axe, tool_stone_pickaxe, item_campfire, item_bandage
- Найменування: `category_name_variant.png` (наприклад, `terrain_grass_top.png`). Каталоги: `assets/textures/terrain`, `assets/textures/objects`, `assets/textures/items`.
- Додатково: підготувати палітру/lighting chart, щоб вся графіка відповідала одному «теплому сонячному» сетапу (як на референсі Lay of the Land). Для дрібних деталей (мікровокселі) — «painterly» переходи всередині плитки, а не деталізація за рахунок високої роздільності.

### 9) Виправлення управління (WASD замість стрілочок)

**Поточна проблема:**
- `PlayerController.gd` використовує `Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")` — це стрілочки за замовчуванням.
- Камера обертається на Q/E (keycode 81/82), що може не відповідати очікуванням.

**Рішення:**
- Створити нові input actions у `project.godot`: `move_left` (A), `move_right` (D), `move_forward` (W), `move_back` (S).
- Замінити в `PlayerController.gd`:
  ```gdscript
  # Було:
  var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
  
  # Стане:
  var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
  ```
- Перевірити/оновити камери: за потреби додати альтернативні кнопки (наприклад, миша + Shift для обертання).
- Оновити `GAME_CONTROLS.md` з правильними клавішами.

### 10) Критичні баги з terrain_generation_implementation_plan.md (треба виправити)

#### 10.1 Mesh Optimization - Не відображати внутрішні грані
**Чому критично:** Кожен блок має всі 6 граней, навіть внутрішні.  
**Вплив:** 50-80% зайвих вершин/трикутників.  
**Рішення:** Реалізувати greedy mesh generation або cull hidden faces.  
**Файли:** Створити `scripts/game/world/generation/MeshOptimizer.gd` або розширити `OptimizationManager.gd`.

#### 10.2 Frustum Culling - Не рендерити невидимі чанки
**Чому критично:** Віддалені чанки рендеряться дарма.  
**Вплив:** GPU bottleneck на великих світах.  
**Рішення:** Camera frustum перевірка перед рендерингом.  
**Файли:** Додати в `ChunkManager.gd` метод `is_chunk_visible(camera: Camera3D, chunk_pos: Vector2i) -> bool`.

#### 10.3 Chunk Boundary Fix - Узгоджені границі чанків
**Чому критично:** Стики між чанками можуть розриватися.  
**Вплив:** Візуальні артефакти, провали в місцевості.  
**Рішення:** Врахування сусідніх чанків при генерації (читати дані сусідів перед встановленням блоків на границях).  
**Файли:** Оновити `ProceduralGeneration.generate_chunk()` та `ChunkManager.generate_chunk()`.

#### 10.4 Partial Mesh Updates - Оновлення тільки змінених частин
**Чому критично:** При зміні одного блоку перебудовується весь чанк.  
**Вплив:** Лаги при building/breaking блоків.  
**Рішення:** Інкрементальні оновлення mesh (відстежувати змінені блоки, перебудовувати лише їх області).  
**Файли:** Додати в `ChunkManager` систему відстеження змін блоків + метод `update_chunk_partial()`.

#### 10.5 Biome Transitions - Плавні переходи між біомами
**Чому критично:** Різкі зміни біомів виглядають нереалістично.  
**Вплив:** Погана імерсія, візуальні артефакти.  
**Рішення:** Interpolation між біомами на стиках (використати weight maps або distance-based blending).  
**Файли:** Розширити `PrecomputedPatterns.gd` або створити `BiomeBlender.gd`.

### 11) Важливі імпруви з terrain_generation_implementation_plan.md

#### 11.1 Mesh/Rendering Optimization
- **Occlusion culling** — не рендерити повністю закриті чанки (додати в `OptimizationManager`).
- **Indexed buffers** — уникнути дублювання вершин (Godot GridMap має це, але перевірити налаштування).
- **GPU data minimization** — мінімізувати vertex attributes (перевірити налаштування матеріалів).
- **Lighting optimization** — динамічне освітлення тільки для активних чанків (LightBaking для статичних частин).

#### 11.2 Generation Quality
- **Large-scale structures** — гори, каньйони як окремий шар (додати в `ProceduralGeneration` або створити `LargeStructureGenerator.gd`).
- **Cave generation** — 3D шум для підземель (додати в `ProceduralGeneration` опцію `use_caves`).
- **Biome blending** — smooth transitions (див. 10.5).
- **Erosion simulation** — природніший рельєф (створити `ErosionSimulator.gd` як post-process).

#### 11.3 Performance
- **Physics optimization** — фізика тільки для активних чанків (оновлювати `VoxelPhysics.gd` для роботи з chunk system).
- **Memory pooling** — reuse objects замість new/delete (створити `ObjectPool.gd` для часто створюваних об'єктів).
- **Preloading buffer** — завантаження чанків наперед (розширити `ChunkManager` методом `preload_chunks_around_player()`).
- **Spatial partitioning** — quadtree для швидкого пошуку (створити `Quadtree.gd` для оптимізації пошуку чанків).

#### 11.4 Gameplay Integration
- **Starting area** — безпечна зона для нового гравця (додати в `ProceduralGeneration` опцію `generate_starting_area()`).
- **Points of Interest** — цікаві локації (міста, печери) (створити `POIGenerator.gd`).
- **Navigation support** — pathfinding через воксельний світ (інтеграція з Godot NavigationServer3D або власна система).

### 12) Ревʼю структури проекту (scripts/)

**Виявлені проблеми:**
- `scripts/core/` — тільки `.uid` файли без основних скриптів (`block_registry_simple.gd.uid`, `resource_manager_simple.gd.uid`, `texture_atlas_manager_simple.gd.uid`). Або знайти основні файли, або видалити `.uid`.
- `scripts/world/` і `scripts/game/world/` — дубль. Перемістити `scripts/world/*` у `scripts/legacy/world/`.
- `scripts/player/` — порожня папка. Видалити або заповнити, якщо планується щось окреме від `scripts/game/player/`.
- `scripts/inventory/` — тільки `inventory_system.gd`. Можливо об'єднати з `scripts/game/systems/` або залишити як окремий модуль.
- `scripts/systems/` — тільки `game_events.gd`. Можливо об'єднати з `scripts/game/systems/` (там уже є `crafting_system.gd`, `needs_system.gd`, `status_effects.gd`).
- `scripts/autoload/` — правильно структурований (BlockRegistry, ResourceManager).
- `scripts/ui/` — правильно структурований.

**Рекомендована структура:**
```
scripts/
├── autoload/          # Autoload скрипти (залишити як є)
├── core/              # Видалити або заповнити основними файлами
├── game/
│   ├── player/        # Контролери гравця (залишити)
│   ├── systems/       # Ігрові системи (crafting, needs, status_effects)
│   └── world/         # Генерація світу (залишити)
├── inventory/         # Залишити як окремий модуль або перенести в game/systems/
├── legacy/            # НОВА папка для старого коду
│   └── world/         # Перенести scripts/world/* сюди
├── systems/           # Об'єднати з game/systems/ або видалити
└── ui/                # UI скрипти (залишити як є)
```

**Дії:**
1. Видалити порожню `scripts/player/` або заповнити.
2. Перевірити `scripts/core/*.uid` — якщо немає основних файлів, видалити `.uid`.
3. Перенести `scripts/world/*` → `scripts/legacy/world/`.
4. Об'єднати `scripts/systems/game_events.gd` з `scripts/game/systems/` або залишити як окремий autoload (якщо використовується як autoload).
5. Видалити дублікати `.uid` файлів без основних скриптів.

### 13) Тест-кейси приймання після правок

- Зміна `chunk_size` у UI → інша кількість блоків по осі (видимо в кадрі).
- Встановлення `seed` A і B → різні патерни рельєфу; повторне встановлення A → той самий рельєф.
- Рух гравця → підвантаження/вивантаження чанків (видно в логах і HUD).
- Без BlockRegistry → генерація працює через fallback; із BlockRegistry → використовує реєстр.
- WASD управління → рух гравця працює на W/A/S/D замість стрілочок.
- Mesh optimization → менше вершин/трикутників у профілі (профілювальник Godot).
- Frustum culling → чанки поза камерою не рендеряться (профілювальник).
- Chunk boundaries → немає провалів на стиках чанків (візуальна перевірка).

### To-dos

#### Генерація світу — пріоритет №1 (мікровокселі + керування параметрами)
- [ ] Побудувати новий mesh-пайплайн: генерувати чанки у ArrayMesh/MeshInstance3D, залишити GridMap лише як debug.
- [ ] Реалізувати greedy meshing з bevel/скосами під «мікровоксельний» стиль Lay of the Land.
- [ ] Зібрати тестову сцену (міст + берег + схили) для перевірки стилю до/після.
- [ ] Додати fallback get_mesh_index_for_block у ProceduralGeneration і замінити виклики.
- [ ] Прибрати 50×50 в ProceduralGeneration/ChunkManager; використовувати chunk_size.
- [ ] Додати Seed/Randomize/Frequency/NoiseType/Octaves у WorldGenerationSettings.
- [ ] Встановити terrain_generator.player у WorldGenerator._setup_terrain_generator.
- [ ] Додати логи та HUD-debug рядок про seed/chunks.
- [ ] Вимкнути/прибрати WorldObjects з scenes/world.tscn, видалити сироти *.uid.

#### Генерація — оптимізація та якість
- [ ] Mesh Optimization: реалізувати greedy mesh generation або cull hidden faces (оновити під новий пайплайн).
- [ ] Frustum Culling: додати перевірку видимості чанків у ChunkManager.
- [ ] Chunk Boundary Fix: врахування сусідніх чанків при генерації.
- [ ] Partial Mesh Updates: інкрементальні оновлення mesh при зміні блоків.
- [ ] Biome Transitions: interpolation між біомами на стиках.
- [ ] Occlusion culling для повністю закритих чанків.
- [ ] Large-scale structures (гори, каньйони).
- [ ] Cave generation (3D шум для підземель).
- [ ] Erosion simulation (природніший рельєф).
- [ ] Physics optimization (фізика тільки для активних чанків).
- [ ] Memory pooling (reuse objects).
- [ ] Preloading buffer (завантаження чанків наперед).
- [ ] Spatial partitioning (quadtree для швидкого пошуку).
- [ ] Starting area (безпечна зона для нового гравця).
- [ ] Points of Interest (цікаві локації).
- [ ] Navigation support (pathfinding).

#### Управління і UI
- [ ] Створити input actions: move_left (A), move_right (D), move_forward (W), move_back (S).
- [ ] Замінити Input.get_vector в PlayerController.gd на нові actions.
- [ ] Перевірити/оновити камеру (Q/E обертання або альтернативні кнопки).
- [ ] Оновити GAME_CONTROLS.md з правильними клавішами (WASD).

#### Структура проекту
- [ ] Перенести scripts/world/* у scripts/legacy/world і прибрати вузол WorldObjects у сцені.
- [ ] Видалити порожню scripts/player/ або заповнити.
- [ ] Перевірити scripts/core/*.uid — якщо немає основних файлів, видалити .uid.
- [ ] Об'єднати scripts/systems/game_events.gd з scripts/game/systems/ або залишити як autoload.
- [ ] Видалити дублікати .uid файлів без основних скриптів.

#### Документація
- [ ] Оновити/архівувати md: usage, implementation_plan, atlas_structure, README refs.

#### Система світів (після стабілізації генерації)
- [ ] Скелет Create/Load World, user://worlds/<id>/world.json.
- [ ] Зв'язати SaveLoadManager з новими параметрами (seed, chunks).

#### Рефакторинг (коли генерація стабільна)
- [ ] Розділити TerrainGenerator.gd на модулі.
- [ ] Винести константи/типи у scripts/game/world/types.gd.
- [ ] Впровадити простий Logger з категоріями.

#### Ассети та візуал (HD-2D)
- [ ] Намалювати базовий пак текстур згідно списку (terrain, ore, flora, items).
- [ ] Підібрати постобробку/профіль освітлення для 2.5D (DOF, bloom, vignette, pixel snap) — реалізувати, коли з’явиться перший art-pass.

#### Тестування
- [ ] Скрипт тестування: змінити параметри і перевірити ефекти в логах/екрані.
- [ ] Performance test: FPS з різною кількістю чанків.
- [ ] Memory test: витрата пам'яті при русі.
- [ ] Generation quality: візуальна перевірка без артефактів.
- [ ] Chunk loading: плавність завантаження/вивантаження.
- [ ] Building/breaking: лагів при модифікації блоків.


