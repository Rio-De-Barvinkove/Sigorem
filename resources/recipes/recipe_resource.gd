@tool
class_name CraftingRecipe extends Resource

const ItemResource = preload("res://resources/items/item_resource.gd")

@export var result_item: ItemResource
@export var result_count: int = 1
@export var ingredients: Array[ItemResource]
@export var ingredient_counts: Array[int]
@export var crafting_time: float = 1.0
