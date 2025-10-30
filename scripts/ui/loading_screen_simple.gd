extends CanvasLayer

@onready var progress_bar = $VBoxContainer/ProgressBar
@onready var status_label = $VBoxContainer/Label

var current_step = 0
var total_steps = 3

func _ready():
	print("LoadingScreen initialized")

func start_loading():
	print("Starting loading...")
	show()
	progress_bar.value = 0
	current_step = 0
	
	status_label.text = "Loading blocks..."
	_update_progress()
	
	await get_tree().create_timer(0.5).timeout
	status_label.text = "Loading textures..."
	_update_progress()
	
	await get_tree().create_timer(0.5).timeout
	status_label.text = "Initializing world..."
	_update_progress()
	
	await get_tree().create_timer(0.5).timeout
	_on_loading_complete()

func _update_progress():
	current_step += 1
	var progress = float(current_step) / float(total_steps)
	progress_bar.value = progress * 100

func _on_loading_complete():
	hide()
	get_tree().change_scene_to_file("res://scenes/world.tscn")
