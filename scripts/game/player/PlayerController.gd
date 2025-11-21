extends CharacterBody3D

@export var speed = 5.0
@export var acceleration = 12.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var jump_velocity := 6.0
@export var max_fall_speed := 40.0

# World generation freeze
@export var freeze_during_world_generation := true
@export var world_generation_freeze_frames := 300  # 5 секунд при 60 FPS

var world_generation_frame_count := 0

# Debug/Test режими
@export_group("Debug/Test Tools")
@export var flight_mode := false
@export var flight_speed := 10.0
@export var speed_multiplier := 1.0  # Множник швидкості (для тестування)
@export var min_speed_multiplier := 0.1
@export var max_speed_multiplier := 10.0

func _ready():
	_ensure_movement_actions()
	_setup_voxel_viewer()

	if freeze_during_world_generation:
		print("PlayerController: Freezing player during world generation")
		# Вимикаємо гравітацію і рух
		gravity = 0.0
		velocity = Vector3.ZERO

func _setup_voxel_viewer():
	# VoxelViewer вже є в сцені як дочірній вузол Player
	# Не створюємо дубль, щоб уникнути конфліктів
	pass

func _on_voxel_terrain_block_loaded(pos):
	# Check if this block is below player
	var player_chunk = Vector3i(global_position) / 32 # Assuming 32 chunk size
	if pos == player_chunk:
		# Safe to enable gravity/physics fully or move player to surface
		pass

func _physics_process(delta: float):
	# Перевіряємо чи потрібно розморозити гравця
	if freeze_during_world_generation and world_generation_frame_count < world_generation_freeze_frames:
		world_generation_frame_count += 1
		# Тримаємо гравця на місці
		velocity = Vector3.ZERO
		return

	# Якщо тільки що розморозили - відновлюємо гравітацію
	if freeze_during_world_generation and world_generation_frame_count == world_generation_freeze_frames:
		print("PlayerController: Unfreezing player - world generation complete")
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		freeze_during_world_generation = false

	if flight_mode:
		_handle_flight_movement(delta)
	else:
		_handle_normal_movement(delta)

func _handle_normal_movement(delta: float):
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

	var current_speed = speed * speed_multiplier
	var target_velocity := Vector3.ZERO
	if direction != Vector3.ZERO:
		target_velocity = direction * current_speed
	else:
		target_velocity = Vector3.ZERO

	velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)

	move_and_slide()

func _handle_flight_movement(delta: float):
	# Польотний режим - вільний рух у всіх напрямках
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	)

	if input_vec.length_squared() > 1.0:
		input_vec = input_vec.normalized()

	var camera := get_viewport().get_camera_3d()
	var direction := Vector3.ZERO
	
	if camera:
		var basis := camera.global_transform.basis
		var forward := -basis.z
		var right := basis.x
		var up := basis.y
		
		direction = (forward * input_vec.y) + (right * input_vec.x)
		
		# Вертикальний рух у польотному режимі
		if Input.is_action_pressed("jump"):
			direction += up
		if Input.is_key_pressed(Key.KEY_SHIFT):
			direction -= up
	
	var current_speed = flight_speed * speed_multiplier
	velocity = direction.normalized() * current_speed if direction.length_squared() > 0 else Vector3.ZERO
	
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
	if event.is_action_pressed("jump") and is_on_floor() and not flight_mode:
		velocity.y = jump_velocity
	
	# Перемикання польотного режиму (F для flight)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == Key.KEY_F:
			flight_mode = not flight_mode
			if flight_mode:
				print("PlayerController: Польотний режим увімкнено")
			else:
				print("PlayerController: Польотний режим вимкнено")
				velocity.y = 0  # Скидаємо вертикальну швидкість
		
		# Зміна швидкості (PageUp/PageDown)
		if event.keycode == Key.KEY_PAGEUP:
			speed_multiplier = min(speed_multiplier + 0.5, max_speed_multiplier)
			print("PlayerController: Швидкість: ", speed_multiplier, "x")
		if event.keycode == Key.KEY_PAGEDOWN:
			speed_multiplier = max(speed_multiplier - 0.5, min_speed_multiplier)
			print("PlayerController: Швидкість: ", speed_multiplier, "x")
