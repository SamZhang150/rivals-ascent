## dungeon_room.gd
## Attach to the root of dungeon_room.tscn
##
## === DUNGEON_ROOM.TSCN NODE TREE ===
## DungeonRoom (Node2D)                 [script: dungeon_room.gd]
## ├── WallLayer (TileMapLayer)         ← wall tiles with collision in TileSet
## ├── FloorLayer (TileMapLayer)        ← floor tiles, no collision
## ├── SpawnPoint (Marker2D)            ← where player teleports in
## ├── ExitDoor (StaticBody2D)          ← blocks path until room is cleared
## │   ├── CollisionShape2D             ← physical blocker
## │   └── Sprite2D                     ← door visual
## ├── ExitTrigger (Area2D)             ← detects player stepping on exit after door opens
## │   └── CollisionShape2D             ← placed just past where the door was
## └── Enemies (Node2D)                 ← parent for all enemy instances
##     ├── Enemy                        ← instances of enemy.tscn (see below)
##     ├── Enemy
##     └── ...
##
## === NOTES ===
## - The ExitDoor is a StaticBody2D that physically blocks the exit.
##   When all enemies die, we remove it and enable the ExitTrigger.
## - Place enemies as children of the Enemies node in the editor,
##   or spawn them procedurally in _ready().
## - Each enemy should emit a "died" signal when killed.

extends Node2D

signal room_cleared()

@onready var exit_door: StaticBody2D = $ExitDoor
@onready var exit_trigger: Area2D = $ExitTrigger

var enemies_alive: int = 0
var is_cleared: bool = false
var room_player: CharacterBody2D = null

func _ready():
	$ExitDoor.visible = true
	$ExitDoor/AnimatedSprite2D.visible = true
	$ExitDoor/AnimatedSprite2D.z_index = 100
	if $ExitDoor/AnimatedSprite2D.sprite_frames != null and $ExitDoor/AnimatedSprite2D.sprite_frames.has_animation("closed"):
		$ExitDoor/AnimatedSprite2D.play("closed")
	else:
		$ExitDoor/AnimatedSprite2D.play()
	$ExitDoor/AnimatedSprite2D.modulate = Color(1.0, 1.0, 1.0, 0.35)
	
	enemies_alive = 0
	# Count enemies and connect their death signals
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_ancestor_of(enemy):
			enemies_alive += 1
			if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
				enemy.died.connect(_on_enemy_died)

	# Use an authoritative recount in case any enemy state changed before signal wiring.
	enemies_alive = _count_alive_room_enemies()
	
	print(name, " enemies_alive = ", enemies_alive)

	# Keep mirror visible but inactive until room is cleared.
	exit_door.visible = true
	exit_door.process_mode = Node.PROCESS_MODE_DISABLED
	if exit_door.has_node("CollisionShape2D"):
		exit_door.get_node("CollisionShape2D").disabled = true


	# Exit trigger is disabled until room is cleared
	exit_trigger.monitoring = false
	exit_trigger.body_entered.connect(_on_exit_trigger_body_entered)

	# If room has no enemies, open immediately
	if enemies_alive == 0:
		_open_exit()
		
func set_room_player(player: CharacterBody2D) -> void:
	set_room_active(true, player)


func set_room_active(active: bool, player: CharacterBody2D = null) -> void:
	room_player = player if active else null
	for node in find_children("*", "", true, false):
		if node.is_in_group("enemies") and node.has_method("set_player"):
			node.set_player(room_player)
			
	#for enemy in get_tree().get_nodes_in_group("enemies"):
		#if is_ancestor_of(enemy) and enemy.has_method("set_player"):
			#enemy.set_player(room_player)
		
			
func _on_enemy_died():
	enemies_alive = _count_alive_room_enemies()
	print(name, " enemy died, remaining = ", enemies_alive)

	if enemies_alive <= 0:
		_open_exit()


func _count_alive_room_enemies() -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not is_ancestor_of(enemy):
			continue
		if "dead" in enemy and bool(enemy.get("dead")):
			continue
		count += 1
	return count
		
func _open_exit():
	if is_cleared:
		return
		
	is_cleared = true
	
	$Done.play()
	
	exit_door.visible = true
	exit_door.process_mode = Node.PROCESS_MODE_INHERIT
	if exit_door.has_node("AnimatedSprite2D"):
		var mirror_sprite := exit_door.get_node("AnimatedSprite2D") as AnimatedSprite2D
		if mirror_sprite != null:
			mirror_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if mirror_sprite.sprite_frames != null and mirror_sprite.sprite_frames.has_animation("open"):
				mirror_sprite.play("open")
	
	if exit_door.has_node("CollisionShape2D"):
		exit_door.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	# Remove the physical door blocker
	#if is_instance_valid(exit_door):
		#exit_door.queue_free()
	
		
	# Enable the trigger area so stepping on it fires room_cleared
	exit_trigger.monitoring = true


func _on_exit_trigger_body_entered(body: Node2D):
	print("trigger hit by: ", body.name, " room_player: ", room_player.name if room_player != null else "null")

	if not is_cleared:
		return
	if body == room_player:
		room_cleared.emit()
		# Disable trigger so it doesn't fire again
		exit_trigger.set_deferred("monitoring", false)
