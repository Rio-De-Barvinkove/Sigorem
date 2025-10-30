extends Node

const CraftingRecipe = preload("res://resources/recipes/recipe_resource.gd")

var recipes: Array[CraftingRecipe] = []

func _ready():
	load_recipes()

func load_recipes():
	var dir = DirAccess.open("res://resources/recipes")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var recipe = load("res://resources/recipes/".path_join(file_name))
				if recipe is CraftingRecipe:
					recipes.append(recipe)
			file_name = dir.get_next()

func get_available_recipes(inventory_system: Node) -> Array[CraftingRecipe]:
	var available_recipes: Array[CraftingRecipe] = []
	for recipe in recipes:
		if can_craft(recipe, inventory_system):
			available_recipes.append(recipe)
	return available_recipes

func can_craft(recipe: CraftingRecipe, inventory_system: Node) -> bool:
	for i in range(recipe.ingredients.size()):
		var ingredient = recipe.ingredients[i]
		var required_count = recipe.ingredient_counts[i]
		if inventory_system.count_item(ingredient.id) < required_count:
			return false
	return true

func craft_item(recipe: CraftingRecipe, inventory_system: Node):
	if can_craft(recipe, inventory_system):
		for i in range(recipe.ingredients.size()):
			inventory_system.remove_item(recipe.ingredients[i].id, recipe.ingredient_counts[i])
		inventory_system.add_item(recipe.result_item, recipe.result_count)
		GameEvents.emit_signal("item_crafted", recipe)
		return true
	return false


