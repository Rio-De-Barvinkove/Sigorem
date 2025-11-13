extends Camera3D

@export var target: Node3D
@export var offset = Vector3(10, 15, 10)
@export var smooth_speed = 5.0

@export_group("2.5D Settings")
@export var diorama_angle = 45.0
@export var enable_tilt_shift = true
@export var min_zoom = 2.0  # Ближче до гравця
@export var max_zoom = 100.0  # Значно далі для огляду
@export var zoom_speed = 2.0  # Швидший зум
@export var rotation_enabled = true
@export var rotation_speed = 2.0

@export_group("First Person View")
@export var enable_first_person = false
@export var first_person_offset = Vector3(0, 1.6, 0)  # Висота очей гравця
@export var first_person_mouse_sensitivity = 0.003

var current_rotation = 0.0
var first_person_rotation = Vector2.ZERO  # Pitch and Yaw for FPS
var is_first_person_active = false

func _ready():
	# 2.5D look
	fov = 45
	near = 0.1
	far = 100.0
	rotation_degrees.x = -diorama_angle
	
	# Якщо target не встановлений, шукаємо Player автоматично
	if not target:
		target = get_node_or_null("../Player")
		if target:
			print("CameraController: Found Player automatically")
		else:
			print("CameraController: Warning - Player not found!")

func _physics_process(delta):
	if not target:
		# Спробуємо знайти Player ще раз
		target = get_node_or_null("../Player")
		if not target:
			return
	
	if is_first_person_active:
		# First Person View - камера на рівні очей гравця
		global_position = target.global_position + first_person_offset
		rotation.x = first_person_rotation.x
		rotation.y = first_person_rotation.y
	else:
		# Третьоособовий вид (2.5D)
		var target_position = target.global_position + offset.rotated(Vector3.UP, current_rotation)
		global_position = global_position.lerp(target_position, delta * smooth_speed)
		var look_target = target.global_position
		look_at(look_target, Vector3.UP)
		rotation_degrees.x = -diorama_angle

func _unhandled_input(event):
	# Перемикання First Person View (клавіша V)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == Key.KEY_V:
			is_first_person_active = not is_first_person_active
			if is_first_person_active:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				print("CameraController: First Person View увімкнено")
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				first_person_rotation = Vector2.ZERO
				print("CameraController: Third Person View увімкнено")
	
	# Рух миші для First Person View
	if is_first_person_active and event is InputEventMouseMotion:
		first_person_rotation.y -= event.relative.x * first_person_mouse_sensitivity
		first_person_rotation.x -= event.relative.y * first_person_mouse_sensitivity
		# Обмеження pitch (щоб не крутити голову на 360°)
		first_person_rotation.x = clamp(first_person_rotation.x, -PI/2, PI/2)
	
	# Зум тільки в третьоособовому режимі
	if not is_first_person_active and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var zoom_factor = zoom_speed
			offset.y = max(min_zoom, offset.y - zoom_factor)
			offset.x = max(min_zoom * 0.7, offset.x - zoom_factor * 0.7)
			offset.z = max(min_zoom * 0.7, offset.z - zoom_factor * 0.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var zoom_factor = zoom_speed
			offset.y = min(max_zoom, offset.y + zoom_factor)
			offset.x = min(max_zoom * 0.7, offset.x + zoom_factor * 0.7)
			offset.z = min(max_zoom * 0.7, offset.z + zoom_factor * 0.7)
	
	if not is_first_person_active and rotation_enabled:
		if event.is_action_pressed("camera_rotate_left"):
			current_rotation += PI / 4
		elif event.is_action_pressed("camera_rotate_right"):
			current_rotation -= PI / 4


