extends Control

const SETTINGS_MENU_SCENE := preload("res://scenes/ui/settings_menu.tscn")

var _settings_menu: Control

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	$VBoxContainer/ContinueButton.pressed.connect(_on_continue_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)

	_settings_menu = SETTINGS_MENU_SCENE.instantiate()
	add_child(_settings_menu)
	_settings_menu.settings_closed.connect(_on_settings_closed)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if _settings_menu.visible:
			_settings_menu.close()
			_show_buttons()
			return
		if visible:
			_on_continue_pressed()
		else:
			get_tree().paused = true
			show()
			_show_buttons()

func _on_continue_pressed():
	get_tree().paused = false
	hide()

func _on_quit_pressed():
	get_tree().quit()

func _on_settings_pressed():
	_settings_menu.open()
	_hide_buttons()

func _on_settings_closed():
	_show_buttons()

func _hide_buttons():
	$VBoxContainer.hide()

func _show_buttons():
	$VBoxContainer.show()
