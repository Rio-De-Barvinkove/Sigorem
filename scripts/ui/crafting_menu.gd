extends Control

@onready var recipe_list = $Panel/ScrollContainer/VBoxContainer
# crafting_system and inventory_system are now autoload singletons

var recipe_button_scene = preload("res://scenes/ui/recipe_button.tscn") # We will create this scene next

func _ready():
	hide()
	# Connect to systems
	# crafting_system = get_node("/root/CraftingSystem")
	# inventory_system = get_node("/root/InventorySystem")
	InventorySystem.inventory_changed.connect(update_recipe_list)

func _unhandled_input(event):
	if event.is_action_pressed("crafting_menu"): # Add to Input Map
		visible = !visible
		if visible:
			update_recipe_list()

func update_recipe_list():
	for child in recipe_list.get_children():
		child.queue_free()
	
	var available_recipes = CraftingSystem.get_available_recipes(InventorySystem)
	for recipe in available_recipes:
		var button = recipe_button_scene.instantiate()
		button.set_recipe(recipe)
		button.pressed.connect(on_recipe_selected.bind(recipe))
		recipe_list.add_child(button)

func on_recipe_selected(recipe: CraftingRecipe):
	CraftingSystem.craft_item(recipe, InventorySystem)
	# update_recipe_list will be called automatically via the inventory_changed signal
