extends CharacterBody2D

signal died

@export var move_speed: float = 40.0
@export var chase_speed: float = 60.0
@export var max_health := 80
@export var touch_damage := 8
@export var knockback_strength := 110.0
@export var arrive_distance: float = 6.0
@export var coin_reward: int = 7

@export var orbit_distance: float = 42.0
@export var orbit_speed: float = 60.0
@export var lunge_speed: float = 80.0
@export var lunge_time: float = 0.22
@export var self_knockback_strength: float = 150.0
@export var min_orbit_time: float = 0.35
@export var max_orbit_time: float = 1.25
@export var min_recover_time: float = 0.35
@export var max_recover_time: float = 0.9
@export var lunge_chance_after_orbit: float = 0.75
@export var orbit_direction_change_chance: float = 0.45
@export var orbit_direction: int = 1

const BAR_WIDTH := 28.0
const BAR_HEIGHT := 2.0

enum DemonState {
	PATROL,
	CHASE,
	ORBIT,
	LUNGE,
	RECOVER
}

var state: DemonState = DemonState.PATROL

var health := 0
var dead := false
var last_damager: Node = null
var knockback := Vector2.ZERO
var player: CharacterBody2D = null
var speed_modifier: float = 1.0
var _slow_timer: Timer = null
var _state_timer: Timer = null
var _has_hit_during_lunge := false
var _lunge_direction := Vector2.ZERO
var _orbit_target_time: float = 0.0

var patrol_point_a_position: Vector2
var patrol_point_b_position: Vector2
var current_patrol_target: Vector2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var hitbox: Area2D = $HitboxArea
@onready var hitbox_shape: CollisionShape2D = $HitboxArea/CollisionShape2D
@onready var hurtbox: Area2D = $HurtboxArea
@onready var hurtbox_shape: CollisionShape2D = $HurtboxArea/CollisionShape2D
@onready var patrol_point_a: Marker2D = $PatrolPointA
@onready var patrol_point_b: Marker2D = $PatrolPointB
@onready var health_bar = $HealthBar
@onready var bar_bg = $HealthBar/BarBG
@onready var bar_fill = $HealthBar/BarFill
@onready var damage_sfx: AudioStreamPlayer2D = $Damage


func _ready() -> void:
	randomize()

	add_to_group("enemies")
	hitbox.add_to_group("enemy_hitbox")

	health = max_health

	patrol_point_a_position = patrol_point_a.global_position
	patrol_point_b_position = patrol_point_b.global_position
	current_patrol_target = patrol_point_a_position

	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)

	_slow_timer = Timer.new()
	_slow_timer.one_shot = true
	_slow_timer.wait_time = 2.0
	_slow_timer.timeout.connect(_on_slow_finished)
	add_child(_slow_timer)

	_state_timer = Timer.new()
	_state_timer.one_shot = true
	_state_timer.timeout.connect(_on_state_timer_timeout)
	add_child(_state_timer)

	health_bar.position = Vector2(-14, -12)
	bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	health_bar.visible = health < max_health

	bar_bg.color = Color("#2a2a2a")
	bar_fill.color = Color("#d64b4b")

	play_idle()


func _physics_process(delta: float) -> void:
	if dead:
		return

	if knockback.length() > 1.0:
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	else:
		match state:
			DemonState.PATROL:
				patrol()
			DemonState.CHASE:
				chase_player()
			DemonState.ORBIT:
				orbit_player()
			DemonState.LUNGE:
				lunge_player()
			DemonState.RECOVER:
				recover(delta)

	move_and_slide()
	update_animation()


func patrol() -> void:
	if player != null and is_instance_valid(player):
		state = DemonState.CHASE
		return

	var direction := current_patrol_target - global_position

	if direction.length() <= arrive_distance:
		if current_patrol_target == patrol_point_a_position:
			current_patrol_target = patrol_point_b_position
		else:
			current_patrol_target = patrol_point_a_position

		direction = current_patrol_target - global_position

	if direction.length() > 0:
		velocity = direction.normalized() * move_speed * speed_modifier
	else:
		velocity = Vector2.ZERO


func chase_player() -> void:
	if player == null or not is_instance_valid(player):
		state = DemonState.PATROL
		velocity = Vector2.ZERO
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()

	if distance <= orbit_distance:
		start_orbit()
		return

	velocity = to_player.normalized() * chase_speed * speed_modifier


func start_orbit() -> void:
	if player == null or not is_instance_valid(player):
		state = DemonState.PATROL
		return

	state = DemonState.ORBIT

	if randf() < orbit_direction_change_chance:
		orbit_direction *= -1

	_orbit_target_time = randf_range(min_orbit_time, max_orbit_time)
	_state_timer.start(_orbit_target_time)


func orbit_player() -> void:
	if player == null or not is_instance_valid(player):
		state = DemonState.PATROL
		velocity = Vector2.ZERO
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()

	if distance > orbit_distance + 24.0:
		state = DemonState.CHASE
		_state_timer.stop()
		return

	var direction := to_player.normalized()
	var perpendicular := Vector2(-direction.y, direction.x) * orbit_direction

	# Keeps the Demon close enough to eventually hit instead of orbiting forever.
	var inward_pull := direction * 0.45

	velocity = (perpendicular + inward_pull).normalized() * orbit_speed * speed_modifier


func start_lunge() -> void:
	if player == null or not is_instance_valid(player):
		state = DemonState.PATROL
		return

	state = DemonState.LUNGE
	_state_timer.stop()

	_has_hit_during_lunge = false
	_lunge_direction = global_position.direction_to(player.global_position)

	velocity = _lunge_direction * lunge_speed * speed_modifier
	_state_timer.start(lunge_time)


func lunge_player() -> void:
	velocity = _lunge_direction * lunge_speed * speed_modifier


func start_recover() -> void:
	state = DemonState.RECOVER
	velocity = Vector2.ZERO

	if player != null and is_instance_valid(player):
		knockback = (global_position - player.global_position).normalized() * self_knockback_strength
	else:
		knockback = -_lunge_direction * self_knockback_strength

	_state_timer.start(randf_range(min_recover_time, max_recover_time))


func recover(delta: float) -> void:
	velocity = knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)


func update_animation() -> void:
	if dead:
		return

	if player != null and is_instance_valid(player):
		play_chase()
	else:
		play_idle()

	update_sprite_flip()


func update_sprite_flip() -> void:
	if player != null and is_instance_valid(player):
		var dir := player.global_position - global_position
		if dir.x != 0:
			sprite.flip_h = dir.x < 0
		return

	if velocity.x < 0:
		sprite.flip_h = true
	elif velocity.x > 0:
		sprite.flip_h = false


func play_idle() -> void:
	if dead:
		return

	if sprite.sprite_frames.has_animation("idle") and sprite.animation != "idle":
		sprite.play("idle")


func play_chase() -> void:
	if dead:
		return

	if sprite.sprite_frames.has_animation("chase") and sprite.animation != "chase":
		sprite.play("chase")


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

	if damage_sfx != null:
		damage_sfx.play()

	if health <= 0:
		if last_damager != null and last_damager.has_method("add_gold"):
			last_damager.add_gold(coin_reward)
		die()


func take_hit() -> void:
	take_damage(1, global_position)


func get_slowed(_amount: float) -> void:
	if dead:
		return

	speed_modifier = 0.6
	_set_slow_visual(true)

	if _slow_timer != null:
		_slow_timer.start(2.0)


func _on_slow_finished() -> void:
	speed_modifier = 1.0

	if not dead:
		_set_slow_visual(false)


func _set_slow_visual(is_slowed: bool) -> void:
	if sprite == null:
		return

	var alpha: float = sprite.modulate.a

	if is_slowed:
		sprite.modulate = Color(0.8, 1.0, 0.8, alpha)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, alpha)


func die() -> void:
	if dead:
		return

	dead = true
	died.emit()

	player = null
	velocity = Vector2.ZERO

	collision_shape.set_deferred("disabled", true)
	hitbox_shape.set_deferred("disabled", true)
	hurtbox_shape.set_deferred("disabled", true)
	detection_shape.set_deferred("disabled", true)

	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	detection_area.set_deferred("monitoring", false)
	detection_area.set_deferred("monitorable", false)

	queue_free()


func _on_detection_area_body_entered(body: Node) -> void:
	if dead:
		return

	if body.has_method("take_damage"):
		player = body as CharacterBody2D
		state = DemonState.CHASE


func _on_detection_area_body_exited(body: Node) -> void:
	if dead:
		return

	if body == player:
		player = null
		state = DemonState.PATROL
		_state_timer.stop()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if dead:
		return

	if state != DemonState.LUNGE:
		return

	if _has_hit_during_lunge:
		return

	if area.is_in_group("player_hitbox"):
		_has_hit_during_lunge = true
		start_recover()


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if dead:
		return

	var attacker := area.get_parent()

	if attacker != null and attacker.has_method("get_attack_damage"):
		take_damage(attacker.get_attack_damage(), attacker.global_position, attacker)
		return

	if "damage" in area:
		take_damage(int(area.damage), area.global_position, attacker)
		return

	if attacker != null and "damage" in attacker:
		take_damage(int(attacker.damage), attacker.global_position, attacker)


func _on_state_timer_timeout() -> void:
	if dead:
		return

	if state == DemonState.ORBIT:
		if randf() < orbit_direction_change_chance:
			orbit_direction *= -1

		if randf() < lunge_chance_after_orbit:
			start_lunge()
		else:
			start_orbit()
		return

	if state == DemonState.LUNGE:
		start_recover()
		return

	if state == DemonState.RECOVER:
		knockback = Vector2.ZERO

		if player != null and is_instance_valid(player):
			if randf() < orbit_direction_change_chance:
				orbit_direction *= -1
			state = DemonState.CHASE
		else:
			state = DemonState.PATROL
