extends Node

signal stat_changed(stat_name, value, max_value)
signal health_depleted

var health = 100.0:
	set(value):
		health = clamp(value, 0, max_health)
		emit_signal("stat_changed", "health", health, max_health)
		if health == 0:
			emit_signal("health_depleted")
var max_health = 100.0

var stamina = 100.0:
	set(value):
		stamina = clamp(value, 0, max_stamina)
		emit_signal("stat_changed", "stamina", stamina, max_stamina)
var max_stamina = 100.0

var stamina_regen_modifier = 1.0
var stamina_regen_rate = 5.0

func _process(_delta):
	if stamina < max_stamina:
		regenerate_stamina(stamina_regen_rate * stamina_regen_modifier * _delta)

func take_damage(amount: float):
	health -= amount

func heal(amount: float):
	health += amount

func use_stamina(amount: float):
	stamina -= amount

func regenerate_stamina(amount: float):
	stamina += amount


