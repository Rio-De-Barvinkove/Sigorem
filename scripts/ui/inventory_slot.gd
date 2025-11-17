extends Panel
class_name InventorySlot

var slot_index: int = -1
var inventory_ui

func _ready():
	mouse_filter = MOUSE_FILTER_PASS

func _get_drag_data(_at_position):
	if not inventory_ui:
		return null
	if slot_index < 0:
		return null
	if not inventory_ui.can_start_drag(slot_index):
		return null
	var preview = inventory_ui.create_drag_preview(slot_index)
	if preview:
		set_drag_preview(preview)
	return {"slot_index": slot_index}

func _can_drop_data(_at_position, data) -> bool:
	if not inventory_ui:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("slot_index"):
		return false
	var from_index: int = data["slot_index"]
	return from_index != slot_index and slot_index >= 0

func _drop_data(_at_position, data):
	if not inventory_ui:
		return
	if typeof(data) != TYPE_DICTIONARY:
		return
	if not data.has("slot_index"):
		return
	var from_index: int = data["slot_index"]
	inventory_ui.handle_slot_drop(from_index, slot_index)




