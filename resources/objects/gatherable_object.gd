extends StaticBody3D

class_name GatherableObject

@export var resource: GatherableResource
var health = 100.0

func _ready():
	# Connect to an interaction system, perhaps via an Area3D
	pass

func take_damage(amount: float, tool_type: String):
	if resource.required_tool_type == tool_type:
		health -= amount * 2 # Double damage with correct tool
	else:
		health -= amount
	
	if health <= 0:
		harvest()

func harvest():
	# Use GameEvents to notify that an item was spawned/dropped
	var item = resource.item_drop
	var count = resource.drop_quantity
	# For now, we'll just emit a signal. A proper implementation would spawn the item in the world.
	GameEvents.emit_signal("item_picked_up", item, count)
	queue_free()
