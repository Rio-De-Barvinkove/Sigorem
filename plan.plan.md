# План стабілізації генерації, UI, папок і ассетів

### 1) Аудит документів (що залишити/оновити/архівувати)

- **docs/terrain_generation_usage.md**: залишити. Оновити розділ з параметрами (seed, frequency, noise type) та додати приклади пресетів. Додати розділ «типові логи при успішній генерації».
- **docs/terrain_generation_implementation_plan.md**: частково неактуальний (надлишкові розділи «вже реалізовано»; критичні пропуски не покриті). Залишити, але переписати під фактичну архітектуру і стан.
- **docs/terrain_assets_analysis.md**: залишити. Додати висновок: беремо підхід GridMap+власна система; WFC — лише для структур.
- **docs/survival_design.md**: залишити без змін (roadmap для майбутнього).
- **assets/textures/atlas_structure.md**: неактуальна структура. Оновити до реальної іменної схеми й дереву каталогів, або перенести в `docs/art_pipeline.md`.
- **README.md, GAME_CONTROLS.md, BUILD_MODE_FIX.md**: залишити. Додати згадку про F10 меню та нові параметри генерації.

### 2) Чому дві папки `scripts/game/world` і `scripts/world` і чи безпечно зносити

- Історичний поділ: нова генерація в `scripts/game/world/generation/*`; старі утиліти/спавнери — у `scripts/world/*`.
- У `scenes/world.tscn` використовується обидва підходи одночасно: GridMap з новим `WorldGenerator.gd` і вузол `WorldObjects` зі старим `scripts/world/world_objects.gd`.
- Конфліктів по виконанню мало (старий спавнер не модифікує GridMap), але це плутає і заважає підтримці.
- Рішення без ризиків: перемістити `scripts/world/*` у `scripts/legacy/world/*`, прибрати вузол `WorldObjects` із сцени (або перепідключити на новий модуль рослинності пізніше). Осиротілі `*.uid` на кшталт `scripts/world/voxel_physics.gd.uid` прибрати.

### 3) Чому «меню не працює» і «світ не міняється» — кореневі причини

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

### 4) Конкретні правки для відновлення керованої генерації

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

### 5) «Як у майнкрафті» — створення/збереження світів (не пріоритет, але одразу закладемо каркас)

- Екран «Створити світ»: name, seed/randomize, preset.
- Структура на диску: `user://worlds/<world_id>/world.json` (name, seed, created_at, last_played) + `chunks/` (per-chunk data).
- `SaveLoadManager.gd`: збереження чанків (вже існує файл, але треба ув’язати з новими параметрами).
- Екран «Список світів»: Continue/Delete/Rename.

### 6) Повний технічний ревʼю і розукрупнення «бого-файлів» (низький пріоритет)

- Розділити `TerrainGenerator.gd` на: Init/Modules wiring, Runtime control, Editor/tools API.
- Винести константи/типи у `scripts/game/world/types.gd`.
- Прибрати дублювання констант (50×50), централізувати у `ChunkSettings`.
- Впровадити простий `Logger` з категоріями.

### 7) Текстури: стратегія і конкретний список «малюємо зараз»

- Стратегія: робимо свій базовий пак (tileable albedo), 256×256 або 512×512. Для блоків потрібні: top і side варіанти (grass/log), решта — одна текстура. Стиль — простий, читабельний з дистанції.
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
- Найменування: `category_name_variant.png` (наприклад, `terrain_grass_top.png`). Дерево: `assets/textures/terrain`, `assets/textures/objects`, `assets/textures/items`.

### 8) Тест-кейси приймання після правок

- Зміна `chunk_size` у UI → інша кількість блоків по осі (видимо в кадрі).
- Встановлення `seed` A і B → різні патерни рельєфу; повторне встановлення A → той самий рельєф.
- Рух гравця → підвантаження/вивантаження чанків (видно в логах і HUD).
- Без BlockRegistry → генерація працює через fallback; із BlockRegistry → використовує реєстр.

### To-dos

- [ ] Оновити/архівувати md: usage, implementation_plan, atlas_structure, README refs
- [ ] Перенести scripts/world/* у scripts/legacy/world і прибрати вузол WorldObjects у сцені
- [ ] Додати fallback get_mesh_index_for_block у ProceduralGeneration і замінити виклики
- [ ] Прибрати 50×50 в ProceduralGeneration/ChunkManager; використовувати chunk_size
- [ ] Додати Seed/Randomize/Frequency/NoiseType/Octaves у WorldGenerationSettings
- [ ] Встановити terrain_generator.player у WorldGenerator._setup_terrain_generator
- [ ] Додати логи та HUD-debug рядок про seed/chunks
- [ ] Вимкнути/прибрати WorldObjects з scenes/world.tscn, видалити сироти *.uid
- [ ] Скелет Create/Load World, user://worlds/<id>/world.json
- [ ] Зв’язати SaveLoadManager з новими параметрами (seed, chunks)
- [ ] План рефакторингу генератора і налаштувань у модулі
- [ ] Намалювати базовий пак текстур згідно списку (terrain, ore, flora, items)
- [ ] Скрипт тестування: змінити параметри і перевірити ефекти в логах/екрані


