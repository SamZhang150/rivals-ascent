## player.gd
## Attach to the root of player.tscn
##
## === PLAYER.TSCN NODE TREE ===
## Player (CharacterBody2D)             [script: player.gd]
## ├── AnimatedSprite2D                 ← player sprite/animation
## ├── CollisionShape2D                 ← physics body
## ├── HitboxArea (Area2D)              ← detects incoming damage
## │   └── CollisionShape2D
## ├── AttackArea (Area2D)              ← deals damage on attack
## │   └── CollisionShape2D
## └── AttackCooldownTimer (Timer)      [wait_time=0.4, one_shot=true]
##
## === INPUT MAP (Project > Input Map) ===
## You should have:
##   p1_up, p1_down, p1_left, p1_right, p1_attack, p1_ready, p1_interact
##   p2_up, p2_down, p2_left, p2_right, p2_attack, p2_ready, p2_interact

extends CharacterBody2D

# ─── CONFIG ──────────────────────────────────────────────
@export var speed: float = 50.0
@export var max_health: int = 100
@export var attack_damage: int = 20

# ─── STATE ───────────────────────────────────────────────
var player_id: int = 1  # set by game manager on spawn
var can_move: bool = true
var can_attack: bool = false
var health: int = max_health
var is_attacking: bool = false

# Shop / progression state
var gold: int = 100
var inventory: Array[String] = []
var nearby_station: Area2D = null
var shop_ui_open: bool = false

# Input action prefixes
var _prefix: String = "p1_"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_timer: Timer = $AttackCooldownTimer
@onready var shop_ui: Node = get_tree().current_scene.get_node("UI/ShopUI")

signal died(player_id: int)


func _ready() -> void:
	add_to_group("player")
	
	_prefix = "p1_" if player_id == 1 else "p2_"
	attack_area.monitoring = false
	attack_timer.timeout.connect(_on_attack_cooldown_finished)

	# Connect hitbox to receive damage
	var hitbox := $HitboxArea
	hitbox.add_to_group("player_hitbox")
	hitbox.area_entered.connect(_on_hitbox_area_entered)

	health = max_health


func _physics_process(_delta: float) -> void:
	if shop_ui_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Gather directional input
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis(_prefix + "left", _prefix + "right")
	input_dir.y = Input.get_axis(_prefix + "up", _prefix + "down")
	input_dir = input_dir.normalized()

	velocity = input_dir * speed
	move_and_slide()

	# Flip sprite and attack area based on movement direction
	if input_dir.x != 0:
		sprite.flip_h = input_dir.x < 0
		attack_area.scale.x = -1 if input_dir.x < 0 else 1


func _unhandled_input(event: InputEvent) -> void:
	if shop_ui_open:
		if event.is_action_pressed(_prefix + "back"):
			close_shop_ui()
		return

	if nearby_station != null and event.is_action_pressed(_prefix + "interact"):
		open_shop_ui(nearby_station.station_type)
		return

	if not can_attack:
		return

	if event.is_action_pressed(_prefix + "attack") and not is_attacking:
		_perform_attack()


func _perform_attack() -> void:
	is_attacking = true
	attack_area.monitoring = true
	attack_timer.start()
	# You could play an attack animation here
	# sprite.play("attack")


func _on_attack_cooldown_finished() -> void:
	is_attacking = false
	attack_area.monitoring = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	# Check if the incoming area is another player's AttackArea
	var attacker := area.get_parent()
	
	if attacker == null or attacker == self:
		return

	if attacker.is_in_group("player"):
		take_damage(attacker.attack_damage)


func take_damage(amount: int) -> void:
	health -= amount

	# Flash the sprite red briefly
	sprite.modulate = Color.RED
	get_tree().create_timer(0.15).timeout.connect(
		func() -> void:
			sprite.modulate = Color.WHITE
	)

	if health <= 0:
		_die()


func _die() -> void:
	if shop_ui_open:
		close_shop_ui()

	can_move = false
	can_attack = false
	visible = false

	# Notify game manager
	var game_manager := get_tree().root.get_node("Main") if get_tree().root.has_node("Main") else null
	if game_manager != null and game_manager.has_method("on_player_died"):
		game_manager.on_player_died(player_id)


func reset_for_round() -> void:
	if shop_ui_open:
		close_shop_ui()

	health = max_health
	can_move = true
	visible = true
	sprite.modulate = Color.WHITE
	is_attacking = false
	attack_area.monitoring = false


# ─── SHOP INTERACTION ────────────────────────────────────

func set_near_shop_station(station: Area2D) -> void:
	nearby_station = station
	if shop_ui != null and shop_ui.has_method("show_prompt"):
		shop_ui.show_prompt("Press interact to use station")


func clear_shop_station(station: Area2D) -> void:
	if nearby_station == station:
		nearby_station = null
		if shop_ui != null and shop_ui.has_method("hide_prompt"):
			shop_ui.hide_prompt()


func open_shop_ui(mode: String) -> void:
	shop_ui_open = true
	can_move = false
	can_attack = false

	if shop_ui != null and shop_ui.has_method("open_ui"):
		shop_ui.open_ui(mode, self)


func close_shop_ui() -> void:
	shop_ui_open = false
	can_move = true
	can_attack = true

	if shop_ui != null and shop_ui.has_method("close_ui_for_player"):
		shop_ui.close_ui_for_player(player_id)
