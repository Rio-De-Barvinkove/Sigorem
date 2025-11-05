extends CanvasLayer

@onready var info_label = $InfoLabel
@onready var build_mode_label = $BuildModeLabel
@onready var world_gen_settings = get_node_or_null("../UI/WorldGenerationSettings")

func _ready():
	build_mode_label.text = ""
	info_label.text = "WASD - рух | I - інвентар | B - build mode | Q/E - поворот камери | Mouse Wheel - зум | F10 - налаштування генерації"

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		toggle_world_gen_settings()

func toggle_world_gen_settings():
	"""Перемикання меню налаштувань генерації світу"""
	if world_gen_settings:
		if world_gen_settings.visible:
			world_gen_settings.hide_settings()
		else:
			world_gen_settings.show_settings()
	else:
		push_warning("GameHUD: WorldGenerationSettings не знайдено!")

func _process(_delta):
	# Перевіряємо стан build mode
	var player = get_node_or_null("/root/World/Player")
	if player:
		var build_mode_node = player.get_node_or_null("BuildMode")
		if build_mode_node and build_mode_node.build_mode:
			build_mode_label.text = "BUILD MODE: ON | LMB - поставити блок | RMB - видалити блок"
		else:
			build_mode_label.text = ""
