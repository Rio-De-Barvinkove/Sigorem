extends Camera3D

@export var target: Node3D
@export var offset = Vector3(10, 15, 10)
@export var smooth_speed = 5.0

@export_group("2.5D Settings")
@export var diorama_angle = 45.0
@export var enable_tilt_shift = true
@export var min_zoom = 5.0
@export var max_zoom = 30.0
@export var zoom_speed = 1.0
@export var rotation_enabled = true
@export var rotation_speed = 2.0

var current_rotation = 0.0

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
	
	var target_position = target.global_position + offset.rotated(Vector3.UP, current_rotation)
	global_position = global_position.lerp(target_position, delta * smooth_speed)
	var look_target = target.global_position
	look_at(look_target, Vector3.UP)
	rotation_degrees.x = -diorama_angle

func _unhandled_input(event):
	if event is InputEventMouseButton:
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
	
	if rotation_enabled:
		if event.is_action_pressed("camera_rotate_left"):
			current_rotation += PI / 4
		elif event.is_action_pressed("camera_rotate_right"):
			current_rotation -= PI / 4


