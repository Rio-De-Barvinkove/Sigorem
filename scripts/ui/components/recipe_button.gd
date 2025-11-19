extends Button

@onready var icon = $HBoxContainer/Icon
@onready var label = $HBoxContainer/Label

var recipe: CraftingRecipe

func set_recipe(new_recipe: CraftingRecipe):
	recipe = new_recipe
	icon.texture = recipe.result_item.icon
	label.text = "%s (%d)" % [recipe.result_item.item_name, recipe.result_count]
