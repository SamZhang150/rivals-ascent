extends CanvasLayer

signal fade_done(side: String)

@export_enum("left", "right") var side: String = "left"
@export_range(0.1, 0.9, 0.05) var split_ratio := 0.5

const MAIN_MENU_SCENE_PATH := "res://scenes/levels/main_menu.tscn"
const LOBBY_SCENE_PATH := "res://scenes/levels/shared/lobby.tscn"

var _is_transitioning := false

func _ready() -> void:
	_apply_split_layout()

func fade_in() -> void:
	await _play_and_wait("fade_in")

func fade_out() -> void:
	await _play_and_wait("fade_out")

func transition_with_action(action: Callable) -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	await fade_out()

	if action.is_valid():
		action.call()

	await fade_in()
	_is_transitioning = false

func transition_to(scene_path: String) -> void:
	var use_fullscreen_fade := _should_use_fullscreen_transition(scene_path)
	if use_fullscreen_fade:
		_apply_fullscreen_layout()

	await transition_with_action(
		func() -> void:
			get_tree().change_scene_to_file(scene_path)
	)

	if use_fullscreen_fade:
		_apply_split_layout()

func _play_and_wait(animation_name: String) -> void:
	$AnimationPlayer.play(animation_name)
	await $AnimationPlayer.animation_finished
	emit_signal("fade_done", side)

func _apply_split_layout() -> void:
	var rect := $ColorRect
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0
	rect.anchor_top = 0.0
	rect.anchor_bottom = 1.0

	if side == "left":
		rect.anchor_left = 0.0
		rect.anchor_right = split_ratio
	else:
		rect.anchor_left = split_ratio
		rect.anchor_right = 1.0

func _apply_fullscreen_layout() -> void:
	var rect := $ColorRect
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0
	rect.anchor_left = 0.0
	rect.anchor_top = 0.0
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0

func _should_use_fullscreen_transition(next_scene_path: String) -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false

	return tree.current_scene.scene_file_path == MAIN_MENU_SCENE_PATH and next_scene_path == LOBBY_SCENE_PATH
