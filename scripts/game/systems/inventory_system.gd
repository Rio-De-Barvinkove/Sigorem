extends Node

const ItemResource = preload("res://resources/items/item_resource.gd")
const InventoryManagerScript = preload("res://addons/rubonnek.inventory_manager/runtime/inventory_manager.gd")
const ItemRegistryScript = preload("res://addons/rubonnek.inventory_manager/runtime/item_registry.gd")

signal inventory_changed

const MAX_SLOTS := 48
const INVALID_ITEM_ID := -1

class ItemSlot:
	var item: ItemResource = null
	var quantity: int = 0

var slots: Array[ItemSlot] = []

var _item_registry: ItemRegistry
var _inventory_manager: InventoryManager

var _string_to_numeric: Dictionary = {}
var _numeric_to_resource: Dictionary = {}
var _next_numeric_id: int = 0

func _ready():
	_item_registry = ItemRegistryScript.new()
	_inventory_manager = InventoryManagerScript.new(_item_registry)
	_inventory_manager.resize(MAX_SLOTS)
	_inventory_manager.reserve(MAX_SLOTS)

	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = ItemSlot.new()

func add_item(item: ItemResource, quantity: int) -> bool:
	if item == null:
		push_warning("InventorySystem: attempted to add a null item.")
		return false
	if quantity <= 0:
		return true

	var numeric_id: int = _ensure_item_registered(item)
	if numeric_id == INVALID_ITEM_ID:
		return false
	var excess = _inventory_manager.add(numeric_id, quantity)
	_sync_slots()
	inventory_changed.emit()
	return not is_instance_valid(excess)

func remove_item(item_id: String, quantity: int) -> bool:
	if quantity <= 0:
		return true
	if not _string_to_numeric.has(item_id):
		return false
	var numeric_id: int = _string_to_numeric[item_id]

	var excess = _inventory_manager.remove(numeric_id, quantity)
	_sync_slots()
	inventory_changed.emit()
	if is_instance_valid(excess):
		return excess.get_amount() == 0
	return true

func count_item(item_id: String) -> int:
	if not _string_to_numeric.has(item_id):
		return 0
	var numeric_id: int = _string_to_numeric[item_id]
	return _inventory_manager.get_item_total(numeric_id)

func clear():
	_inventory_manager.clear()
	_sync_slots()
	inventory_changed.emit()

func get_item_at_slot(slot_index: int) -> ItemSlot:
	if slot_index < 0 or slot_index >= slots.size():
		return null
	return slots[slot_index]

func _ensure_item_registered(item: ItemResource) -> int:
	if item.id.is_empty():
		push_error("InventorySystem: item %s is missing an ID." % item)
		return INVALID_ITEM_ID

	if _string_to_numeric.has(item.id):
		var existing_id: int = _string_to_numeric[item.id]
		_update_registry_entry(existing_id, item)
		return existing_id

	var numeric_id: int = _next_numeric_id
	_next_numeric_id += 1

	_string_to_numeric[item.id] = numeric_id
	_numeric_to_resource[numeric_id] = item
	_item_registry.add_item(
		numeric_id,
		item.item_name,
		item.description,
		item.icon,
		max(item.max_stack, 1)
	)
	return numeric_id

func _update_registry_entry(numeric_id: int, item: ItemResource):
	_item_registry.set_name(numeric_id, item.item_name)
	_item_registry.set_description(numeric_id, item.description)
	if is_instance_valid(item.icon):
		_item_registry.set_icon(numeric_id, item.icon)
	_item_registry.set_stack_capacity(numeric_id, max(item.max_stack, 1))

func _sync_slots():
	for i in range(MAX_SLOTS):
		var slot: ItemSlot = slots[i]
		if not _inventory_manager.is_slot_valid(i) or _inventory_manager.is_slot_empty(i):
			slot.item = null
			slot.quantity = 0
			continue

		var numeric_id := _inventory_manager.get_slot_item_id(i)
		if not _numeric_to_resource.has(numeric_id):
			slot.item = null
			slot.quantity = 0
			continue

		var resource: ItemResource = _numeric_to_resource[numeric_id]
		slot.item = resource
		slot.quantity = _inventory_manager.get_slot_item_amount(i)
