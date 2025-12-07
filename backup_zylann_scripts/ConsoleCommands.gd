extends Node
class_name ConsoleCommands

## Console Commands
## DEPRECATED: Zylann VoxelTools commands disabled
## For Voxdot, use VoxdotController API directly

var player: Node3D
var voxdot_terrain: Node  # VoxdotTerrain
var voxdot_controller: Node  # VoxdotController

func _ready():
	await get_tree().process_frame
	
	# Find Voxdot nodes
	var demo = get_tree().get_root().get_node_or_null("VoxdotDemo")
	if demo:
		player = demo.get_node_or_null("Player")
		voxdot_terrain = demo.get_node_or_null("VoxdotTerrain")
		voxdot_controller = demo.get_node_or_null("VoxdotController")
	
	# Fallback: find in any scene
	if not player:
		player = _find_node_by_type("Player")
	if not voxdot_terrain:
		voxdot_terrain = _find_node_by_class("VoxdotTerrain")
	
	_register_panku_commands()

func _find_node_by_type(node_name: String) -> Node:
	return get_tree().get_root().find_child(node_name, true, false)

func _find_node_by_class(class_name_str: String) -> Node:
	var nodes = get_tree().get_nodes_in_group("all")
	for node in get_tree().get_root().get_children():
		if node.get_class() == class_name_str:
			return node
		var found = _find_child_by_class(node, class_name_str)
		if found:
			return found
	return null

func _find_child_by_class(parent: Node, class_name_str: String) -> Node:
	for child in parent.get_children():
		if child.get_class() == class_name_str:
			return child
		var found = _find_child_by_class(child, class_name_str)
		if found:
			return found
	return null

func _register_panku_commands():
	if not Engine.has_singleton("Panku"):
		return
	
	var panku = Engine.get_singleton("Panku")
	if panku and panku.has_method("register_command"):
		panku.register_command("tp", teleport, "Teleport player to coordinates")
		panku.register_command("help", help, "Show available commands")
		panku.register_command("sphere", place_sphere, "Place/remove sphere")

func teleport(x: float, y: float, z: float) -> String:
	if not player:
		return "Error: Player not found"
	player.global_position = Vector3(x, y, z)
	return "Teleported to (%d, %d, %d)" % [x, y, z]

func teleport_to_surface(x: float = 0, z: float = 0) -> String:
	if not player:
		return "Error: Player not found"
	
	# Raycast down to find surface
	var from = Vector3(x, 200, z)
	var to = Vector3(x, -100, z)
	var space = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space.intersect_ray(query)
	
	if result:
		player.global_position = result.position + Vector3(0, 2, 0)
		return "Teleported to surface at (%d, %d, %d)" % [result.position.x, result.position.y + 2, result.position.z]
	else:
		player.global_position = Vector3(x, 50, z)
		return "No surface found, teleported to (%d, 50, %d)" % [x, z]

func place_sphere(x: float, y: float, z: float, radius: float = 1.0, material: int = 0) -> String:
	if not voxdot_controller:
		return "Error: VoxdotController not found"
	
	if voxdot_controller.has_method("place_sphere"):
		voxdot_controller.place_sphere(Vector3(x, y, z), radius, material)
		return "Placed sphere at (%d, %d, %d) r=%0.1f mat=%d" % [x, y, z, radius, material]
	
	return "Error: place_sphere method not found"

func help() -> String:
	return """Available commands:
  tp x y z - Teleport to coordinates
  teleport_to_surface x z - Teleport to terrain surface
  sphere x y z radius material - Place/remove sphere (material=0 removes)
  help - Show this help"""
