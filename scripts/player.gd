## player.gd
## Attach to the root of player.tscn
##
## === PLAYER.TSCN NODE TREE ===
## Player (CharacterBody2D)             [script: player.gd]
## ├── Sprite2D                         ← player sprite/animation
## ├── CollisionShape2D                 ← physics body (RectangleShape2D or CircleShape2D)
## ├── HitboxArea (Area2D)              ← detects incoming damage
## │   └── CollisionShape2D             ← slightly larger than body collision
## ├── AttackArea (Area2D)              ← deals damage on attack
## │   └── CollisionShape2D             ← positioned in front of player
## └── AttackCooldownTimer (Timer)      [wait_time=0.4, one_shot=true]
##
## === INPUT MAP (Project > Input Map) ===
## You MUST create these input actions:
##   p1_up, p1_down, p1_left, p1_right, p1_attack, p1_ready
##   p2_up, p2_down, p2_left, p2_right, p2_attack, p2_ready
##
## Suggested bindings:
##   P1: WASD + Space (attack) + Enter (ready)
##   P2: Arrow keys + Numpad 0 (attack) + Numpad Enter (ready)

extends CharacterBody2D

# ─── CONFIG ──────────────────────────────────────────────
@export var speed: float = 50.0
@export var max_health: int = 100
@export var attack_damage: int = 20

# ─── STATE ───────────────────────────────────────────────
var player_id: int = 1  # set by game_manager on spawn
var can_move: bool = true
var can_attack: bool = false
var health: int = max_health
var is_attacking: bool = false

# Input action prefixes
var _prefix: String = "p1_"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_timer: Timer = $AttackCooldownTimer

signal died(player_id: int)


func _ready():
	_prefix = "p1_" if player_id == 1 else "p2_"
	attack_area.monitoring = false
	attack_timer.timeout.connect(_on_attack_cooldown_finished)

	# Connect hitbox to receive damage
	var hitbox = $HitboxArea as Area2D
	hitbox.area_entered.connect(_on_hitbox_area_entered)

	health = max_health


func _physics_process(_delta: float):
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


func _unhandled_input(event: InputEvent):
	if not can_attack:
		return
	if event.is_action_pressed(_prefix + "attack") and not is_attacking:
		_perform_attack()


func _perform_attack():
	is_attacking = true
	attack_area.monitoring = true
	attack_timer.start()
	# You could play an attack animation here
	# sprite.play("attack")


func _on_attack_cooldown_finished():
	is_attacking = false
	attack_area.monitoring = false


func _on_hitbox_area_entered(area: Area2D):
	# Check if the incoming area is another player's AttackArea
	var attacker = area.get_parent()
	if attacker is CharacterBody2D and attacker != self:
		take_damage(attacker.attack_damage)


func take_damage(amount: int):
	health -= amount
	# Flash the sprite red briefly
	sprite.modulate = Color.RED
	get_tree().create_timer(0.15).timeout.connect(
		func(): sprite.modulate = Color.WHITE
	)
	if health <= 0:
		_die()


func _die():
	can_move = false
	can_attack = false
	visible = false
	# Notify game manager
	var game_manager = get_tree().root.get_node("Main")
	if game_manager.has_method("on_player_died"):
		game_manager.on_player_died(player_id)


func reset_for_round():
	health = max_health
	can_move = true
	visible = true
	sprite.modulate = Color.WHITE
