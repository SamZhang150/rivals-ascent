extends CharacterBody2D

signal died

@export var speed := randf_range(60, 80)
@export var max_health := 80
@export var touch_damage := 12
@export var knockback_strength := 110.0
@export var coin_reward: int = 16

# Ranged behavior
@export var preferred_radius: float = 180.0
@export var too_close_radius: float = 120.0
@export var too_far_radius: float = 240.0
@export var strafe_speed_multiplier: float = 3

# Shooting
@export var projectile_scene: PackedScene
@export var projectile_damage: int = 8
@export var shoot_range: float = 350.0
@export var shoot_min_distance: float = 100.0
@export var shoot_cooldown: float = 3
@export var projectile_spawn_offset: Vector2 = Vector2.ZERO

@onready var sprite = $AnimatedSprite2D
@onready var hurtbox = $HurtboxArea
@onready var hitbox = $HitboxArea
@onready var health_bar = $HealthBar
@onready var bar_bg = $HealthBar/BarBG
@onready var bar_fill = $HealthBar/BarFill

const BAR_WIDTH := 28.0
const BAR_HEIGHT := 2.0

var health := 0
var dead := false
var last_damager: Node = null
var knockback := Vector2.ZERO
var player: CharacterBody2D = null
var speed_modifier: float = 1.0

var _slow_timer: Timer = null
var _stun_timer: Timer = null
var _shoot_timer: Timer = null
var _stun_active: bool = false
var _strafe_dir: int = 1

func _ready() -> void:
	add_to_group("enemies")
	hitbox.add_to_group("enemy_hitbox")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)

	_slow_timer = Timer.new()
	_slow_timer.one_shot = true
	_slow_timer.wait_time = 2.0
	_slow_timer.timeout.connect(_on_slow_finished)
	add_child(_slow_timer)

	_stun_timer = Timer.new()
	_stun_timer.one_shot = true
	_stun_timer.timeout.connect(_on_stun_finished)
	add_child(_stun_timer)

	_shoot_timer = Timer.new()
	_shoot_timer.one_shot = true
	_shoot_timer.wait_time = shoot_cooldown
	add_child(_shoot_timer)

	health = max_health
	health_bar.position = Vector2(-14, -12)
	bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	health_bar.visible = health < max_health
	
	bar_bg.color = Color("#2a2a2a")
	bar_fill.color = Color("#d64b4b")

func set_player(target: CharacterBody2D) -> void:
	player = target

func get_player() -> CharacterBody2D:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	return player

func _physics_process(delta: float) -> void:
	if dead:
		return

	if _stun_active:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var current_player := get_player()

	if knockback.length() > 1.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 500.0 * delta)

	elif current_player != null and is_instance_valid(current_player):
		var to_player := global_position.direction_to(current_player.global_position)
		var away_from_player := -to_player
		var dist := global_position.distance_to(current_player.global_position)

		var move_dir := Vector2.ZERO

		if dist < too_close_radius:
			# Player is too close, back away.
			move_dir = away_from_player
		elif dist > too_far_radius:
			# Player is too far, move closer.
			move_dir = to_player
		else:
			# Good range, strafe around the player.
			move_dir = to_player.orthogonal() * _strafe_dir

		velocity = move_dir.normalized() * speed * speed_modifier

		if velocity.length() > 1.0:
			sprite.play("run")
		else:
			sprite.play("idle")

		if to_player.x != 0:
			sprite.flip_h = to_player.x >= 0

		if dist <= shoot_range and dist >= shoot_min_distance:
			_try_shoot(current_player)

	else:
		velocity = Vector2.ZERO
		sprite.play("idle")

	move_and_slide()

func _try_shoot(current_player: CharacterBody2D) -> void:
	if projectile_scene == null:
		return
	if not _shoot_timer.is_stopped():
		return

	var dir := global_position.direction_to(current_player.global_position)
	_shoot_projectile(dir)

	_shoot_timer.start(shoot_cooldown)
	_strafe_dir *= -1

	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("shoot"):
		sprite.play("shoot")

func _shoot_projectile(dir: Vector2) -> void:
	var projectile := projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	projectile.global_position = global_position + projectile_spawn_offset
	print("projectile spawned at ", projectile.global_position)
	
	if projectile.has_method("setup"):
		projectile.setup(dir, projectile_damage, self)
	else:
		projectile.set("direction", dir)
		projectile.set("damage", projectile_damage)

func take_damage(amount: int, from_position: Vector2, damager: Node = null) -> void:
	if dead:
		return
		
	if damager != null:
		last_damager = damager

	health -= amount
	health = clamp(health, 0, max_health)

	var ratio := float(health) / float(max_health)
	bar_fill.size.x = BAR_WIDTH * ratio
	health_bar.visible = health < max_health

	knockback = (global_position - from_position).normalized() * knockback_strength
	$Damage.play()

	if health <= 0:
		if last_damager != null and last_damager.has_method("add_gold"):
			last_damager.add_gold(coin_reward)
		die()

func get_slowed(_amount: float) -> void:
	if dead:
		return

	speed_modifier = 0.6
	_set_slow_visual(true)
	if _slow_timer != null:
		_slow_timer.start(2.0)

func apply_chain_stun(incoming_damage: int, stun_time: float, chain_amount: int = 0, chain_damage: float = 0.0, chain_dist: float = 0.0, damager: Node = null) -> void:
	if dead:
		return

	take_damage(incoming_damage, global_position, damager)
	_apply_stun(stun_time)

func _apply_stun(stun_time: float) -> void:
	if stun_time <= 0.0 or dead:
		return

	_stun_active = true
	_refresh_sprite_tint()

	if _stun_timer != null:
		_stun_timer.start(stun_time)

func _on_stun_finished() -> void:
	_stun_active = false
	if not dead:
		_refresh_sprite_tint()

func _on_slow_finished() -> void:
	speed_modifier = 1.0
	if not dead:
		_set_slow_visual(false)

func _set_slow_visual(is_slowed: bool) -> void:
	if dead:
		return
	speed_modifier = 0.6 if is_slowed else 1.0
	_refresh_sprite_tint()

func _refresh_sprite_tint() -> void:
	if sprite == null:
		return

	var alpha: float = sprite.modulate.a

	if _stun_active:
		sprite.modulate = Color(1.0, 1.0, 0.25, alpha)
	elif speed_modifier < 0.999:
		sprite.modulate = Color(0.8, 1.0, 0.8, alpha)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, alpha)

func _on_hurtbox_area_entered(body: Node) -> void:
	pass

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		var player = area.get_parent()

func die() -> void:
	if dead:
		return

	dead = true
	_stun_active = false
	_refresh_sprite_tint()
	died.emit()
	queue_free()
