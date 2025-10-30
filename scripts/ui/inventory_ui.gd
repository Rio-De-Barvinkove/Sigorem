extends Control

@onready var grid_container = $Panel/GridContainer
# inventory_system is now an autoload singleton

func _ready():
	hide() # Спочатку приховано
	InventorySystem.inventory_changed.connect(update_ui)
	
	# Create placeholder slots
	for i in range(InventorySystem.MAX_SLOTS):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(40, 40)
		grid_container.add_child(slot)
	
	update_ui() # Initial update

func _unhandled_input(event):
	if event.is_action_pressed("toggle_inventory"):
		visible = !visible

func update_ui():
	var slots = InventorySystem.slots
	for i in range(grid_container.get_child_count()):
		var slot_ui = grid_container.get_child(i)
		var item_slot = slots[i]
		
		# Clear previous item visuals
		for child in slot_ui.get_children():
			child.queue_free()
			
		if item_slot.item:
			var icon = TextureRect.new()
			icon.texture = item_slot.item.icon
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot_ui.add_child(icon)
			
			var label = Label.new()
			label.text = str(item_slot.quantity)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			slot_ui.add_child(label)
