extends CanvasLayer

@onready var info_label = $InfoLabel
@onready var build_mode_label = $BuildModeLabel

func _ready():
	build_mode_label.text = ""
	info_label.text = "WASD - рух | I - інвентар | B - build mode | Q/E - поворот камери | Mouse Wheel - зум"

func _process(_delta):
	# Перевіряємо стан build mode
	var player = get_node_or_null("/root/World/Player")
	if player:
		var build_mode_node = player.get_node_or_null("BuildMode")
		if build_mode_node and build_mode_node.build_mode:
			build_mode_label.text = "BUILD MODE: ON | LMB - поставити блок | RMB - видалити блок"
		else:
			build_mode_label.text = ""
