extends Node

signal inventory_changed

const MAX_SLOTS = 48
var slots: Array = []

class ItemSlot:
	var item: ItemResource
	var quantity: int
	
	func can_add(amount: int) -> bool:
		if !item:
			return true
		return quantity + amount <= item.max_stack
		
	func get_space() -> int:
		if !item:
			return 64 # a bit of a magic number, should be based on item type
		return item.max_stack - quantity

func _ready():
	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = ItemSlot.new()

func add_item(item: ItemResource, quantity: int):
	# First, try to stack with existing items
	for slot in slots:
		if quantity == 0: break
		if slot.item and slot.item.id == item.id and slot.can_add(1):
			var can_add = min(quantity, slot.get_space())
			slot.quantity += can_add
			quantity -= can_add
			
	# Then, find an empty slot
	for slot in slots:
		if quantity == 0: break
		if !slot.item:
			var can_add = min(quantity, item.max_stack)
			slot.item = item
			slot.quantity = can_add
			quantity -= can_add
			
	emit_signal("inventory_changed")
	
	if quantity > 0:
		print("Inventory full, couldn't add %d of %s" % [quantity, item.item_name])
		return false # Couldn't add all items
	
	return true

func remove_item(item_id: String, quantity: int):
	for slot in slots:
		if quantity == 0: break
		if slot.item and slot.item.id == item_id:
			var can_remove = min(quantity, slot.quantity)
			slot.quantity -= can_remove
			quantity -= can_remove
			if slot.quantity == 0:
				slot.item = null
	
	emit_signal("inventory_changed")
