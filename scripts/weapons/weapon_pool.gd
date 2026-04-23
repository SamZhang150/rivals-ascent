class_name WeaponPool
extends Resource

@export var power_1: Array[PackedScene] = []
@export var power_2: Array[PackedScene] = []
@export var power_3: Array[PackedScene] = []
@export var power_4: Array[PackedScene] = []


func get_weapons_in_power_range(min_power: int, max_power: int) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var seen_paths: Dictionary = {}
	for power in range(min_power, max_power + 1):
		for weapon_scene in _get_pool_for_power(power):
			if weapon_scene == null:
				continue
			var key := weapon_scene.resource_path
			if key.is_empty():
				key = str(weapon_scene.get_instance_id())
			if seen_paths.has(key):
				continue
			seen_paths[key] = true
			result.append(weapon_scene)
	return result

func get_weapon(power: int) -> PackedScene:
	var pool := _get_pool_for_power(power)

	if pool.is_empty():
		push_error("No weapons for power %d" % power)
		return null

	return pool.pick_random()


func _get_pool_for_power(power: int) -> Array[PackedScene]:
	match power:
		1:
			return power_1
		2:
			return power_2
		3:
			return power_3
		4:
			return power_4
		_:
			return power_1
