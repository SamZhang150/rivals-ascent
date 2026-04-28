extends Node

func _ready() -> void:
	reset_player_stats()
	_configure_controller_input_map()


func _configure_controller_input_map() -> void:
	# Device 0 controls player 1, device 1 controls player 2.
	_add_controller_mapping(1, 0)
	_add_controller_mapping(2, 1)
	_ensure_action_exists("p1_toggle_controls", 0.85)
	_ensure_action_exists("p2_toggle_controls", 0.85)
	InputMap.action_set_deadzone("p1_toggle_controls", 0.85)
	InputMap.action_set_deadzone("p2_toggle_controls", 0.85)
	_add_joy_motion_event("p1_toggle_controls", 0, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_motion_event("p2_toggle_controls", 1, JOY_AXIS_TRIGGER_LEFT, 1.0)


func _add_controller_mapping(player_id: int, device_id: int) -> void:
	var prefix := "p1_" if player_id == 1 else "p2_"

	_add_joy_motion_event(prefix + "left", device_id, JOY_AXIS_LEFT_X, -1.0)
	_add_joy_motion_event(prefix + "right", device_id, JOY_AXIS_LEFT_X, 1.0)
	_add_joy_motion_event(prefix + "up", device_id, JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_motion_event(prefix + "down", device_id, JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button_event(prefix + "left", device_id, JOY_BUTTON_DPAD_LEFT)
	_add_joy_button_event(prefix + "right", device_id, JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button_event(prefix + "up", device_id, JOY_BUTTON_DPAD_UP)
	_add_joy_button_event(prefix + "down", device_id, JOY_BUTTON_DPAD_DOWN)

	_add_joy_motion_event(prefix + "aim_left", device_id, JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_motion_event(prefix + "aim_right", device_id, JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_motion_event(prefix + "aim_up", device_id, JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_motion_event(prefix + "aim_down", device_id, JOY_AXIS_RIGHT_Y, 1.0)

	_add_joy_motion_event(prefix + "attack", device_id, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_button_event(prefix + "interact", device_id, JOY_BUTTON_X)
	_add_joy_button_event(prefix + "dash", device_id, JOY_BUTTON_A)
	_add_joy_button_event(prefix + "invprev", device_id, JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button_event(prefix + "invnext", device_id, JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button_event(prefix + "back", device_id, JOY_BUTTON_B)
	_add_joy_button_event(prefix + "ready", device_id, JOY_BUTTON_Y)


func _ensure_action_exists(action_name: String, deadzone: float = 0.2) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name, deadzone)


func _add_joy_button_event(action_name: String, device_id: int, button: JoyButton) -> void:
	_ensure_action_exists(action_name)
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventJoypadButton:
			var joy_event := existing_event as InputEventJoypadButton
			if joy_event.device == device_id and joy_event.button_index == button:
				return

	var new_event := InputEventJoypadButton.new()
	new_event.device = device_id
	new_event.button_index = button
	InputMap.action_add_event(action_name, new_event)


func _add_joy_motion_event(action_name: String, device_id: int, axis: JoyAxis, axis_value: float) -> void:
	_ensure_action_exists(action_name)
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventJoypadMotion:
			var joy_event := existing_event as InputEventJoypadMotion
			if joy_event.device == device_id and joy_event.axis == axis and is_equal_approx(joy_event.axis_value, axis_value):
				return

	var new_event := InputEventJoypadMotion.new()
	new_event.device = device_id
	new_event.axis = axis
	new_event.axis_value = axis_value
	InputMap.action_add_event(action_name, new_event)

# different params by player
const DEFAULT_PLAYER_STATS := {
	1: {
		"health": 75,
		"max_health": 100,
		"speed": 100.0,
		"is_dead": false,
		"attack_damage": 2,
		"attack_duration": 0.2,
		"attack_cooldown": 1.75,
		"invuln_time": 0.5,
		"knockback_strength": 120.0,
		"knockback_decay": 700.0,
		"dashes_max": 1,
		"dashes_available": 1
	},
	2: {
		"health": 75,
		"max_health": 100,
		"speed": 100.0,
		"is_dead": false,
		"attack_damage": 2,
		"attack_duration": 0.2,
		"attack_cooldown": 1.75,
		"invuln_time": 0.5,
		"knockback_strength": 120.0,
		"knockback_decay": 700.0,
		"dashes_max": 1,
		"dashes_available": 1
	}
}

var player_stats = {}


func _clone_player_stats_defaults() -> Dictionary:
	return {
		1: DEFAULT_PLAYER_STATS[1].duplicate(true),
		2: DEFAULT_PLAYER_STATS[2].duplicate(true)
	}


func reset_player_stats() -> void:
	player_stats = _clone_player_stats_defaults()
