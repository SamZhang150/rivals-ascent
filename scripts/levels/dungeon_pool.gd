class_name DungeonPool
extends Resource

@export var difficulty_1: Array[PackedScene] = []
@export var difficulty_2: Array[PackedScene] = []
@export var difficulty_3: Array[PackedScene] = []
@export var difficulty_4: Array[PackedScene] = []

func get_room(difficulty: int) -> PackedScene:
	var pool: Array[PackedScene]
	match difficulty:
		1: pool = difficulty_1
		2: pool = difficulty_2
		3: pool = difficulty_3
		4: pool = difficulty_4
		_: pool = difficulty_1

	if pool.is_empty():
		push_error("No rooms for difficulty %d" % difficulty)
		return null

	return pool.pick_random()
