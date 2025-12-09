extends Button

@onready var recipe_icon = $HBoxContainer/Icon
@onready var recipe_label = $HBoxContainer/Label

var recipe: CraftingRecipe

func set_recipe(new_recipe: CraftingRecipe):
	recipe = new_recipe
	recipe_icon.texture = recipe.result_item.icon
	recipe_label.text = "%s (%d)" % [recipe.result_item.item_name, recipe.result_count]
