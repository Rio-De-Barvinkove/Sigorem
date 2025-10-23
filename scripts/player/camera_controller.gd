extends Camera3D

@export var target: Node3D
@export var offset = Vector3(10, 15, 10)
@export var smooth_speed = 5.0

func _physics_process(delta):
	if target:
		var target_position = target.global_transform.origin + offset
		global_transform.origin = global_transform.origin.lerp(target_position, delta * smooth_speed)
		look_at(target.global_transform.origin, Vector3.UP)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			offset.y -= 1
			offset.x -= 0.5
			offset.z -= 0.5
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			offset.y += 1
			offset.x += 0.5
			offset.z += 0.5
