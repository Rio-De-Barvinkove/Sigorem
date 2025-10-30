extends Node3D

# This node will be responsible for spawning resources like trees, rocks, etc.

@export var objects_to_spawn: Array[PackedScene]
@export var spawn_area_size = Vector2(50, 50)
@export var spawn_density = 0.1 # a value between 0 and 1

@onready var grid_map = get_parent().get_node("GridMap")

func _ready():
	spawn_objects()

func spawn_objects():
	if not grid_map or objects_to_spawn.is_empty():
		return
	
	for x in range(spawn_area_size.x):
		for z in range(spawn_area_size.y):
			if randf() < spawn_density:
				# Знаходимо найвищу точку терейну
				var highest_y = -1
				for y in range(20, -1, -1): # Перевіряємо зверху вниз
					if grid_map.get_cell_item(Vector3i(x, y, z)) != -1:
						highest_y = y
						break
				
				if highest_y != -1:
					var object_scene = objects_to_spawn.pick_random()
					if object_scene:
						var instance = object_scene.instantiate()
						instance.position = grid_map.map_to_local(Vector3i(x, highest_y + 1, z))
						add_child(instance)
