extends Control

func _ready():
	$VBoxContainer/NewGameButton.pressed.connect(on_new_game_pressed)
	$VBoxContainer/QuitButton.pressed.connect(on_quit_pressed)

func on_new_game_pressed():
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func on_quit_pressed():
	get_tree().quit()
