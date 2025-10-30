extends Control

@onready var loading_screen = $LoadingScreen
# Використовуємо спрощений LoadingScreen

func _on_play_button_pressed():
	# Приховуємо меню
	hide()
	
	# Запускаємо нову систему завантаження
	if loading_screen:
		loading_screen.start_loading()
	else:
		# Якщо loading screen немає, просто переходимо
		get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_quit_button_pressed():
	get_tree().quit()
