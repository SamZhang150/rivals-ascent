extends Node2D

@onready var _sprite: Sprite2D = $Sprite2D

var _player: CharacterBody2D = null

func _ready() -> void:
	# Keep world-space scale/rotation independent of the scaled player node.
	set_as_top_level(true)
	scale = Vector2.ONE
	_player = _resolve_player()
	visible = false


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player()

	if _player == null:
		visible = false
		return

	var room: Node2D = _get_active_dungeon_room_for_player(_player)
	if room == null:
		visible = false
		return

	var player_viewport: SubViewport = _get_player_viewport(_player)
	if player_viewport == null:
		visible = false
		return

	var alive_enemies: Array[Node2D] = _get_alive_enemies_in_room(room)
	var target_position: Vector2 = Vector2.ZERO
	var has_target := false

	if alive_enemies.is_empty():
		target_position = _get_room_top_middle(room)
		has_target = true
	else:
		if _has_any_visible_enemy(alive_enemies, player_viewport):
			visible = false
			return

		var target_enemy: Node2D = _get_nearest_offscreen_enemy(alive_enemies, _player, player_viewport)
		if target_enemy != null:
			target_position = target_enemy.global_position
			has_target = true

	if not has_target:
		visible = false
		return

	# Always anchor to the owning player's world position.
	global_position = _player.global_position

	var to_target: Vector2 = target_position - _player.global_position
	if to_target.length_squared() <= 0.001:
		visible = false
		return

	rotation = to_target.angle()
	visible = true
	if _sprite != null:
		_sprite.visible = true


func _resolve_player() -> CharacterBody2D:
	# Prefer the direct parent so each player keeps its own arrow instance.
	if get_parent() is CharacterBody2D:
		return get_parent() as CharacterBody2D

	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D:
			return node as CharacterBody2D

	return null


func _get_active_dungeon_room_for_player(player: CharacterBody2D) -> Node2D:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null

	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back() as Node
		if node is Node2D:
			var candidate: Node2D = node as Node2D
			if candidate.has_node("ExitDoor") and candidate.has_node("ExitTrigger") and candidate.has_method("set_room_active"):
				var room_player: CharacterBody2D = candidate.get("room_player") as CharacterBody2D
				if room_player == player:
					return candidate

		for child: Node in node.get_children():
			stack.push_back(child)

	return null


func _get_nearest_alive_enemy_in_room(room: Node2D, player: CharacterBody2D) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist_sq: float = INF

	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue

		var enemy: Node2D = node as Node2D
		if not room.is_ancestor_of(enemy):
			continue
		if "dead" in enemy and bool(enemy.get("dead")):
			continue

		var dist_sq: float = player.global_position.distance_squared_to(enemy.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy

	return nearest


func _get_alive_enemies_in_room(room: Node2D) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue

		var enemy: Node2D = node as Node2D
		if not room.is_ancestor_of(enemy):
			continue
		if "dead" in enemy and bool(enemy.get("dead")):
			continue

		enemies.append(enemy)

	return enemies


func _get_nearest_offscreen_enemy(enemies: Array[Node2D], player: CharacterBody2D, player_viewport: SubViewport) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist_sq: float = INF

	for enemy: Node2D in enemies:
		if _is_world_point_visible_in_viewport(enemy.global_position, player_viewport):
			continue

		var dist_sq: float = player.global_position.distance_squared_to(enemy.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy

	return nearest


func _has_any_visible_enemy(enemies: Array[Node2D], player_viewport: SubViewport) -> bool:
	for enemy: Node2D in enemies:
		if _is_world_point_visible_in_viewport(enemy.global_position, player_viewport):
			return true

	return false


func _get_player_viewport(player: CharacterBody2D) -> SubViewport:
	var root: Node = get_tree().current_scene
	if root == null:
		return null

	var player_id_value: Variant = player.get("player_id")
	var player_id: int = int(player_id_value)

	if player_id == 1:
		return root.get_node_or_null("ScreenDisplay/ViewportContainer/Left/SubViewport") as SubViewport
	if player_id == 2:
		return root.get_node_or_null("ScreenDisplay/ViewportContainer/Right/SubViewport") as SubViewport

	if player.name == "Player1":
		return root.get_node_or_null("ScreenDisplay/ViewportContainer/Left/SubViewport") as SubViewport
	if player.name == "Player2":
		return root.get_node_or_null("ScreenDisplay/ViewportContainer/Right/SubViewport") as SubViewport

	return null


func _is_world_point_visible_in_viewport(world_point: Vector2, viewport: SubViewport) -> bool:
	# canvas_transform translates world -> viewport coordinates.
	var view_space_point: Vector2 = viewport.canvas_transform * world_point
	var visible_rect := Rect2(Vector2.ZERO, Vector2(viewport.size))
	return visible_rect.has_point(view_space_point)


func _get_room_top_middle(room: Node2D) -> Vector2:
	var cam_top_left: Marker2D = room.get_node_or_null("CamTopLeft") as Marker2D
	var cam_bottom_right: Marker2D = room.get_node_or_null("CamBottomRight") as Marker2D
	if cam_top_left != null and cam_bottom_right != null:
		return Vector2(
			(cam_top_left.global_position.x + cam_bottom_right.global_position.x) * 0.5,
			cam_top_left.global_position.y
		)

	var exit_door: Node2D = room.get_node_or_null("ExitDoor") as Node2D
	if exit_door != null:
		return exit_door.global_position

	return room.global_position
