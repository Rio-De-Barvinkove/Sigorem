extends Node

enum PlayerState {
	NORMAL,
	HUNGRY,
	STARVING,
	THIRSTY,
	DEHYDRATED,
	TIRED,
	EXHAUSTED,
	COLD,
	HOT,
	SICK,
	INJURED
}

var active_states: Array[PlayerState] = []

func _ready():
	var needs_system = get_node_or_null("/root/World/Player/NeedsSystem")
	if needs_system:
		needs_system.needs_changed.connect(check_states)

func check_states(_need_name, _value, _max_value):
	active_states.clear()
	var needs_system = get_node_or_null("/root/World/Player/NeedsSystem")
	if not needs_system:
		return

	if needs_system.hunger < 20:
		active_states.append(PlayerState.STARVING)
	elif needs_system.hunger < 50:
		active_states.append(PlayerState.HUNGRY)

	if needs_system.thirst < 20:
		active_states.append(PlayerState.DEHYDRATED)
	elif needs_system.thirst < 50:
		active_states.append(PlayerState.THIRSTY)

	if needs_system.sleepiness < 20:
		active_states.append(PlayerState.EXHAUSTED)
	elif needs_system.sleepiness < 50:
		active_states.append(PlayerState.TIRED)

	apply_state_effects()

func apply_state_effects():
	var player_stats = get_node_or_null("/root/World/Player/PlayerStats")
	if not player_stats:
		return

	player_stats.stamina_regen_modifier = 1.0

	if active_states.has(PlayerState.STARVING) or active_states.has(PlayerState.DEHYDRATED):
		player_stats.take_damage(0.1)

	if active_states.has(PlayerState.EXHAUSTED):
		player_stats.stamina_regen_modifier = 0.5


