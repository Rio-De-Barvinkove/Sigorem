extends Control

@onready var health_bar = $Panel/HBoxContainer/StatsContainer/HealthBar
@onready var stamina_bar = $Panel/HBoxContainer/StatsContainer/StaminaBar
@onready var hunger_bar = $Panel/HBoxContainer/StatsContainer/HungerBar

var player_stats: Node
var needs_system: Node

func _ready():
	hide()
	# These should be connected to the actual player nodes
	# player_stats = get_node("/root/World/Player/PlayerStats")
	# needs_system = get_node("/root/World/Player/NeedsSystem")
	# player_stats.stat_changed.connect(on_stat_changed)
	# needs_system.needs_changed.connect(on_needs_changed)
	
func _unhandled_input(event):
	if event.is_action_pressed("character_menu"): # Assuming you have an input map for this
		visible = !visible

func on_stat_changed(stat_name, value, max_value):
	match stat_name:
		"health":
			health_bar.max_value = max_value
			health_bar.value = value
		"stamina":
			stamina_bar.max_value = max_value
			stamina_bar.value = value

func on_needs_changed(need_name, value, max_value):
	match need_name:
		"hunger":
			hunger_bar.max_value = max_value
			hunger_bar.value = value
