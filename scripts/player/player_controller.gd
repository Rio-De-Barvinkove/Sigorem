extends CharacterBody3D

@export var speed = 5.0

func _physics_process(delta):
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	move_and_slide()
