extends Resource
class_name CraftingRecipe

@export var ingredients: Array[ItemResource] = []
@export var ingredient_counts: Array[int] = []
@export var result_item: ItemResource
@export var result_count: int = 1

