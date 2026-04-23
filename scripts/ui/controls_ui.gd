extends Control

@export_range(0, 2, 1) var player_id: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const PLAYER_ACTION_SUFFIXES: Array[String] = [
	"up",
	"down",
	"left",
	"right",
	"aim_up",
	"aim_down",
	"aim_left",
	"aim_right",
	"attack",
	"interact",
	"dash",
	"invprev",
	"invnext",
	"back",
	"ready",
	"toggle_controls",
]


func _resolve_player_id() -> int:
	if player_id in [1, 2]:
		return player_id

	var lower_name := name.to_lower()
	if lower_name.contains("left"):
		return 1
	if lower_name.contains("right"):
		return 2

	# Fallback for any unnamed/legacy controls panel.
	return 1


func _event_matches_player(event: InputEvent) -> bool:
	var prefix := "p1_" if _resolve_player_id() == 1 else "p2_"
	for suffix in PLAYER_ACTION_SUFFIXES:
		if event.is_action_pressed(prefix + suffix):
			return true
	return false


func _toggle_action_name() -> String:
	return "p1_toggle_controls" if _resolve_player_id() == 1 else "p2_toggle_controls"


func _event_is_toggle_just_pressed(event: InputEvent) -> bool:
	var action_name := _toggle_action_name()
	return event.is_action_pressed(action_name) and Input.is_action_just_pressed(action_name)


func _is_controller_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not _event_matches_player(event):
		return

	if _event_is_toggle_just_pressed(event):
		visible = not visible

	if not visible:
		return

	var anim := "controls" if _is_controller_event(event) else "controlskey"
	if sprite.animation != anim:
		sprite.play(anim)
