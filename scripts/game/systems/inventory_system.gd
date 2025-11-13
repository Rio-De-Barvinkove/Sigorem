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
	_inventory_manager.slot_modified.connect(_on_slot_modified)
	_inventory_manager.inventory_cleared.connect(_on_inventory_cleared)
	_inventory_manager.item_added.connect(_on_item_added)
	_inventory_manager.item_removed.connect(_on_item_removed)

	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = ItemSlot.new()

	_register_available_items()
	_sync_slots()
	inventory_changed.emit()

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
	return not is_instance_valid(excess)

func remove_item(item_id: String, quantity: int) -> bool:
	if quantity <= 0:
		return true
	if not _string_to_numeric.has(item_id):
		return false
	var numeric_id: int = _string_to_numeric[item_id]

	var excess = _inventory_manager.remove(numeric_id, quantity)
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

func _register_available_items():
	var dir := DirAccess.open("res://resources/items")
	if dir == null:
		return
	var item_paths: PackedStringArray = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			item_paths.push_back("res://resources/items".path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	item_paths.sort()
	for resource_path in item_paths:
		var resource := load(resource_path)
		if resource is ItemResource:
			_ensure_item_registered(resource)

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

func _on_slot_modified(slot_index: int):
	if slot_index < 0 or slot_index >= slots.size():
		return
	_update_slot(slot_index)
	inventory_changed.emit()

func _on_item_added(slot_index: int, _item_id: int):
	_on_slot_modified(slot_index)

func _on_item_removed(slot_index: int, _item_id: int):
	_on_slot_modified(slot_index)

func _on_inventory_cleared():
	for slot in slots:
		slot.item = null
		slot.quantity = 0
	inventory_changed.emit()

func _update_slot(slot_index: int):
	var slot := slots[slot_index]
	if not _inventory_manager.is_slot_valid(slot_index) or _inventory_manager.is_slot_empty(slot_index):
		slot.item = null
		slot.quantity = 0
		return
	var numeric_id := _inventory_manager.get_slot_item_id(slot_index)
	var resource: ItemResource = _numeric_to_resource.get(numeric_id, null) as ItemResource
	if resource == null:
		slot.item = null
		slot.quantity = 0
		return
	slot.item = resource
	slot.quantity = _inventory_manager.get_slot_item_amount(slot_index)

func swap_slots(first_index: int, second_index: int):
	_inventory_manager.swap(first_index, second_index)

func transfer(from_index: int, to_index: int, amount: int):
	if amount <= 0:
		return
	_inventory_manager.transfer(from_index, amount, to_index)

func add_item_to_slot(item: ItemResource, amount: int, slot_index: int) -> bool:
	var numeric_id := _ensure_item_registered(item)
	if numeric_id == INVALID_ITEM_ID or amount <= 0:
		return false
	var remaining := _inventory_manager.add_items_to_slot(slot_index, numeric_id, amount)
	return remaining == 0

func remove_item_from_slot(slot_index: int, amount: int) -> int:
	if amount <= 0:
		return 0
	if not _inventory_manager.is_slot_valid(slot_index) or _inventory_manager.is_slot_empty(slot_index):
		return 0
	var numeric_id := _inventory_manager.get_slot_item_id(slot_index)
	var remaining := _inventory_manager.remove_items_from_slot(slot_index, numeric_id, amount)
	return amount - remaining
