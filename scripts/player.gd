extends CharacterBody2D


const SPEED = 35.0

@export var player_id := 1
@export var move_left := "p1_left"
@export var move_right := "p1_right"
@export var move_up := "p1_up"
@export var move_down := "p1_down"
@export var attack_action := "p1_attack"


# shared player variables
var facing_dir := Vector2.RIGHT

var is_attacking := false
var is_dead := false

var attack_timer := 0.0
var invuln_timer := 0.0
var cooldown_timer := 0.0

var hit_enemies := []

# nodes
@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox
@onready var attack_shape = $AttackHitbox/CollisionShape2D
@onready var camera = $Camera2D

@onready var health_ui = get_tree().current_scene.get_node("HealthUI")


func _ready() -> void:
	if not Global.player_stats.has(player_id):
		Global.player_stats[player_id] = {
			"health": 20,
			"max_health": 20,
			"is_dead": false,
			"attack_damage": 2,
			"attack_duration": 0.2,
			"attack_cooldown": 1.75,
			"invuln_time": 0.75,
			"knockback_strength": 260.0,
			"knockback_decay": 700.0
		}

func _physics_process(delta: float) -> void:
	handle_timers(delta)
	handle_movement()
	handle_attack()
	move_and_slide()


func handle_movement() -> void:
	var input_dir = Input.get_vector(move_left, move_right, move_up, move_down)
	
	if input_dir != Vector2.ZERO:
		facing_dir = input_dir.normalized()
		velocity = facing_dir * SPEED
		sprite.flip_h = input_dir.x < 0
		sprite.play("run")
	else:
		velocity = Vector2.ZERO
		sprite.play("idle")


func handle_attack() -> void:
	if Input.is_action_just_pressed(attack_action) and not is_attacking and cooldown_timer <= 0.0:
		start_attack()


func start_attack() -> void:
	$Attack.play()
	is_attacking = true
	attack_timer = get_stat("attack_duration")
	cooldown_timer = get_stat("attack_cooldown")
	hit_enemies.clear()
	attack_hitbox.set_deferred("monitoring", true)
	attack_shape.set_deferred("disabled", false)


func handle_timers(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			attack_hitbox.set_deferred("monitoring", false)
			attack_shape.set_deferred("disabled", true)
			
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		
	if invuln_timer > 0.0:
		invuln_timer -= delta


func take_damage(amount: int) -> void:
	if invuln_timer > 0.0 or get_stat("is_dead"):
		return
		
	set_stat("health", get_stat("health") - amount)
	invuln_timer = get_stat("invuln_time")
	
	if get_stat("health") <= 0:
		set_stat("health", 0)
		set_stat("is_dead", true)

func get_stat(stat_name: String):
	return Global.player_stats[player_id][stat_name]

func set_stat(stat_name: String, value) -> void:
	Global.player_stats[player_id][stat_name] = value
