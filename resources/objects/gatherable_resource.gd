@tool
class_name GatherableResource extends Resource

const ItemResource = preload("res://resources/items/item_resource.gd")

@export var item_yield: ItemResource
@export var yield_amount: int = 1
@export var gathering_time: float = 2.0
@export var required_tool_type: String = "any" # e.g., "axe", "pickaxe"
