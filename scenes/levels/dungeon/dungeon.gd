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
	enemies_alive = 0
	# Count enemies and connect their death signals
	for node in find_children("*", "", true, false):
		if node.is_in_group("enemies"):
			enemies_alive += 1
			if node.has_signal("died") and not node.died.is_connected(_on_enemy_died):
				node.died.connect(_on_enemy_died)

	# Exit trigger is disabled until room is cleared
	exit_trigger.monitoring = false
	exit_trigger.body_entered.connect(_on_exit_trigger_body_entered)

	# If room has no enemies, open immediately
	if enemies_alive == 0:
		_open_exit()
		
func set_room_player(player: CharacterBody2D) -> void:
	for node in find_children("*", "", true, false):
		if node.is_in_group("enemies") and node.has_method("set_player"):
			node.set_player(player)
		
			
func _on_enemy_died():
	enemies_alive -= 1
	if enemies_alive <= 0:
		_open_exit()
		
func _open_exit():
	if is_cleared:
		return
		
	is_cleared = true
	
	# Remove the physical door blocker
	if is_instance_valid(exit_door):
		exit_door.queue_free()
		
	# Enable the trigger area so stepping on it fires room_cleared
	exit_trigger.monitoring = true


func _on_exit_trigger_body_entered(body: Node2D):
	if not is_cleared:
		return
	if body == room_player:
		room_cleared.emit()
		# Disable trigger so it doesn't fire again
		exit_trigger.set_deferred("monitoring", false)
