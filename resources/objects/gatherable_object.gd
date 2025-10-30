extends StaticBody3D

const GatherableResource = preload("res://resources/objects/gatherable_resource.gd")

@export var resource_data: GatherableResource

func _ready():
	if not resource_data:
		push_error("Gatherable object has no resource data assigned!")
		queue_free()
		return

	# Setup visuals based on resource_data if needed
	var mesh_instance = $MeshInstance3D
	if mesh_instance and resource_data.item_yield and resource_data.item_yield.icon:
		var material = StandardMaterial3D.new()
		material.albedo_texture = resource_data.item_yield.icon
		mesh_instance.set_surface_override_material(0, material)


func interact(player):
	print("Player interacted with ", resource_data.item_yield.item_name)
	# Here you would start a timer for gathering_time
	# After the timer, add item_yield to player's inventory
	InventorySystem.add_item(resource_data.item_yield, resource_data.yield_amount)
	
	# For now, just destroy the object
	queue_free()
