# FILEMAP

Legend for status tags:
- `[ACTIVE]` used now
- `[LEGACY]` kept for reference, not used
- `[PLACEHOLDER]` stub/minimal implementation
- `[REFERENCE]` examples/learning only
- `[THIRDPARTY]` external addons/plugins

## Entry Points
- `[ACTIVE]` `project.godot` → main scene `scenes/main_menu.tscn` (loads `voxdot_demo/voxdot_demo.tscn` on Play/after loading screen).
- `[ACTIVE]` `voxdot_demo/voxdot_demo.tscn` – Voxdot world demo with player, UI, PerfLogger.
- `[ACTIVE]` `Voxdot-0.7.0/` – custom Godot + Voxdot module. Patched `modules/voxdot_terrain/voxdot_terrain.cpp` (`add_chunk` sets `generate_terrain` correctly).

## High-Level Structure (key dirs)
- `docs/`
- `scripts/`
  - `autoload/`
  - `game/` (`world/`, `player/`, `systems/`)
  - `ui/`
  - `tools/`
- `scenes/`
- `voxdot_demo/`
- `resources/` (`items/`, `recipes/`)
- `assets/` (voxel_library, textures)
- `backup_zylann_scripts/` `[LEGACY]`
- `voxel_game_refference.DISABLED/` `[REFERENCE]`
- `addons/` `[THIRDPARTY]`

## docs/
- `[ACTIVE]` `ROADMAP.md` – current project roadmap (Voxdot-first). Phases, priorities, and voxel-engine scope.
- `[REFERENCE]` `voxel_reference_algorithms.md` – algorithm notes/ideas (octree, LOD, RT, lighting, etc.).
- `[ACTIVE]` `FILEMAP.md` – this file.

## scripts/autoload/
- `[ACTIVE?]` `BlockRegistry.gd` – registry of block definitions/metadata for inventory/crafting/voxel lookups.
- `[ACTIVE?]` `ResourceManager.gd` – shared loader/cacher for resources (avoids duplicate loads).

## scripts/game/world/
- `[ACTIVE]` `voxdot_controller.gd` – main Voxdot terrain controller: initializes terrain node, sets voxel scale, noise parameters, biome assignment, connects player, SafeSpawn, PerfLogger; manages chunk add/mesh pipeline and view-distance updates (chunk unload currently disabled to avoid holes; ready for future unload logic). Uses TerrainDepthManager for depth sorting and Y-sort.
- `[ACTIVE]` `TerrainDepthManager.gd` – manages depth buffer settings, Y-sort for MeshInstance3D, material depth configuration, performance optimization, and transparent material preparation.
- `[ACTIVE]` `safe_spawn.gd` – creates a flat platform (configurable radius/thickness/material) at origin using `terrain.place_edit`, samples noise height, sets player spawn above platform; prevents spawning in void/inside terrain.
- `[ACTIVE]` `perf_logger.gd` – console-based chunk timing logger: tracks add/mesh operations, prints basic periodic reports to console; lightweight, minimal overhead.
- `[ACTIVE]` `PerformanceLogger.gd` – advanced performance monitoring system (UI + console): FPS/frame time, memory usage (current/peak), object count, draw calls, chunk generation times, custom metrics; includes debug overlay panel for real-time performance visualization and periodic console reports.
- `[ACTIVE]` `performance_monitor.gd` – debug UI panel for real-time performance metrics: FPS, frame time, memory usage (MB), total chunks generated, current scene objects count, average draw calls; integrates with PerformanceLogger for development monitoring.
- `[PLACEHOLDER]` `physics/voxel_physics.gd` – stub to satisfy autoload name; real voxel physics TBD.

## scripts/game/player/
- `[ACTIVE]` `voxdot_player.gd` – main player controller: movement (walk/fly/jump), first-person camera mode, visible character mesh (small green capsule), voxel pick/place/remove via Voxdot API, integrates PlayerStats/NeedsSystem/StatusEffects child nodes. Controls: WASD movement, Shift sprint, Space jump/fly up, Ctrl fly down, F toggle fly mode, mouse look.
- `[ACTIVE]` `PlayerStats.gd` – health/stamina component with class_name for typing; basic regen/damage hooks.
- `[ACTIVE]` `NeedsSystem.gd` – hunger/thirst/sleepiness decay and thresholds; emits to status effects.
- `[ACTIVE]` `StatusEffects.gd` – applies effects based on needs (e.g., debuffs when starving/thirsty/sleepy).
- `[LEGACY]` `PlayerController.gd`, `CameraController.gd` – older movement/camera stack; not used by Voxdot player.

## scripts/game/systems/
- `[ACTIVE]` `inventory_system.gd` – inventory slots/stacks, add/remove/transfer, emits signals for UI updates.
- `[ACTIVE]` `crafting_system.gd` – resolves crafting recipes, checks inputs/outputs, integrates with inventory.
- `[ACTIVE]` `game_events.gd` – global event bus (signals) for decoupled systems.
- `[ACTIVE]` `needs_system.gd` – shared needs logic (for non-player or reusable cases).
- `[ACTIVE]` `status_effects.gd` – shared effects logic.

## scripts/ui/
- components: `[ACTIVE]`
  - `inventory_slot.gd` – slot UI logic, selection, drag/drop hooks.
  - `inventory_ui.gd` – inventory panel controller, binds to InventorySystem signals.
  - `recipe_button.gd` – crafting recipe entry (uses recipe_icon/recipe_label to avoid Button name conflicts).
- menus & HUD: `[ACTIVE]`
  - `main_menu.gd` – Play loads Voxdot demo; shows loading screen when present.
  - `loading_screen_simple.gd` – simple progress -> loads Voxdot demo scene.
  - `pause_menu.gd`, `settings_menu.gd` – pause/options handling.
  - `crafting_menu.gd` – crafting UI hookup to CraftingSystem.
  - `character_menu.gd` – character stats/needs view.
  - `WorldGenerationSettings.gd` – legacy world generation settings UI (`[LEGACY]`).
  - `performance_monitor.gd` – debug performance metrics overlay controller; toggles visibility, updates real-time stats display.
- legacy: `[LEGACY]`
  - `game_hud.gd` – old HUD controller with build mode labels and debug info; not currently used.

## scripts/tools/
- `[ACTIVE]` helpers to build voxel libraries/mesh libs from texture sets: `create_voxel_library*.gd`, `create_meshlib.gd`; used offline to prep voxel_library assets.

## scenes/
- `[ACTIVE]` `main_menu.tscn` – entry point scene.
- `ui/` – UI scenes for inventory, crafting, pause, character, HUD, loading (instanced in Voxdot demo).
- `Sigorem.tscn` – base scene (not used by current flow) `[LEGACY?]`.

## voxdot_demo/
- `[ACTIVE]` `voxdot_demo.tscn` – demo world scene wiring VoxdotController, player (voxdot_player), PerfLogger node, SafeSpawn child via controller, organized CanvasLayers (TerrainLayer layer=-10, ObjectsLayer layer=-5, PlayerLayer layer=0, UILayer layer=10 with Inventory/Crafting/Pause/Character menus and PerformanceMonitor, OverlayLayer layer=20), camera rig.
- `[ACTIVE]` `performance_monitor.tscn` – debug performance monitoring UI; shows real-time FPS, memory, chunks, rendering stats; toggleable overlay for development.

## resources/
- items: `[PLACEHOLDER]` `item_resource.gd` – base item resource (id/name/icon/stack size placeholders).
- recipes: `[PLACEHOLDER]` `recipe_resource.gd` – crafting recipe resource (inputs/outputs placeholders).

## assets/
- `[ACTIVE]` `voxel_library.tres` – voxel material library consumed by Voxdot terrain.
- Textures/shaders in `assets/` (large third-party set; see subfolders).

## Voxdot-0.7.0/
- `[ACTIVE]` Full engine/module source. Local patch: `modules/voxdot_terrain/voxdot_terrain.cpp` `add_chunk` now sets `generate_terrain` flag before inserting into `chunk_map` (fixes missing terrain generation). Build outputs in `bin/`.

## backup_zylann_scripts/ `[LEGACY]`
- Stored old Zylann voxel scripts (TerrainManager, VoxelGeneratorAdapter, etc.) – not used.

## voxel_game_refference.DISABLED/ `[REFERENCE]`
- Reference blocky voxel game/sample assets (disabled, not loaded).

## addons/ `[THIRDPARTY]`
- Beehave, DialogueManager, LimboAI, panku_console, etc. (external plugins; see subfolders for details).

## Quick Visual Map (condensed)
```
project.godot
└─ scenes/
   ├─ main_menu.tscn
   └─ ui/ (...UI scenes...)
└─ voxdot_demo/voxdot_demo.tscn
   └─ performance_monitor.tscn
└─ scripts/
   ├─ autoload/
   ├─ game/
   │  ├─ world/ (voxdot_controller, TerrainDepthManager, safe_spawn, perf_logger, PerformanceLogger, physics/)
   │  ├─ player/ (voxdot_player, stats/needs/effects, legacy controllers)
   │  └─ systems/ (inventory, crafting, game_events, needs, status_effects)
   ├─ ui/ (menus, HUD, components, performance_monitor)
   └─ tools/ (voxel library builders)
└─ resources/ (items, recipes)
└─ assets/ (voxel_library.tres, textures)
└─ Voxdot-0.7.0/ (engine + Voxdot module, patched)
└─ backup_zylann_scripts/ (legacy)
└─ voxel_game_refference.DISABLED/ (reference)
└─ addons/ (third-party plugins)
```

