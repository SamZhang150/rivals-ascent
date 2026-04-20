extends Node

signal phase_changed(new_phase: int)
signal split_screen_changed(enabled: bool)
signal dungeon_transition_requested(player_id: int, scene_path: String)
signal shared_transition_requested(scene_path: String)
signal player_ready_changed(player_id: int, ready: bool)
signal dungeon_room_assigned(player_id: int, room_number: int, difficulty: int, scene_path: String)

enum GamePhase {
	DUNGEON,
	SHOP,
	PVP,
	ENDED,
}

const PLAYER_1 := 1
const PLAYER_2 := 2

const ROOMS_PER_DUNGEON_PHASE := 4
const TOTAL_LOOPS := 5

@export var shop_scene_path := "res://scenes/levels/shop.tscn"
@export var pvp_scene_path := "res://scenes/levels/pvp.tscn"
@export var ending_scene_path := "res://scenes/levels/ending.tscn"
@export var room_difficulty_by_number: PackedInt32Array = PackedInt32Array([
	1, 1, 2, 2, 3, 3, 3, 3, 4, 4,
	4, 4, 5, 5, 5, 5, 5, 5, 5, 5,
])

@export var difficulty_1_rooms: Array[String] = [
	"res://scenes/levels/days/day1.tscn",
	"res://scenes/levels/days/day2.tscn",
]
@export var difficulty_2_rooms: Array[String] = [
	"res://scenes/levels/dreams/dream1.tscn",
	"res://scenes/levels/days/day3.tscn",
	"res://scenes/levels/dreams/dream2.tscn",
]
@export var difficulty_3_rooms: Array[String] = [
	"res://scenes/levels/days/day4.tscn",
	"res://scenes/levels/dreams/dream3.tscn",
	"res://scenes/levels/days/day5.tscn",
]
@export var difficulty_4_rooms: Array[String] = [
	"res://scenes/levels/dreams/dream4.tscn",
	"res://scenes/levels/days/day6.tscn",
]
@export var difficulty_5_rooms: Array[String] = [
	"res://scenes/levels/dreams/dream5.tscn",
	"res://scenes/levels/days/day7.tscn",
]

var current_quota = 0

var _phase := GamePhase.DUNGEON
var _split_screen_enabled := true
var _loop_index := 0
var _room_number := {
	PLAYER_1: 1,
	PLAYER_2: 1,
}
var _rooms_completed_in_loop := {
	PLAYER_1: 0,
	PLAYER_2: 0,
}
var _player_quota := {
	PLAYER_1: 0,
	PLAYER_2: 0,
}
var _active_room_scene := {
	PLAYER_1: "",
	PLAYER_2: "",
}
var _active_room_difficulty := {
	PLAYER_1: 1,
	PLAYER_2: 1,
}
var _in_shop := {
	PLAYER_1: false,
	PLAYER_2: false,
}
var _ready_for_pvp := {
	PLAYER_1: false,
	PLAYER_2: false,
}

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func start_run() -> void:
	_reset_run_state()
	_set_phase(GamePhase.DUNGEON)
	_set_split_screen(true)

	_assign_and_emit_next_room(PLAYER_1)
	_assign_and_emit_next_room(PLAYER_2)

func advance_level(player_id: int = PLAYER_1) -> void:
	advance_room(player_id)

func advance_room(player_id: int = PLAYER_1) -> void:
	if not _is_valid_player(player_id):
		return

	if _phase != GamePhase.DUNGEON:
		return

	_rooms_completed_in_loop[player_id] += 1
	_room_number[player_id] += 1
	_player_quota[player_id] = 0
	if player_id == PLAYER_1:
		current_quota = 0

	if _rooms_completed_in_loop[player_id] < ROOMS_PER_DUNGEON_PHASE:
		_assign_and_emit_next_room(player_id)
	else:
		mark_player_entered_shop(player_id)

func mark_player_entered_shop(player_id: int) -> void:
	if not _is_valid_player(player_id):
		return

	if _phase == GamePhase.PVP or _phase == GamePhase.ENDED:
		return

	if not _in_shop[player_id]:
		_in_shop[player_id] = true

	if _phase != GamePhase.SHOP:
		_set_phase(GamePhase.SHOP)
		emit_signal("shared_transition_requested", shop_scene_path)

	_update_split_screen_for_shop()

func set_player_ready(player_id: int, ready: bool) -> void:
	if not _is_valid_player(player_id):
		return

	if _phase != GamePhase.SHOP:
		return

	_ready_for_pvp[player_id] = ready
	emit_signal("player_ready_changed", player_id, ready)

	if _ready_for_pvp[PLAYER_1] and _ready_for_pvp[PLAYER_2]:
		_start_pvp()

func finish_pvp() -> void:
	if _phase != GamePhase.PVP:
		return

	_loop_index += 1
	if _loop_index >= TOTAL_LOOPS:
		_set_phase(GamePhase.ENDED)
		emit_signal("shared_transition_requested", ending_scene_path)
		return

	_begin_next_dungeon_loop()

func get_phase() -> int:
	return _phase

func is_split_screen_enabled() -> bool:
	return _split_screen_enabled

func get_level_index(player_id: int = PLAYER_1) -> int:
	return get_room_number(player_id)

func get_room_number(player_id: int = PLAYER_1) -> int:
	if not _is_valid_player(player_id):
		return 1
	return _room_number[player_id]

func get_loop_index() -> int:
	return _loop_index

func get_active_room_scene(player_id: int = PLAYER_1) -> String:
	if not _is_valid_player(player_id):
		return ""
	return _active_room_scene[player_id]

func get_active_room_difficulty(player_id: int = PLAYER_1) -> int:
	if not _is_valid_player(player_id):
		return 1
	return _active_room_difficulty[player_id]

func get_current_level_path(player_id: int = PLAYER_1) -> String:
	return get_active_room_scene(player_id)

func is_dream(player_id: int = PLAYER_1) -> bool:
	return get_active_room_scene(player_id).contains("dream")

func _start_pvp() -> void:
	_set_split_screen(false)
	_set_phase(GamePhase.PVP)
	emit_signal("shared_transition_requested", pvp_scene_path)

func _begin_next_dungeon_loop() -> void:
	_set_phase(GamePhase.DUNGEON)
	_set_split_screen(true)
	_in_shop[PLAYER_1] = false
	_in_shop[PLAYER_2] = false
	_ready_for_pvp[PLAYER_1] = false
	_ready_for_pvp[PLAYER_2] = false
	_rooms_completed_in_loop[PLAYER_1] = 0
	_rooms_completed_in_loop[PLAYER_2] = 0
	_assign_and_emit_next_room(PLAYER_1)
	_assign_and_emit_next_room(PLAYER_2)

func _update_split_screen_for_shop() -> void:
	# Keep split screen while only one player has reached shop.
	var both_in_shop: bool = _in_shop[PLAYER_1] and _in_shop[PLAYER_2]
	_set_split_screen(not both_in_shop)

func _assign_and_emit_next_room(player_id: int) -> void:
	var room_number: int = _room_number[player_id]
	var difficulty := _difficulty_for_room(room_number)
	var scene_path := _pick_room_for_difficulty(difficulty)

	_active_room_difficulty[player_id] = difficulty
	_active_room_scene[player_id] = scene_path

	emit_signal("dungeon_room_assigned", player_id, room_number, difficulty, scene_path)
	emit_signal("dungeon_transition_requested", player_id, scene_path)

func _difficulty_for_room(room_number: int) -> int:
	if room_number <= 0:
		return 1

	if room_number <= room_difficulty_by_number.size():
		return max(1, room_difficulty_by_number[room_number - 1])

	if room_difficulty_by_number.is_empty():
		return 5

	return max(1, room_difficulty_by_number[room_difficulty_by_number.size() - 1])

func _pick_room_for_difficulty(difficulty: int) -> String:
	var pool := _pool_for_difficulty(difficulty)
	if pool.is_empty():
		pool = _fallback_pool()
	if pool.is_empty():
		return ""
	return pool[_rng.randi_range(0, pool.size() - 1)]

func _pool_for_difficulty(difficulty: int) -> Array[String]:
	match difficulty:
		1:
			return difficulty_1_rooms
		2:
			return difficulty_2_rooms
		3:
			return difficulty_3_rooms
		4:
			return difficulty_4_rooms
		_:
			return difficulty_5_rooms

func _fallback_pool() -> Array[String]:
	var merged: Array[String] = []
	merged.append_array(difficulty_1_rooms)
	merged.append_array(difficulty_2_rooms)
	merged.append_array(difficulty_3_rooms)
	merged.append_array(difficulty_4_rooms)
	merged.append_array(difficulty_5_rooms)
	return merged

func _set_phase(new_phase: int) -> void:
	if _phase == new_phase:
		return

	_phase = new_phase
	emit_signal("phase_changed", _phase)

func _set_split_screen(enabled: bool) -> void:
	if _split_screen_enabled == enabled:
		return

	_split_screen_enabled = enabled
	emit_signal("split_screen_changed", _split_screen_enabled)

func _reset_run_state() -> void:
	_loop_index = 0
	_room_number[PLAYER_1] = 1
	_room_number[PLAYER_2] = 1
	_rooms_completed_in_loop[PLAYER_1] = 0
	_rooms_completed_in_loop[PLAYER_2] = 0
	_player_quota[PLAYER_1] = 0
	_player_quota[PLAYER_2] = 0
	_active_room_scene[PLAYER_1] = ""
	_active_room_scene[PLAYER_2] = ""
	_active_room_difficulty[PLAYER_1] = 1
	_active_room_difficulty[PLAYER_2] = 1
	current_quota = 0
	_in_shop[PLAYER_1] = false
	_in_shop[PLAYER_2] = false
	_ready_for_pvp[PLAYER_1] = false
	_ready_for_pvp[PLAYER_2] = false

func _is_valid_player(player_id: int) -> bool:
	return player_id == PLAYER_1 or player_id == PLAYER_2
