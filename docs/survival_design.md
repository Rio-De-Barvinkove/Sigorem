# Survival Design Document

This document outlines the core survival elements and crafting recipes for the game.

## Gatherable Resources

- **Wood**: Obtained from trees. Requires a tool (e.g., axe) for efficiency. Used for basic tools and structures.
- **Stone**: Obtained from rock nodes on the ground. Requires a tool (e.g., pickaxe). Used for tools and building.
- **Flint**: Chance to drop when mining stone nodes. Used for early game tools.
- **Plant Fibers**: Obtained from bushes. Used for bindings and simple cloth.
- **Berries**: Obtained from bushes. Can be eaten to restore a small amount of hunger.

## Interaction System

- Player approaches a resource node.
- An interaction prompt (e.g., 'E' to gather) appears.
- Player holds the interaction key. A timer/progress bar appears.
- Upon completion, the resource is added to the player's inventory.
- Tool usage will be checked. Using the correct tool speeds up gathering. Using no tool or the wrong tool is slow or impossible.

## Basic Crafting Recipes

Crafting will be recipe-based. The player discovers recipes over time.

| Result Item        | Ingredients                          | Crafting Station |
|--------------------|--------------------------------------|------------------|
| **Stone Axe**      | 2x Stone, 1x Wood, 2x Plant Fibers   | Hand             |
| **Stone Pickaxe**  | 3x Stone, 1x Wood, 2x Plant Fibers   | Hand             |
| **Campfire**       | 5x Wood, 3x Stone                    | Hand             |
| **Simple Bandage** | 3x Plant Fibers                      | Hand             |

## Future expansions
- Add a workbench for more complex crafting recipes.
- Add more resources like ores (copper, iron), leather, etc.
- Add more complex recipes for better tools, armor, and building parts.
