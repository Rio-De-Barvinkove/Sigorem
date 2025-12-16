extends CharacterBody3D
class_name VoxdotPlayer
## Voxdot player: рух + воксельне редагування + базові потреби/стати

@export var speed: float = 8.0
@export var sprint_speed: float = 16.0
@export var jump_force: float = 8.0
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.003
@export var fly_mode: bool = true

@export_node_path("VoxdotController") var voxdot_controller_path: NodePath

var voxdot_controller: VoxdotController

@onready var camera: Camera3D = $Camera3D
@onready var character_mesh: MeshInstance3D = $CharacterMesh
@onready var interaction_handler: VoxelInteractionHandler = $VoxelInteractionHandler

# Простий first-person режим
var _yaw: float = 0.0
var _pitch: float = 0.0
@onready var stats: PlayerStats = $PlayerStats
@onready var needs: Node = $NeedsSystem


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if voxdot_controller_path:
		voxdot_controller = get_node_or_null(voxdot_controller_path)
	if needs and needs.has_signal("needs_changed"):
		needs.needs_changed.connect(_on_needs_changed)

	# Налаштування камери
	camera.position = Vector3(0, 1.2, 0)  # Очі на висоті 1.2м (для меншого персонажа)




func _unhandled_input(event: InputEvent) -> void:
	# Обертання камери
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, -PI / 2.0, PI / 2.0)
		
		rotation.y = _yaw
		camera.rotation.x = _pitch
	
	# Escape - вийти/увійти в захоплення миші
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		
		# F - перемкнути режим польоту
		elif event.keycode == KEY_F:
			fly_mode = not fly_mode
			print("Fly mode: ", fly_mode)
	
	# Передати подію в interaction handler
	if interaction_handler:
		interaction_handler.handle_input(event)

	# Клік миші - редагування вокселів
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		
		if interaction_handler:
			interaction_handler.handle_mouse_button(event.button_index)


func _physics_process(delta: float) -> void:
	var input_dir = Vector3.ZERO
	
	# Отримати напрямки руху
	if Input.is_key_pressed(KEY_W):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += transform.basis.x
	
	var current_speed = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else speed
	
	if fly_mode:
		# Режим польоту
		if Input.is_key_pressed(KEY_SPACE):
			input_dir.y += 1.0
		if Input.is_key_pressed(KEY_CTRL):
			input_dir.y -= 1.0
		
		input_dir = input_dir.normalized()
		velocity = input_dir * current_speed
	else:
		# Звичайний режим з гравітацією
		input_dir.y = 0.0
		input_dir = input_dir.normalized()
		
		velocity.x = input_dir.x * current_speed
		velocity.z = input_dir.z * current_speed
		
		if is_on_floor():
			if Input.is_key_pressed(KEY_SPACE):
				velocity.y = jump_force
		else:
			velocity.y -= gravity * delta
	
	move_and_slide()
	_apply_status_effects(delta)



func _on_needs_changed(_need_name, _value, _max_value):
	# Реагуємо при змінах потреб
	_apply_status_effects(0.0)


func _apply_status_effects(delta: float) -> void:
	if not stats or not needs:
		return
	
	# Базові значення
	stats.stamina_regen_modifier = 1.0
	
	# Штраф за голод/спрагу
	if needs.hunger < 20 or needs.thirst < 20:
		stats.take_damage(0.5 * delta if delta > 0 else 0.1)
	elif needs.hunger < 50 or needs.thirst < 50:
		stats.take_damage(0.1 * delta if delta > 0 else 0.02)
	
	# Втома
	if needs.sleepiness < 20:
		stats.stamina_regen_modifier = 0.5
	elif needs.sleepiness < 50:
		stats.stamina_regen_modifier = 0.8
