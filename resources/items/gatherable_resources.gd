@tool
class_name GatherableResource extends Resource

@export var resource_name: String
@export var item_drop: ItemResource
@export var drop_quantity: int = 1
@export var required_tool_type: String # e.g., "axe", "pickaxe"
@export var gathering_time: float = 2.0
