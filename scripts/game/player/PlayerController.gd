extends CharacterBody3D

@export var speed = 5.0
@export var acceleration = 12.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var jump_velocity := 6.0
@export var max_fall_speed := 40.0

func _ready():
	_ensure_movement_actions()

func _physics_process(delta: float):

	if not is_on_floor():
		velocity.y -= gravity * delta
		velocity.y = max(velocity.y, -max_fall_speed)
	else:
		velocity.y = max(velocity.y, -1.0)

	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)

	if input_vec.length_squared() > 1.0:
		input_vec = input_vec.normalized()

	var direction := _get_direction_relative_to_camera(input_vec)

	var target_velocity := Vector3.ZERO
	if direction != Vector3.ZERO:
		target_velocity = direction * speed
	else:
		target_velocity = Vector3.ZERO

	velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)

	move_and_slide()

func _ensure_movement_actions():
	var map := {
		"move_left": [Key.KEY_A, Key.KEY_LEFT],
		"move_right": [Key.KEY_D, Key.KEY_RIGHT],
		"move_forward": [Key.KEY_W, Key.KEY_UP],
		"move_back": [Key.KEY_S, Key.KEY_DOWN],
	}

	for action in map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)

		if InputMap.action_get_events(action).is_empty():
			for key_code in map[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key_code
				InputMap.action_add_event(action, event)

	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
	if InputMap.action_get_events("jump").is_empty():
		var jump_event := InputEventKey.new()
		jump_event.physical_keycode = Key.KEY_SPACE
		InputMap.action_add_event("jump", jump_event)

func _get_direction_relative_to_camera(input_vec: Vector2) -> Vector3:
	if input_vec == Vector2.ZERO:
		return Vector3.ZERO

	var camera := get_viewport().get_camera_3d()
	if camera:
		var basis := camera.global_transform.basis
		var forward := -basis.z
		forward.y = 0
		forward = forward.normalized()

		var right := basis.x
		right.y = 0
		right = right.normalized()

		var direction := (forward * input_vec.y) + (right * input_vec.x)
		if direction.length_squared() > 0:
			return direction.normalized()

	return Vector3(input_vec.x, 0, input_vec.y).normalized()

func _unhandled_input(event):
	if event.is_action_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
