# Texture Atlas Structure

This document outlines the structure for organizing textures in the project. The target resolution for tile textures is 64x64 or 128x128 to achieve an HD-2D aesthetic.

## Directory Structure

- `assets/textures/terrain/`: For all environmental tiles (grass, dirt, stone, sand, water).
- `assets/textures/objects/`: For world objects like trees, rocks, bushes, and structures.
- `assets/textures/items/`: For inventory icons.
- `assets/textures/ui/`: For user interface elements like buttons, frames, and backgrounds.
- `assets/textures/effects/`: For particle effects and other visual effects.

## Naming Convention

`category_name_variant.png`

- `category`: `terrain`, `object`, `item`, `ui`, `fx`
- `name`: `grass`, `stone`, `wood_sword`
- `variant`: `01`, `dark`, `snowy`

Example: `terrain_grass_01.png`, `item_sword_stone.png`
