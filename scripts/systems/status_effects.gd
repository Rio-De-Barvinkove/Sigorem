var active_states: Array[PlayerState] = []

func _ready():
	# Connect to needs system signals
	var needs_system = get_node("../NeedsSystem") # Adjust path as needed
	needs_system.needs_changed.connect(check_states)
	
func check_states(_need_name, _value, _max_value):
	active_states.clear()
	
	var needs_system = get_node("../NeedsSystem")
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
		
	# Apply effects based on states
	apply_state_effects()

func apply_state_effects():
	var player_stats = get_node("../PlayerStats") # Adjust path as needed
	
	# Reset modifiers first
	player_stats.stamina_regen_modifier = 1.0
	
	if active_states.has(PlayerState.STARVING) or active_states.has(PlayerState.DEHYDRATED):
		player_stats.take_damage(0.1) # small continuous damage
	
	if active_states.has(PlayerState.EXHAUSTED):
		player_stats.stamina_regen_modifier = 0.5
