extends Node

signal needs_changed(need_name, value, max_value)

var hunger = 100.0:
	set(value):
		hunger = clamp(value, 0, max_hunger)
		emit_signal("needs_changed", "hunger", hunger, max_hunger)
var max_hunger = 100.0
@export var hunger_drain_rate = 0.1 # per second

var thirst = 100.0:
	set(value):
		thirst = clamp(value, 0, max_thirst)
		emit_signal("needs_changed", "thirst", thirst, max_thirst)
var max_thirst = 100.0
@export var thirst_drain_rate = 0.15 # per second

var sleepiness = 100.0:
	set(value):
		sleepiness = clamp(value, 0, max_sleepiness)
		emit_signal("needs_changed", "sleepiness", sleepiness, max_sleepiness)
var max_sleepiness = 100.0
@export var sleepiness_drain_rate = 0.05 # per second

func _process(delta):
	hunger -= hunger_drain_rate * delta
	thirst -= thirst_drain_rate * delta
	sleepiness -= sleepiness_drain_rate * delta

func eat(amount: float):
	hunger += amount

func drink(amount: float):
	thirst += amount

func sleep(amount: float):
	sleepiness += amount
