extends Control

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	$VBoxContainer/ContinueButton.pressed.connect(on_continue_pressed)
	$VBoxContainer/QuitButton.pressed.connect(on_quit_pressed)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if visible:
			on_continue_pressed()
		else:
			get_tree().paused = true
			show()

func on_continue_pressed():
	get_tree().paused = false
	hide()

func on_quit_pressed():
	get_tree().quit()
