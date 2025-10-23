extends Node3D

# This node will be responsible for spawning resources like trees, rocks, etc.

@export var objects_to_spawn: Array[PackedScene]
@export var spawn_area_size = Vector2(50, 50)
@export var spawn_density = 0.1 # a value between 0 and 1

@onready var grid_map = get_node("/root/World/GridMap")

func _ready():
	spawn_objects()

func spawn_objects():
	for x in range(spawn_area_size.x):
		for z in range(spawn_area_size.y):
			if randf() < spawn_density:
				var y = grid_map.get_cell_item(Vector3i(x, 0, z)) # This is a simplification
				if y != -1: # if there is a ground block
					var object_scene = objects_to_spawn.pick_random()
					var instance = object_scene.instantiate()
					instance.position = grid_map.map_to_local(Vector3i(x, y + 1, z))
					add_child(instance)
