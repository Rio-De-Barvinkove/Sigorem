extends Control

const SETTINGS_MENU_SCENE := preload("res://scenes/ui/settings_menu.tscn")

@onready var loading_screen = $LoadingScreen
@onready var _options_button: Button = $VBoxContainer/OptionsButton

var _settings_menu: Control

func _ready():
	_options_button.pressed.connect(_on_options_button_pressed)
	_settings_menu = SETTINGS_MENU_SCENE.instantiate()
	add_child(_settings_menu)
	_settings_menu.settings_closed.connect(_on_settings_closed)

func _on_play_button_pressed():
	hide()
	if loading_screen:
		loading_screen.start_loading()
	else:
		get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_quit_button_pressed():
	get_tree().quit()

func _on_options_button_pressed():
	_settings_menu.open()

func _on_settings_closed():
	_show_menu()

func _show_menu():
	show()
