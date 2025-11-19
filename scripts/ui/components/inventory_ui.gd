extends Control

const InventorySlot = preload("res://scripts/ui/components/inventory_slot.gd")

@onready var grid_container = $Panel/GridContainer

func _ready():
	hide()
	InventorySystem.inventory_changed.connect(update_ui)
	_create_slots()
	update_ui()

func _unhandled_input(event):
	if event.is_action_pressed("toggle_inventory"):
		visible = !visible

func update_ui():
	var slots = InventorySystem.slots
	for i in range(grid_container.get_child_count()):
		var slot_ui = grid_container.get_child(i)
		slot_ui.set_tooltip_text("")
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
			
			var tooltip_text: String = item_slot.item.item_name
			if item_slot.item.description.strip_edges() != "":
				tooltip_text += "\n" + item_slot.item.description
			slot_ui.set_tooltip_text(tooltip_text)

func _create_slots():
	for child in grid_container.get_children():
		child.queue_free()
	for i in range(InventorySystem.MAX_SLOTS):
		var slot: InventorySlot = InventorySlot.new()
		slot.slot_index = i
		slot.inventory_ui = self
		slot.custom_minimum_size = Vector2(48, 48)
		grid_container.add_child(slot)

func can_start_drag(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= InventorySystem.slots.size():
		return false
	var slot = InventorySystem.slots[slot_index]
	return slot.item != null and slot.quantity > 0

func create_drag_preview(slot_index: int) -> Control:
	var slot = InventorySystem.slots[slot_index]
	if slot.item == null:
		return null
	var preview := Panel.new()
	preview.custom_minimum_size = Vector2(48, 48)
	var icon := TextureRect.new()
	icon.texture = slot.item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(icon)
	var label := Label.new()
	label.text = str(slot.quantity)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	preview.add_child(label)
	return preview

func handle_slot_drop(from_index: int, to_index: int):
	if from_index == to_index:
		return
	if from_index < 0 or to_index < 0:
		return
	InventorySystem.swap_slots(from_index, to_index)
